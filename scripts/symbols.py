# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re

class Module:
  def __init__(self, fqn):
    self.pckg_fqn, sep, self.name = fqn.rpartition('.')
    self.fqn = fqn
    self.sym_dict = {}
  def __cmp__(self, other):
    result = cmp(self.name.lower(), other.name.lower())
    if result == 0: # Compare fqn if the names are equal.
      result = cmp(self.fqn.lower(), other.fqn.lower())
    return result
  @property
  def symbolTree(self):
    return self.sym_dict['']

class Package(Module): # Inherit for convenience.
  def __init__(self, fqn):
    Module.__init__(self, fqn)
    self.packages, self.modules = ([], [])

class PackageTree:
  from bisect import bisect_left
  def __init__(self):
    self.root = Package('')
    self.packages = {'': self.root}
    self.modules = [] # Sorted list of all modules.

  def addModule(self, module):
    self.getPackage(module.pckg_fqn).modules.append(module)
    insert_pos = self.bisect_left(self.modules, module)
    self.modules.insert(insert_pos, module)

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

  @property
  def link(self):
    return "#m-%s:%s" % (self.modfqn, self.fqn)

  @property
  def beg(self):
    return self.loc[0]
  @property
  def end(self):
    return self.loc[1]

  def __cmp__(self, other):
    return cmp(self.name.lower(), other.name.lower())

  def __repr__(self):
    return self.fqn

def get_symbols(jsons, module_fqn, categorize=True):
  """ Extracts the symbols from an HTML document. """

  SymKind = ("package module template class interface struct union alias "
    "typedef enum enummem variable function invariant new delete unittest "
    "ctor dtor sctor sdtor").split(" ")

  SymAttr = ("private protected package public export abstract auto const "
    "deprecated extern final invariant override scope static synchronized "
    "in out ref lazy variadic manifest C C++ D Windows Pascal").split(" ")

  import json
  json_path = jsons/(module_fqn+".json")
  json_text = open(json_path).read()
  arrayTree = json.loads(json_text)

  symbol_dict = {}
  cat_dict = {}

  def visit(s, fqn):
    name = s[0]
    d = {'name': name, 'kind': SymKind[s[1]],
      'attrs': [SymAttr[x] for x in s[2]], 'loc': s[3], 'modfqn': module_fqn}

    # E.g.: 'tango.core' + '.' + 'Thread'
    fqn += ("." if fqn != "" else "") + name
    # Add ":\d+" suffix if not unique.
    sibling = symbol_dict.get(fqn)
    if sibling:
      if not hasattr(sibling, 'count'):
        sibling.count = 1
      sibling.count += 1
      fqn += ":" + str(sibling.count)
    d['fqn'] = fqn

    symbol = Symbol(d) # Create the symbol.
    symbol_dict[fqn] = symbol # Add it to the dictionary.

    symbol.sub = members = s[4] # Visit the members of this symbol.
    for i, m in enumerate(members):
      members[i] = visit(m, fqn)

    if categorize: # cat_dict[kind] += [symbol]
      kinds = cat_dict.setdefault(symbol.kind, [])
      kinds.append(symbol)

    return symbol

  root_name = arrayTree[0]
  arrayTree[0] = ""
  root = visit(arrayTree, "") # Start traversing the tree.
  root.name = root_name
  root.fqn = module_fqn
  return symbol_dict, cat_dict

def get_index(symbols):
  """ Groups the symbols by the initial letter of their names. """
  letter_dict = {} # Sort index by the symbol's initial letter.
  for sym in symbols:
    initial_letter = sym.name[0].upper()
    letter_dict.setdefault(initial_letter, []).append(sym) # Add to the group.
  letter_list = letter_dict.keys()
  letter_list.sort()
  return letter_dict, letter_list
