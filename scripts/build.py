#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
__file__ = tounicode(__file__)

class Command:
  def __init__(self, exe, wine):
    self.use_wine = wine
    self.exe = exe
  def args(self):
    return []
  def call(self):
    """ Executes the compiler executable. """
    args = self.args()
    exe = self.exe
    if self.use_wine:
      args = [exe] + args
      exe = "wine"
    try:
      retcode = call_proc(exe, *args)
    except OSError as e:
      e.exe = exe
      raise e
    return retcode

class CmdParameters(dict):
  def __getattr__(self, name): return self[name]
  def __setattr__(self, name, value): self[name] = value
  def __delattr__(self, name): del self[name]

class DMDCommand(Command):
  exe = "dmd"
  P = CmdParameters( # Parameter template strings.
    I = "-I%s", # Include-directory.
    L = "-L%s", # Linker option.
    version = "-version=%s", # Version level or identifier.
    of = "-of%s", # Output file path.
    od = "-od%s", # Object directory.
    inline = "-inline", # Inline code.
    release = "-release", # Compile release code.
    debug = "-debug", # Compile in debug statements.
    O = "-O", # Optimize code.
    g = "-g", # Include debug symbols.
    w = "-w", # Enable warnings.
    op = "-op", # Don't strip paths from source files.
    o_ = "-o-" # Don't output object file.
  )
  def __init__(self, files, out_exe, exe=exe, wine=False, objdir='obj',
               release=False, optimize=False, inline=False, debug_info=False,
               no_obj=False, warnings=False, strip_paths=False,
               lnk_args=[], includes=[], versions=[], other=[]):
    Command.__init__(self, exe, wine)
    P = self.P
    self.files = files
    self.out_exe = P.of%out_exe if out_exe else None
    options = ((release, P.release), (optimize, P.O), (inline, P.inline),
              (objdir, P.od%objdir), (warnings, P.w), (debug_info, P.g),
              (not strip_paths, P.op), (no_obj, P.o_))
    self.options  = [o for enabled, o in options if enabled]
    self.lnk_args = [P.L%l for l in lnk_args]
    self.includes = [P.I%i for i in includes]
    self.versions = [P.version%v for v in versions]
    self.other_args = other

  def args(self):
    """ Returns all command arguments as a list of strings. """
    return self.options + self.lnk_args + self.includes + \
           self.versions + self.files + self.other_args + \
           ([self.out_exe] if self.out_exe else [])

  def __str__(self):
    """ Returns the cmd as a string, but doesn't include the file paths. """
    files_saved = self.files
    # Don't flood cmd line with file paths.
    self.files = ["(%d source files...)"%len(files_saved)]
    cmd_str = " ".join([self.exe]+self.args())
    self.files = files_saved
    return cmd_str

class LDCCommand(DMDCommand):
  """ Overrides members where needed. """
  exe = "ldc"
  P = CmdParameters(DMDCommand.P,
    I = "-I=%s",
    L = "-L=%s",
    of = "-of=%s",
    od = "-od=%s",
    inline = "-enable-inlining",
    version = "-d-version=%s",
  )
  def __init__(self, files, out_exe, exe=exe, **kwargs):
    DMDCommand.__init__(self, files, out_exe, exe=exe, **kwargs)

def build_dil(cmd_kwargs):
  """ Collects D source files and calls the compiler. """
  BIN = Path("bin")
  DATA = Path("data")
  BIN.mkdir()
  # Copy the config file if non-existent.
  (BIN/"dilconf.d").exists or (DATA/"dilconf.d").copy(BIN)
  # Find the source files.
  FILES = find_dil_source_files(Path("src"))
  # Pick a compiler class.
  Command = cmd_kwargs.pop("cmdclass", DMDCommand)
  # Run the compiler.
  exe_dest = BIN/"dil"
  if "wine" in cmd_kwargs:
    exe_dest = (exe_dest+".exe").replace("/", "\\")
  if "-c" in cmd_kwargs["other"]: # Only compile objects?
    exe_dest = None
  cmd = Command(FILES, exe_dest, **cmd_kwargs)
  print(cmd)
  try:
    retcode = cmd.call()
  except OSError as e:
    if e.errno == 2:
      print("Error: command not found: '%s'" % e.exe)
  return retcode


def build_dil_release(**kwargs):
  # Enable inlining when DMDBUG #7967 is fixed.
  options = {'release':1, 'optimize':1, 'inline':0}
  return build_dil(dict(kwargs, **options))

def build_dil_debug(**kwargs):
  options = {'debug_info':1}
  kwargs.setdefault('other', []).append('-debug')
  return build_dil(dict(kwargs, **options))

def main():
  from optparse import OptionParser
  import sys

  usage = """Usage: %s [Options]

    Options after the string '--' are forwarded to the compiler.""" % __file__
  parser = OptionParser(usage=usage)
  parser.add_option(
    "--release", dest="release", action="store_true", default=False,
    help="build a release version (default)")
  parser.add_option(
    "--debug", dest="debug", action="store_true", default=False,
    help="build a debug version")
  parser.add_option("-1", dest="d1", action="store_true", default=False,
    help="build with -version=D1")
  parser.add_option("--ldc", dest="ldc", action="store_true", default=False,
    help="use ldc instead of dmd")
  parser.add_option(
    "--unittest", dest="unittest", action="store_true", default=False,
    help="build unit tests (recommended for first run)")
  parser.add_option("--wine", dest="wine", action="store_true", default=False,
    help="use wine to build a Windows binary on Linux")

  args, other_args = sys.uargv[1:], []
  try:
    i = args.index("--")
    args, other_args = args[:i], args[i+1:]
  except Exception: pass

  (options, args) = parser.parse_args(args)

  change_cwd(__file__)

  for_win = is_win32 or options.wine

  command = (DMDCommand, LDCCommand)[options.ldc]
  versions = (["D2"], ["D1"])[options.d1]
  lnk_args = []
  if options.debug and not for_win:
    # -ldl needs to come last to avoid linker errors.
    lnk_args = ["-ltango-dmd", "-lphobos2", "-ldl"]

  if options.unittest: other_args += ["-unittest"]

  build_func = (build_dil_release, build_dil_debug)[options.debug]
  # Call the compiler with the provided options.
  retcode = build_func(cmdclass=command, wine=options.wine, versions=versions,
    lnk_args=lnk_args, other=other_args)

  sys.exit(retcode)

if __name__ == '__main__':
  main()
