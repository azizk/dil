# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from dil.symbol import Symbol

class Package(Symbol):
  def __init__(self, name):
    Symbol.__init__(self, name)
    self.name = name
    self.packages = []
    self.modules = []

    insert(modul, modul.name);

  def addModule(self, m):
    m.parent = self
    self.modules.append(m)
    self.insert(m)

  def addPackage(self, p):
    p.parent = self
    self.packages.append(p)
    self.insert(p)
