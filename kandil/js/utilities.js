/// Author: Aziz Köksal

/// Escapes the regular expression meta characters in str.
RegExp.escape = function(str) {
  return str.replace(/([\\.*+?^${}()|[\]/])/g, '\\$1');
};

/// Splits a string by 'sep' returning a tuple (head, tail).
String.prototype.rpartition = function(sep) {
  var sep_pos = this.lastIndexOf(sep);
  var head = (sep_pos == -1) ? "" : this.slice(0, sep_pos);
  var tail = this.slice(sep_pos+1);
  return [head, tail];
};

/// Strips chars (defaults to whitespace) from the start and end of a string.
String.prototype.strip = function(chars) {
  var rx = /^\s+|\s+$/g; // Fast for short strings.
  if (arguments.length == 1)
    (chars = RegExp.escape(chars)),
    (rx = RegExp("^["+chars+"]+|["+chars+"]+$", "g"));
  return this.replace(rx, "");
  // Alternative method (fast for long strings):
  /*var rx = /^\s+/;
  if (arguments.length == 1)
    (chars = RegExp.escape(chars)),
    (rx = RegExp("^["+chars+"]+"));
  var str = this.replace(rx, ""), i = str.length;
  if (i) while(rx.test(str[--i])){}
  return str.substring(0, i+1);*/
};

/// Prepends and appends chars to each element and returns a joined string.
// Array.prototype.surround = function(chars) {
//   return chars+this.join(chars+chars)+chars;
// };

// Extend the DOM Element class with custom methods.
// They're faster than the jQuery methods.
jQuery.extend(Element.prototype, {
  /// Removes one or more CSS classes (separated by '|') from a node.
  removeClass: function(classes) {
    if (/*this.nodeType != 1 || */this.className == undefined) return;
    // Can't work with:
    // 1. '\b(?:classes)\b' would match class names with hyphens: "name-abc".
    // 2. '(?:\s|^)(?:classes)(?:\s|$)' produces wrong matches.
    // Adding a space to both sides elegantly solves this problem.
    var rx = RegExp(" (?:"+classes+") ", "g");
    this.className = (" "+this.className+" ").replace(rx, " ").slice(1, -1);
    return this;
  },
  /// Adds one or more CSS classes (separated by '|') to a node.
  addClass: function(classes) {
    if (/*this.nodeType != 1 || */this.className == undefined) return;
    this.removeClass(classes);
    this.className += " " + classes.replace(/\|/g, " ");
    return this;
  },
  /// Returns true if the node has one of the classes (separated by '|').
  hasClass: function(classes) {
    if (/*this.nodeType != 1 || */this.className == undefined) return;
    return RegExp(" (?:"+classes+") ").test(" "+this.className+" ");
  },
  /// Toggles one or more CSS classes (separated by '|') of a node.
  /// Note: $('<x class="a b"/>').toggleClass("b|c|d") -> "a", not "a c d"
  toggleClass: function(classes, state) {
    if (/*this.nodeType != 1 || */this.className == undefined) return;
    if (typeof state != typeof true)
      state = !this.hasClass(classes);
    state ? this.addClass(classes) : this.removeClass(classes);
    return this;
  }
});

// Replace the methods in jQuery.
jQuery.extend(jQuery.fn, function(p/*rototype*/){ return {
  removeClass: function(){ return this.each(p.removeClass, arguments) },
  addClass:    function(){ return this.each(p.addClass, arguments) },
  toggleClass: function(){ return this.each(p.toggleClass, arguments) },
  hasClass:    function(classes){
    for (var i = 0, len = this.length; i < len; i++)
      if (p.hasClass.call(this[i], classes))
        return true;
    return false;
  }
}}(Element.prototype));

/*// Create "console" variable for browsers that don't support it.
var emptyFunc = function(){};
if (window.opera)
  console = {log: function(){ opera.postError(arguments.join(" ")) },
             profile: emptyFunc, profileEnd: emptyFunc};
else if (!window.console)
  console = {log: emptyFunc, profile:emptyFunc, profileEnd: emptyFunc};

profile = function profile(msg, func) {
  console.profile(msg);
  func();
  console.profileEnd(msg);
};*/
