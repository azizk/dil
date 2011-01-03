# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals

class Module:
  def __init__(self, fqn):
    self.pckg_fqn, sep, self.name = fqn.rpartition('.')
    self.pckg = None
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

  @property
  def link(self):
    return "#m-" + self.fqn

class Package(Module): # Inherit for convenience.
  def __init__(self, fqn):
    Module.__init__(self, fqn)
    self.packages, self.modules = ([], [])

  def addModule(self, module):
    self.modules.append(module)
    module.pckg = self

  def addPackage(self, package):
    self.packages.append(package)
    package.pckg = self

  @property
  def link(self):
    return "#p-" + self.fqn

class PackageTree:
  """ Represents a tree of all packages and modules in a project. """
  from bisect import bisect_left
  def __init__(self):
    self.root = Package('')
    self.packages = {'': self.root}
    self.modules = [] # Sorted list of all modules.
    self.mod_dict = {} # All modules by FQN.
    self.cat_dict = {} # All symbols by category.

  def addModule(self, module):
    self.getPackage(module.pckg_fqn).addModule(module)
    insert_pos = self.bisect_left(self.modules, module)
    self.modules.insert(insert_pos, module)
    self.mod_dict[module.fqn] = module
    if hasattr(module, 'cat_dict'):
      self.addCatDict(module.cat_dict)

  def getPackage(self, fqn):
    """ Returns the package object for the fqn string. """
    package = self.packages.get(fqn)
    if not package:
      parent_fqn, sep, name = fqn.rpartition('.')
      parentPackage = self.getPackage(parent_fqn) # Get the parent recursively.
      package = Package(fqn) # Create a new package.
      parentPackage.addPackage(package) # Add the new package to its parent.
      self.packages[fqn] = package # Add the new package to the list.
    return package

  def sortTree(self): self.sort(self.root)

  def sort(self, pckg):
    pckg.packages.sort()
    pckg.modules.sort()
    for subpckg in pckg.packages:
      self.sort(subpckg)

  def addCatDict(self, cat_dict):
    for kind, symbol_list in cat_dict.iteritems():
      self.cat_dict.setdefault(kind, []).extend(symbol_list)

  def sortCatDict(self):
    map(list.sort, self.cat_dict.itervalues())

  def listSymbols(self, kinds):
    """ Returns a list of all symbols of certain kinds in this tree. """
    syms = []
    for kind in kinds:
      if kind in self.cat_dict:
        syms.extend(self.cat_dict[kind])
    syms.sort()
    return syms

  @classmethod
  def symbolsByLetter(cls, symbols):
    """ Groups the symbols by the initial letter of their names. """
    letter_dict = {} # Sort index by the symbol's initial letter.
    for sym in symbols:
      initial_letter = sym.name[0].upper()
      # Add to the group.
      letter_dict.setdefault(initial_letter, []).append(sym)
    letter_list = letter_dict.keys()
    letter_list.sort(key=unicode.lower)
    return letter_dict, letter_list

class Symbol:
  """ Represents a D symbol. E.g. a class, a function etc. """
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
    return "Symbol(%s)" % self.fqn

class ModuleJSON(Module):
  """ Class for loading a module's symbols from a *.json file. """
  import json

  SymKind = ("package module template class interface struct union alias "
    "typedef enum enummem variable function invariant new delete unittest "
    "ctor dtor sctor sdtor").split(" ")
  SymKind = tuple(SymKind).__getitem__

  SymAttr = ("private protected package public export abstract auto const "
    "deprecated extern final override scope static synchronized "
    "in out ref lazy variadic immutable manifest nothrow pure "
    "shared gshared thread disable property safe system trusted "
    "C C++ D Windows Pascal System").split(" ")
  SymAttr = tuple(SymAttr).__getitem__

  def __init__(self, path, fqn, categorize=True):
    """ Loads the file and constructs the object. """
    Module.__init__(self, fqn)
    json_path = path/(fqn+".json")
    json_text = json_path.open().read()
    arrayTree = self.json.loads(json_text)

    self.module_fqn = fqn
    self.categorize = categorize
    self.sym_dict = {} # Maps FQNs to symbols.
    self.cat_dict = {} # Categorized by symbol kind.

    # The root's name must be empty,
    # so that it doesn't become part of the symbols' FQN.
    root_name = arrayTree[0]
    arrayTree[0] = ""
    root = self._visit(arrayTree, "") # Start traversing the tree.
    root.name = root_name # Now we can restore the name.
    root.fqn = fqn

    self.root = root

  def _visit(self, s, fqn):
    name = s[0]
    d = {
      'name': name, 'kind': self.SymKind(s[1]),
      'attrs': map(self.SymAttr, s[2]),
      'loc': s[3], 'modfqn': self.module_fqn
    }

    # E.g.: 'tango.core' + '.' + 'Thread'
    fqn += ("." if fqn != "" else "") + name
    # Add ":\d+" suffix if not unique.
    sibling = self.sym_dict.get(fqn)
    if sibling:
      if not hasattr(sibling, 'count'):
        sibling.count = 1
      sibling.count += 1
      fqn += ":" + str(sibling.count)
    d['fqn'] = fqn

    symbol = Symbol(d) # Create the symbol.
    self.sym_dict[fqn] = symbol # Add it to the dictionary.

    symbol.sub = members = s[4] # Visit the members of this symbol.
    for i, m in enumerate(members):
      members[i] = self._visit(m, fqn)

    if self.categorize: # cat_dict[kind] += [symbol]
      self.cat_dict.setdefault(symbol.kind, []).append(symbol)

    return symbol
