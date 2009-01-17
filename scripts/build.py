#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal

class DMDCommand:
  def __init__(self, files, out_exe, dmd_exe="dmd", objdir='obj',
               release=False, optimize=False, inline=False, debug_info=False,
               no_obj=False, warnings=False, strip_paths=False,
               lnk_args=[], includes=[], versions=[]):
    """ Returns a tuple of the string arguments and the local variables:
        (args, locals()). """
    self.use_wine = False
    self.files = files
    self.dmd_exe = dmd_exe
    self.out_exe = "-of"+out_exe
    options = ((release, "-release"), (optimize, "-O"), (inline, "-inline"),
              (objdir, "-od"+objdir), (warnings, "-w"), (debug_info, "-g"),
              (not strip_paths, "-op"), (no_obj, "-o-"))
    self.options  = [o for enabled, o in options if enabled]
    self.lnk_args = ["-L+"+l for l in lnk_args]
    self.includes = ["-I"+i for i in includes]
    self.versions = ["-version="+v for v in versions]

  def args(self):
    """ Returns all command arguments as a list of strings. """
    return self.options + self.lnk_args + self.includes + \
           self.versions + self.files + [self.out_exe]

  def call(self):
    """ Executes the dmd executable. """
    args = self.args()
    dmd_exe = self.dmd_exe
    if self.use_wine:
      args = [dmd_exe] + args
      dmd_exe = "wine"
    from subprocess import call
    call([dmd_exe] + args)

  def __str__(self):
    """ Returns the cmd as a string, but doesn't include the file paths. """
    files_saved = self.files
    self.files = ["(sourcefiles...)"] # Don't flood cmd line with file paths.
    cmd_str = " ".join([self.dmd_exe]+self.args())
    self.files = files_saved
    return cmd_str

def build_dil(cmd_kwargs):
  """ Collects D source files and calls dmd. """
  from common import find_dil_source_files
  from path import Path
  BIN = Path("bin")
  DATA = Path("data")
  BIN.mkdir()
  # Copy the config file.
  (BIN/"dilconf.d").exists or (DATA/"dilconf.d").copy(BIN)
  # Find the source files.
  FILES = find_dil_source_files(Path("src"))
  # Execute dmd.
  cmd = DMDCommand(FILES, BIN/"dil", **cmd_kwargs)
  print cmd
  cmd.call()

def build_dil_release(versions=[]):
  options = {'release':1, 'optimize':1, 'inline':1, 'versions':versions}
  build_dil(options)

def build_dil_debug(versions=[]):
  #{'debug_info':1} # Requires Tango compiled with -g.
  options = {'versions':versions}
  build_dil(options)

def main():
  from optparse import OptionParser

  usage = "Usage: scripts/build.py [Options]"
  parser = OptionParser(usage=usage)
  parser.add_option("--release", dest="release", action="store_true", default=False,
    help="build a release version (default)")
  parser.add_option("--debug", dest="debug", action="store_true", default=False,
    help="build a debug version")
  parser.add_option("-2", dest="d2", action="store_true", default=False,
    help="build with -version=D2")

  (options, args) = parser.parse_args()

  versions = ["D2"] if options.d2 else []
  if options.debug:
    build_dil_debug(versions)
  else:
    build_dil_release(versions)

if __name__ == '__main__':
  main()
