# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from dil.symbol import Symbol

class Module(Symbol):
  def __init__(self, fqn="", tokens=[], ext="", root=None):
    self.tokens = tokens
    self.fqn = fqn
    self.ext = ext
    self.root = root
