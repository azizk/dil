# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from __future__ import unicode_literals
import re

class Macro:
  rx = re.compile(r"^([^\W0-9]\w*)\s*=" "|^", re.M | re.U)
  def __init__(self, name, text, pos, src=""):
    self.pos = pos
    self.name = name
    self.text = text
    self.src = src
  def __repr__(self):
    return self.name + "@(%d,%d)" % self.pos + "='" + self.text[:5] + "'"
  __unicode__ = __str__ = __repr__

  @staticmethod
  def parse(text, src, skip=1):
    """ Parses a text and returns a list of macros. """
    prev_end = 0
    prev_name = ""
    prev_pos = (1, 1)
    macros = []
    macros_add = macros.append
    linnum = 0
    for m in Macro.rx.finditer(text):
      linnum += 1 # Increment line number.
      whole_match = m.group() # Whole matched text.
      if not whole_match: # Empty only when a newline was matched.
        continue
      # value = text[prev_end : m.start()]
      macros_add(Macro(prev_name, text[prev_end:m.start()], prev_pos, src))
      # Update variables.
      prev_end = m.end()
      prev_name = m.group(1)
      # column = whole_match.find(prev_name[0]) + 1
      prev_pos = (linnum, whole_match.find(prev_name[0]) + 1)
    macros_add(Macro(prev_name, text[prev_end:], prev_pos, src))
    return macros[skip:]

class MacroTable:
  def __init__(self, parent=None):
    self.parent = parent
    self.table = {}
  def search(self, name):
    macro = self.table.get(name, None)
    if not macro and self.parent: self.parent.search(name)
    return macro
  def insert(self, macro):
    self.table[macro.name] = macro
  def insert2(self, name, text, pos=(0,0), src=""):
    self.insert(Macro(name, text, pos, src))
