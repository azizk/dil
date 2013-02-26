#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from utils import dicta, dictad

class Target(dictad):
  """ Provides specific properties that apply to a target machine/platform. """
class Targets(dicta):
  """ Collection of Target objects. """

Targets = Targets()

Targets.Win = Target(
  name="Windows",
  dir="windows",
  iswin=True,
  dbgexe="dil%s_dbg.exe",
  rlsexe="dil%s.exe",
  libsffx=".lib",
  objsffx=".obj",
  binsffx=".exe",
  lnklibf="+lib%s.lib",
  lnklibd="+%s\\",
)

Targets.Win32 = Target(Targets.Win, bits=32)
Targets.Win64 = Target(Targets.Win, bits=64)

Targets.Lin = Target(
  name="Linux",
  dir="linux",
  islin=True,
  dbgexe="dil%s_dbg",
  rlsexe="dil%s",
  libsffx=".a",
  objsffx=".o",
  binsffx="",
  lnklibf="-l%s",
  lnklibd="-L%s",
)

Targets.Lin32 = Target(Targets.Lin, bits=32, arch="i386")
Targets.Lin64 = Target(Targets.Lin, bits=64, arch="amd64")
