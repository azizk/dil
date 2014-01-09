#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
from targets import *
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


class CmdArgs(dicta):
  def libd(self, ds, target):
    self.lnk_args += [target.lnklibd % d for d in ds]
  def libf(self, fs, target):
    self.lnk_args += [target.lnklibf % f for f in fs]


class DMDCommand(Command):
  exe = "dmd"
  P = dicta( # Parameter template strings.
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
    o_ = "-o-", # Don't output object file.
    m32 = "-m32", # Generate 32bit code.
    m64 = "-m64", # Generate 64bit code.
  )
  def __init__(self, files, out_exe, exe=exe, wine=False, objdir='obj',
               m32=False, m64=False,
               release=False, optimize=False, inline=False, debug_info=False,
               no_obj=False, warnings=False, strip_paths=False,
               lnk_args=[], includes=[], versions=[], other=[]):
    Command.__init__(self, exe, wine)
    P = self.P
    self.files = files
    self.out_exe = P.of%out_exe if out_exe else None
    options = ((release, P.release), (optimize, P.O), (inline, P.inline),
              (m32, P.m32), (m64, P.m64),
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
  P = dicta(DMDCommand.P,
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
  # Copy the config file if non-existent (and adjust DATADIR.)
  if not (BIN/"dilconf.d").exists:
    text = (DATA/"dilconf.d").read().replace("../../data", "../data")
    (BIN/"dilconf.d").write(text)
  # Find the source files.
  FILES = find_dil_source_files(Path("src"))
  # Pick a compiler class.
  Command = cmd_kwargs.pop("cmdclass", DMDCommand)
  # Run the compiler.
  exe_dest = BIN/"dil"
  if cmd_kwargs.get("wine", False):
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
  from argparse import ArgumentParser
  import sys

  desc = "Options after the string '--' are forwarded to the compiler."
  parser = ArgumentParser(description=desc)
  addarg = parser.add_argument
  addarg("--tango", dest="tango", metavar="PATH",
    help="set the root PATH to Tango for source and lib files")
  addarg("--release", dest="release", action="store_true",
    help="build a release version (default)")
  addarg("--debug", dest="debug", action="store_true",
    help="build a debug version")
  addarg("-1", dest="d1", action="store_true",
    help="build with -version=D1")
  addarg("--ldc", dest="ldc", action="store_true",
    help="use ldc instead of dmd")
  addarg("--unittest", dest="unittest", action="store_true",
    help="build unit tests (recommended for first run)")
  addarg("--wine", dest="wine", action="store_true",
    help="use wine to build a Windows binary on Linux")

  args = sys.uargv[1:]
  i = args.index("--") if "--" in args else len(args)
  args, other_args = args[:i], args[i+1:]

  options = parser.parse_args(args)

  change_cwd(__file__)

  for_win = is_win32 or options.wine
  target = (Targets.Lin, Targets.Win)[for_win]

  cargs = CmdArgs(lnk_args=[], includes=[], wine=options.wine, other=other_args)

  if options.tango:
    TANGO = Path(options.tango)
    cargs.includes += [TANGO]
    cargs.libd(TANGO/("lib32", "lib64"), target)
    cargs.libf(["tango-dmd"], target)

  command = (DMDCommand, LDCCommand)[options.ldc]
  cargs.versions = (["D2"], ["D1"])[options.d1]

  if options.debug and not for_win:
    # "dl" needs to come last to avoid linker errors.
    cargs.libf(["dl"], target)

  if options.unittest: cargs.other_args += ["-unittest"]

  build_func = (build_dil_release, build_dil_debug)[options.debug]
  sw = StopWatch()
  # Call the compiler with the provided options.
  retcode = build_func(cmdclass=command, **cargs)
  print("Finished in %.2fs" % sw.stop())

  sys.exit(retcode)

if __name__ == '__main__':
  main()
