# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re

class Module:
  def __init__(self, fqn):
    self.pckg_fqn, sep, self.name = fqn.rpartition('.')
    self.fqn = fqn
  def __cmp__(self, other):
    return cmp(self.name, other.name)

class Package(Module): # Inherit for convenience.
  def __init__(self, fqn):
    Module.__init__(self, fqn)
    self.packages, self.modules = ([], [])

class PackageTree:
  def __init__(self):
    self.root = Package('')
    self.packages = {'': self.root}

  def addModule(self, module):
    self.getPackage(module.pckg_fqn).modules += [module]

  def getPackage(self, fqn):
    """ Returns the package object for the fqn string. """
    package = self.packages.get(fqn);
    if not package:
      parent_fqn, sep, name = fqn.rpartition('.')
      parentPackage = self.getPackage(parent_fqn) # Get the parent recursively.
      package = Package(fqn) # Create a new package.
      parentPackage.packages += [package] # Add the new package to its parent.
      self.packages[fqn] = package # Add the new package to the list.
    return package;

  def sortTree(self): self.sort(self.root)

  def sort(self, pckg):
    pckg.packages.sort();
    pckg.modules.sort();
    for subpckg in pckg.packages:
      self.sort(subpckg);

class Symbol:
  def __init__(self, symdict):
    for attr, val in symdict.items():
      setattr(self, attr, val)
    self.parent_fqn, sep, self.name = self.fqn.rpartition('.')
    self.sub = []

def get_symbols(html_str, module_fqn):
  """ Extracts the symbols from an HTML document. """
  rx = re.compile(r'<a class="symbol [^"]+" name="(?P<fqn>[^"]+)"'
                  r' href="(?P<srclnk>[^"]+)" kind="(?P<kind>[^"]+)"'
                  r' beg="(?P<beg>\d+)" end="(?P<end>\d+)">'
                  r'(?P<name>[^<]+)</a>')
  root = dict(fqn=module_fqn, src="", kind="module", beg="", end="")
  symbol_dict = {"" : Symbol(root)}
  for m in rx.finditer(html_str):
    symbol = Symbol(m.groupdict())
    symbol_dict[symbol.parent_fqn].sub += [symbol]
    symbol_dict[symbol.fqn] = symbol
  return symbol_dict
