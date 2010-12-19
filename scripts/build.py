#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
import subprocess

class Command:
  def __init__(self, exe):
    self.use_wine = False
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
      subprocess.call([exe] + args)
    except OSError as e:
      e.exe = exe
      raise e

class CmdParameters(dict):
  def __getattr__(self, name): return self[name]
  def __setattr__(self, name, value): self[name] = value
  def __delattr__(self, name): del self[name]

class DMDCommand(Command):
  cmd = "dmd"
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
  def __init__(self, files, out_exe, exe=cmd, objdir='obj',
               release=False, optimize=False, inline=False, debug_info=False,
               no_obj=False, warnings=False, strip_paths=False,
               lnk_args=[], includes=[], versions=[], other=[]):
    Command.__init__(self, exe)
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
  cmd = "ldc"
  P = CmdParameters(DMDCommand.P,
    I = "-I=%s",
    L = "-L=%s",
    of = "-of=%s",
    od = "-od=%s",
    inline = "-enable-inlining",
    version = "-d-version=%s",
  )
  def __init__(self, files, out_exe, exe=cmd, **kwargs):
    DMDCommand.__init__(self, files, out_exe, exe=exe, **kwargs)

def build_dil(cmd_kwargs):
  """ Collects D source files and calls the compiler. """
  from common import find_dil_source_files
  from path import Path
  BIN = Path("bin")
  DATA = Path("data")
  BIN.mkdir()
  # Copy the config file if non-existent.
  (BIN/"dilconf.d").exists or (DATA/"dilconf.d").copy(BIN)
  # Find the source files.
  FILES = find_dil_source_files(Path("src"))
  # Pick a compiler class.
  Command = cmd_kwargs.get("CMDCLASS", DMDCommand)
  use_wine = cmd_kwargs.get("wine", False)
  del cmd_kwargs["CMDCLASS"]
  del cmd_kwargs["wine"]
  # Run the compiler.
  exe_dest = BIN/"dil"
  if use_wine:
    exe_dest = (exe_dest+".exe").replace("/", "\\")
  if "-c" in cmd_kwargs["other"]: # Only compile objects?
    exe_dest = None
  cmd = Command(FILES, exe_dest, **cmd_kwargs)
  cmd.use_wine = use_wine
  print cmd
  try:
    cmd.call()
  except OSError as e:
    if e.errno == 2:
      print "Error: command not found: '%s'" % e.exe


def build_dil_release(**kwargs):
  options = {'release':1, 'optimize':1, 'inline':1}
  build_dil(dict(kwargs, **options))

def build_dil_debug(**kwargs):
  options = {'debug_info':1}
  kwargs.setdefault('other', []).append('-debug')
  build_dil(dict(kwargs, **options))

def main():
  from optparse import OptionParser
  from common import change_cwd
  import sys

  usage = """Usage: scripts/build.py [Options]

    Options after the string '--' are forwarded to the compiler."""
  parser = OptionParser(usage=usage)
  parser.add_option(
    "--release", dest="release", action="store_true", default=False,
    help="build a release version (default)")
  parser.add_option(
    "--debug", dest="debug", action="store_true", default=False,
    help="build a debug version")
  parser.add_option("-2", dest="d2", action="store_true", default=False,
    help="build with -version=D2")
  parser.add_option("--ldc", dest="ldc", action="store_true", default=False,
    help="use ldc instead of dmd")
  parser.add_option(
    "--unittest", dest="unittest", action="store_true", default=False,
    help="build unit tests (recommended for first run)")
  parser.add_option("--wine", dest="wine", action="store_true", default=False,
    help="use wine to build a Windows binary on Linux")

  args, other_args = sys.argv[1:], []
  try:
    i = args.index("--")
    args, other_args = args[:i], args[i+1:]
  except Exception: pass

  (options, args) = parser.parse_args(args)

  change_cwd(__file__)

  is_win32 = (sys.platform == "win32" or options.wine)

  command = (DMDCommand, LDCCommand)[options.ldc]
  versions = ([], ["D2"])[options.d2]
  lnk_args = (["-lmpfr", "-ldl"], ["+mpfr"])[is_win32]
  # Remove -ldl if release build.
  lnk_args = (lnk_args[:1], lnk_args)[options.debug]

  if options.unittest: other_args += ["-unittest"]

  build_func = (build_dil_release, build_dil_debug)[options.debug]
  # Call the compiler with the provided options.
  build_func(CMDCLASS=command, wine=options.wine, versions=versions,
    lnk_args=lnk_args, other=other_args)

if __name__ == '__main__':
  main()
