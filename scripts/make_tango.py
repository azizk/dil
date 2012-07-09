#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
from build import DMDCommand, LDCCommand
__file__ = tounicode(__file__)

# Linux:
def make_Linux(TANGO):
  bob = "build/bin/linux32/bob"
  lib = "libtango-dmd.a"
  LIB32, LIB64 = map(Path.mkdir, TANGO//("lib32", "lib64"))
  for bits in (32, 64):
    DEST = (TANGO/"lib%d"%bits).mkdir()
    # Release
    ret = call_proc(bob, "-vu", "-m=%d"%bits, ".", cwd=TANGO)
    if ret != 0:
      break
    map(Path.rm, TANGO.glob("*.o"))
    (TANGO/lib).move(DEST)
    # Debug
    ret = call_proc(bob, "-vu", "-m=%d"%bits, ".", "-o=-g", cwd=TANGO)
    if ret != 0:
      break
    map(Path.rm, TANGO.glob("*.o"))
    (TANGO/lib).move(DEST/"libtango-dmd-dbg.a")

def make_Windows(TANGO):
  bob = "build/bin/win32/bob.exe"
  lib = "libtango-dmd.lib"
  build = call_proc
  if not is_win32:
    build = lambda *a, **k: call_proc("wine", *a, **k)
  for bits in (32,): # 64 not supported yet.
    DEST = (TANGO/"lib%d"%bits).mkdir()
    # Release
    ret = build(bob, "-vu", "-m=%d"%bits, ".", cwd=TANGO)
    if ret != 0:
      break
    (TANGO/lib).move(DEST)
    # Debug
    ret = build(bob, "-vu", "-m=%d"%bits, "-o=-g", ".", cwd=TANGO)
    if ret != 0:
      break
    (TANGO/lib).move(DEST/"libtango-dmd-dbg.lib")

def main():
  from optparse import OptionParser

  usage = "Usage: %s TANGO_DIR" % __file__
  parser = OptionParser(usage=usage)
  (opts, args) = parser.parse_args(sys.uargv[1:])
  if len(args) < 1:
    parser.error("missing argument TANGO_DIR")

  TANGO = Path(args[0])

  make_Linux(TANGO)
  make_Windows(TANGO)

  return

if __name__ == '__main__':
  main()
