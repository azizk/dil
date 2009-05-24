# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from __future__ import unicode_literals
import re

class Macro:
  rx = re.compile(r"^\s*([^\W0-9]\w*)\s*=", re.M | re.U)
  def __init__(self, pos, name, text, src=""):
    self.pos = pos
    self.name = name
    self.text = text
    self.src = src
  def __repr__(self):
    return self.name + "@%d,%d" % self.pos + "='" + self.text[:5] + "'"
  __unicode__ = __str__ = __repr__

class MacroTable:
  def __init__(self, parent=None):
    self.parent = parent
    self.table = {}
  def search(self, name):
    macro = self.table.get(name, None)
    if not macro and self.parent: self.parent.search(name)
    return macro

def parse_macros_v1(text, src):
  """ Note: doesn't produce correct (row,column) info. """
  rx_iter = Macro.rx.finditer(text)
  macros = []
  ms = [m.span()+m.groups() for m in rx_iter]
  ms += [(len(text), len(text), "")]

  for i in xrange(0, len(ms)-1):
    m = ms[i]
    name = m[2]
    pos = (text.find(name[0], m[0]), m[1])
    macro_text = text[m[1] : ms[i+1][0]]
    macros.append(Macro(pos, name, macro_text, src))
  return macros

def parse_macros_v2(text, src):
  rx = Macro.rx
  macros = []
  i = 0 # Line number.
  macro = Macro((1, 1), "", "", src) # First dummy macro.
  for line in text.splitlines(True):
    i += 1
    m = rx.match(line)
    if m:
      name = m.group(1)
      column = line.find(name[0]) + 1
      macro = Macro((i, column), name, line[m.end():], src)
      macros.append(macro)
    else:
      macro.text += line
  macros += [macro]
  return macros
