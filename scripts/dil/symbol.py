# -*- coding: utf-8 -*-
# Author: Aziz Köksal

class Symbol(object):
  def __init__(self, name):
    self.name = name
    self.parent = None

class ScopeSymbol(Symbol):
  def __init__(self, name):
    Symbol.__init__(self, name)
    self.table = {}

  def insert(self, symbol):
    self.table[symbol.name] = symbol

  def lookup(self, name):
    self.table.get(name)
