#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
from build import DMDCommand, LDCCommand

# Linux:
def make_Linux(TANGO):
  bob = "build/bin/linux32/bob"
  lib = "libtango-dmd.a"
  LIB32, LIB64 = map(Path.mkdir, TANGO//("lib32", "lib64"))
  for bits in (32, 64):
    DEST = (TANGO/"lib%d"%bits).mkdir()
    # Release
    call_proc(bob, "-vu", "-m=%d"%bits, ".", cwd=TANGO)
    map(Path.rm, TANGO.glob("*.o"))
    (TANGO/lib).move(DEST)
    # Debug
    call_proc(bob, "-vu", "-m=%d"%bits, ".", "-o=-g", cwd=TANGO)
    map(Path.rm, TANGO.glob("*.o"))
    (TANGO/lib).move(DEST/"libtango-dmd-dbg.a")

def make_Windows(TANGO):
  bob = "build/bin/win32/bob.exe"
  lib = "libtango-dmd.lib"
  for bits in (32,): # 64 not supported yet.
    DEST = (TANGO/"lib%d"%bits).mkdir()
    # Release
    call_proc("wine", "bob", "-vu", "-m=%d"%bits, ".", cwd=TANGO)
    (TANGO/lib).move(DEST)
    # Debug
    call_proc("wine", "bob", "-vu", "-m=%d"%bits, "-o=-g", ".", cwd=TANGO)
    (TANGO/lib).move(DEST/"libtango-dmd-dbg.lib")

def main():
  TANGO = Path("/home/aziz/git/tango")
  make_Linux(TANGO)
  make_Windows(TANGO)
  return

if __name__ == '__main__':
  main()
