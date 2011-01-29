#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
import sys, re
from path import Path

def listEntities(path):
  """ Parses the list from:
    http://www.w3.org/2003/entities/2007/w3centities-f.ent """
  txt = Path(path).open().read()
  rx = re.compile(r'<!ENTITY (\S+)\s+ "([^"]+)" ><!--(.+?) -->')
  a = rx.findall(txt)
  a.sort(key=lambda x: x[0].lower()) # Sort on entity name ignoring case.
  return a

def formatEntities(ents):
  s = "static const Entity[] namedEntities = [\n"
  for name, value, longname in ents:
    cmnt = "" # Comment out?
    if (value.count("&#") > 1 or # The entity has more than one character.
        " " in value or # E.g.: DotDot " &#x020DC;"
        "." in name): # E.g.: "b.Delta"
      cmnt, value = ("// ", '"%s"' % value)
    elif "&#38;" in value: # E.g.: "&#38;#60;" = &LT;
      value = value.replace("&#38;#", "").rstrip(";") # -> "60;" -> "60"
      value = "0x%05X" % int(value) # -> "0x00060"
    else:
      value = "0" + value.strip("&#;")
    s += '  %s{"%s", %s},\n' % (cmnt, name, value)
  return s + "];\n"

def main():
  ents = listEntities(sys.argv[1])
  s = formatEntities(ents)
  print(s)

if __name__ == "__main__":
  main()
