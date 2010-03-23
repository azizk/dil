/// Author: Aziz Köksal
/// License: zlib/libpng

/// An enumeration of symbol kinds. Maps strings to IDs and IDs to strings.
var SymbolKind = (function(){
  var kinds = "package module template class interface struct union alias \
typedef enum enummem variable function invariant new delete unittest ctor \
dtor sctor sdtor".split(" ");
  var dict = {str: kinds};
  for (var i = 0, len = kinds.length; i < len; i++)
    (dict[kinds[i]] = i), // E.g.: dict["package"] = 0;
    (dict[i] = kinds[i]); // E.g.: dict[0] = "package";
  return dict;
})();
/// Returns true if this symbol is a function.
SymbolKind.isFunction = function(key) {
  if (typeof key == typeof "")
    key = this[key]; // Get the ID if the key is a string.
  return 12 <= key && key <= 20; // ID range: 12-20.
};

/// Constructs a symbol. Represents a package, a module or a D symbol.
function Symbol(fqn, kind, sub)
{
  var parts = fqn.rpartition(".");
  this.parent_fqn = parts[0]; /// The fully qualified name of the parent.
  this.name = parts[1]; /// The text to be displayed.
  this.kind = kind;     /// The kind of this symbol.
  this.fqn = fqn;       /// The fully qualified name.
  this.sub = sub || []; /// Sub-symbols.
  return this;
}

Symbol.getTree = function(json/*=JSON text*/, moduleFQN) {
  var arrayTree = JSON.parse(json);
  var dict = {}; // A map of fully qualified names to symbols.
  var list = []; // A flat list of all symbols.
  function visit(s/*=symbol*/, fqn/*=fully qualified name*/)
  { // Assign the elements of this tuple to variables.
    var name = s[0], kindID = s[1], loc = s[2], members = s[3];
    // E.g.: 'tango.core' + 'Thread'
    fqn += (fqn ? "." : "") + name;
    // E.g.: 'Thread.this', 'Thread.this:2' etc.
    if (sibling = dict[fqn]) // Add ":\d+" suffix if not unique.
      fqn += ":" + ((sibling.count += 1) || (sibling.count = 2));
    // Create a new symbol.
    var symbol = new Symbol(fqn, SymbolKind[kindID], members);
    symbol.loc = s[2];
    dict[fqn] = symbol; // Add to the dictionary.
    list.push(symbol); // Add to the list.
    // Visit the members of this symbol.
    for (var i = 0, len = members.length; i < len; i++)
      (members[i] = visit(members[i], fqn)),
      (members[i].parent = symbol);
    return symbol;
  }
  var root_name = arrayTree[0];
  // Avoid including the roots name in the FQNs of the symbols.
  arrayTree[0] = "";
  dict.root = visit(arrayTree, "");
  dict.root.name = root_name;
  dict.root.fqn = moduleFQN;
  dict.list = list;
  return dict;
};


/// Constructs a module.
function M(fqn) {
  return new Symbol(fqn, "module");
}
/// Constructs a package.
function P(fqn, sub) {
  return new Symbol(fqn, "package", sub);
}

function PackageTree(root)
{
  this.root = root;
}
PackageTree.prototype.initList = function() {
  // Create a flat list from the package tree.
  var list = [];
  function visit(syms)
  { // Iterate recursively through the tree.
    for (var i = 0, len = syms.length; i < len; i++) {
      var sym = syms[i];
      list.push(sym);
      if (sym.sub.length) visit(sym.sub);
    }
  }
  visit([this.root]);
  this.list = list;
};
