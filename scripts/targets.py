#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function

class Target(dict):
  """ Provides specific properties that apply to a target machine/platform. """
  def __getattr__(self, name): return self.get(name, None)
  def __setattr__(self, name, value): self[name] = value
  def __delattr__(self, name): del self[name]

twindows32 = Target(
  name="Windows",
  dir="windows",
  iswin=True,
  bits=32,
  dbgexe="dil%s_dbg.exe",
  rlsexe="dil%s.exe",
  libsffx=".lib",
  objsffx=".obj",
  binsffx=".exe",
)

twindows64 = Target(twindows32, bits=64)

tlinux32 = Target(
  name="Linux",
  dir="linux",
  islin=True,
  bits=32,
  arch="i386",
  dbgexe="dil%s_dbg",
  rlsexe="dil%s",
  libsffx=".a",
  objsffx=".o",
  binsffx="",
)

tlinux64 = Target(tlinux32, bits=64, arch="amd64")
