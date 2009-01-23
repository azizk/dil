/// Author: Aziz Köksal

/// Removes one or more CSS classes (separated by ' ') from a node.
function removeClasses(node, classes)
{
  classes = classes.split(" ").join("\\b|\\s*\\b");
  rx = RegExp("\\s*\\b"+classes+"\\b", "g");
  node.className = node.className.replace(rx, "");
}

/// Splits a string by 'sep' returning a tuple (head, tail).
function rpartition(str, sep)
{
  var sep_pos = str.lastIndexOf(sep);
  var head = (sep_pos == -1) ? "" : str.slice(0, sep_pos);
  var tail = str.slice(sep_pos+1);
  return [head, tail];
}
