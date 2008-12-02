#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal

def dmd_cmd(files, exe_path, dmd_exe='dmd', objdir='obj', release=False,
            optimize=False, inline=False, debug_info=False, no_obj=False,
            warnings=False, lnk_args=[], includes=[], versions=[]):
  """ Returns a tuple (command, arguments) (str, dict). """
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
  files = ' '.join(map(escape, files))
  args = dict(locals(), exe_path="-of"+escape(exe_path))
  cmd = "%(dmd_exe)s%(options)s%(includes)s%(lnk_args)s %(files)s %(exe_path)s"
  return (cmd, args)

def main():
  pass

if __name__ == '__main__':
  main()
