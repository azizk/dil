#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal

def dmd_cmd(files, exe_path, dmd_exe='dmd', objdir='obj', release=False,
            optimize=False, inline=False, debug_info=False, no_obj=False,
            warnings=False, lnk_args=[], includes=[], versions=[]):
  """ Returns a tuple (command, arguments) of (str, dict). """
  def escape(f): # Puts quotations around the string if it has spaces.
    if '"' in f or "'" in f or ' ' in f or '\t' in f:
      return '"%s"' % f.replace('"', r'\"')
    else: return f
  options = ((release, "-release"), (optimize, "-O"), (inline, "-inline"),
             (objdir, "-od"+escape(objdir)), (True, "-op"), (warnings, "-w"),
             (debug_info, "-g"), (no_obj, "-o-"))
  options  = ''.join([" "+o for enabled, o in options if enabled])
  lnk_args = ''.join([" -L+"+escape(l) for l in lnk_args])
  includes = ''.join([" -I="+escape(i) for i in includes])
  versions = ''.join([" -version="+v for v in versions])
  files    = ' '+' '.join(map(escape, files))
  args = dict(locals(), exe_path=" -of"+escape(exe_path))
  cmd = "%(dmd_exe)s%(options)s%(includes)s%(lnk_args)s%(files)s%(exe_path)s"
  return (cmd, args)

def build_dil(**kwargs):
  """ Collects D source files and calls dmd. """
  import os
  from common import find_dil_source_files
  from path import Path
  BIN = Path("bin")
  DATA = Path("data")
  BIN.mkdir()
  if not (DATA/"dilconf.d").exists: (DATA/"dilconf.d").copy(BIN)
  FILES = find_dil_source_files(Path("src"))
  cmd, args = dmd_cmd(FILES, BIN/"dil", **kwargs)
  print cmd % dict(args, files=' (files...)')
  os.system(cmd % args)

def build_dil_release():
  options = {'release':1, 'optimize':1, 'inline':1}
  build_dil(**options)

def build_dil_debug():
  #{'debug_info':1} # Requires Tango compiled with -g.
  options = {}
  build_dil(**options)

def main():
  from optparse import OptionParser

  usage = "Usage: scripts/build.py [Options]"
  parser = OptionParser(usage=usage)
  parser.add_option("--release", dest="release", action="store_true", default=False,
    help="build a release version (default)")
  parser.add_option("--debug", dest="debug", action="store_true", default=False,
    help="build a debug version")

  (options, args) = parser.parse_args()

  if options.debug:
    build_dil_debug()
  else:
    build_dil_release()

if __name__ == '__main__':
  main()
