#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
from build import DMDCommand, LDCCommand
__file__ = tounicode(__file__)

def call_bob(bob, bits, TANGO, *args, **kwargs):
  kwargs["cwd"] = TANGO
  if not isinstance(bob, list):
    bob = [bob]
  args = tuple(bob) + ("-vu", "-m=%d"%bits, ".") + args
  if 0 != call_proc(*args, **kwargs):
    raise Exception("bob returned non-zero exit code")

def make_Linux(TANGO):
  bob = Path("build")/"bin"/"linux%d"/"bob" % cpu_bits
  lib = "libtango-dmd.a"
  LIB32, LIB64 = map(Path.mkdir, TANGO//("lib32", "lib64"))

  for bits in (32, 64):
    DEST = (TANGO/"lib%d"%bits).mkdir()
    # Release
    call_bob(bob, bits, TANGO)
    map(Path.rm, TANGO.glob("*.o"))
    (TANGO/lib).move(DEST)
    # Debug
    call_bob(bob, bits, TANGO, "-o=-g")
    map(Path.rm, TANGO.glob("*.o"))
    (TANGO/lib).move(DEST/"libtango-dmd-dbg.a")

def make_Windows(TANGO):
  bob = Path("build")/"bin"/"win32"/"bob.exe"
  lib = "libtango-dmd.lib"
  if not is_win32:
    bob = ["wine", bob]
  for bits in (32,): # 64 not supported yet.
    DEST = (TANGO/"lib%d"%bits).mkdir()
    # Release
    call_bob(bob, bits, TANGO)
    (TANGO/lib).move(DEST)
    # Debug
    call_bob(bob, bits, TANGO, "-o=-g")
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
