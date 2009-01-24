/// Author: Aziz Köksal

/// Removes one or more CSS classes (separated by ' ') from a node.
function removeClasses(node, classes)
{
  classes = classes.split(" ").join("\\b|\\s*\\b");
  rx = RegExp("\\s*\\b"+classes+"\\b", "g");
  node.className = node.className.replace(rx, "");
}

/// Splits a string by 'sep' returning a tuple (head, tail).
String.prototype.rpartition = function(sep)
{
  var sep_pos = this.lastIndexOf(sep);
  var head = (sep_pos == -1) ? "" : this.slice(0, sep_pos);
  var tail = this.slice(sep_pos+1);
  return [head, tail];
}

RegExp.escape = function(str) {
  return str.replace(/([\\.*+?^${}()|[\]/])/g, '\\$1');
}
