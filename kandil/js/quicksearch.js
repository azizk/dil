/// Author: Aziz Köksal
/// License: zlib/libpng

/// Constructs a QuickSearch object.
function QuickSearch(id, options)
{
  this.options = $.extend({
    text: "Filter...",
    delay: 500, // Delay time after key press until search kicks off.
  }, options);

  this.$input = $("<input class='filterbox' type='text'/>");
  this.$input.attr({value: this.options.text, id: id});
  this.input = this.$input[0];
  this.cancelSearch = false;
  this.timeoutId = 0;
  this.delaySearch = function() {
    this.cancelSearch = false;
    clearTimeout(this.timeoutId);
    qs = this;
    this.timeoutId = setTimeout(function() {
      if (!qs.cancelSearch) qs.$input.trigger("start_search", qs);
    }, this.options.delay);
  };
  this.input.qs = this; // Needed inside event handlers.
  this.$input.keyup(function(e) {
    switch (e.keyCode) {
    case 0:case 9:case 13:case 16:case 17:case 18:
    case 20:case 35:case 36:case 37:case 39:
      break; // Ignore meta keys and other keys.
    case 27: // Escape key.
      this.qs.cancelSearch = true;
      clearTimeout(this.qs.timeoutId);
      break;
    default:
      this.qs.delaySearch();
    }
  });

  function firstFocusHandler(e) {
    // Clear the text box when focused for the first time.
    $(this).val("").unbind("focus", firstFocusHandler)
           .trigger("first_focus", this.qs);
  }
  this.resetFirstFocusHandler = function() {
    this.$input.focus(firstFocusHandler)
               .val(this.options.text);
  };
  this.resetFirstFocusHandler();

  this.str = "";
  this.parse = function() { // Parses the query.
    this.sanitizeStr();
    if (this.str.length == 0)
      return false;
    function makeRegExp(term) {
      term = RegExp.escape(term).replace(/\\\?/g, ".").replace(/\\\*/g, ".*?");
      return RegExp(term, "i");
    }
    var terms = this.str.split(/\s+/);
    var query = {regexps: [], attributes: [], fqn_regexps: []};
    try
    {
      for (var i = 0, len = terms.length; i < len; i++)
        if (terms[i][0] == ':')
          query.attributes.push(RegExp("^(?:"+terms[i].slice(1)+")", "mi"));
        //else if (terms[i][0] == '/')
        //  query.regexps.push(RegExp(terms[i].slice(1,-1), "i"));
        else if (terms[i].indexOf(".") != -1)
          query.fqn_regexps.push(makeRegExp(terms[i]));
        else if (terms[i].indexOf("*") != -1)
          query.regexps.push(makeRegExp(terms[i]));
        else
          query.regexps.push(RegExp(RegExp.escape(terms[i]), "i"));
    }
    catch(e) {
      return false;
    }
    this.query = query;
    return terms.length != 0;
  };
  this.sanitizeStr = function() {
    // Strip leading and trailing whitespace.
    this.str = this.$input.val();
    this.str = this.str.strip();
    return this.str;
  };
  return this;
}

/// Prepares symbols for the search algorithm.
function extendSymbols(ul, symbols)
{
  var symlist = symbols.list;
  var li_tags = ul.getElementsByTagName("li");
  if (li_tags.length != symlist.length)
    throw new Error("The number of symbols ({0}) doesn't match the number of \
list items ({1})!".format(li_tags.length, symlist.length));

  // Add the property 'qs_attrs' to all symbol objects.
  // Also add the property 'li', so we can modify the tag's CSS classes.
  if (symbols.symbol_tags)
    for (var i = 0, len = symlist.length; i < len; i++)
    { // Symbols in a module.
      var s = symlist[i];
      // Put each attribute on a new line.
      // Makes it searchable with multiline RegExps.
      var attrs = s.attrs.join("\n");
      if (SymbolKind.isFunction(s.kind) && s.kind != "function")
         attrs += "\nfunction";
      attrs += "\n"+s.kind;
      // If there's no protection attribute: (assume it's in attrs[0])
      if (!SymbolAttr.isProtection(s.attrs[0]))
        attrs += "\npublic"; // Default to public.
      if (attrs[0] == "\n")
        attrs = attrs.slice(1); // Remove leading newline.
      s.qs_attrs = attrs; // Result, e.g.: "function\npublic\nstatic"
      s.li = li_tags[i];
    }
  else // Packages and modules.
    for (var i = 0, len = symlist.length; i < len; i++)
      (s = symlist[i]),
      (s.qs_attrs = s.kind),
      (s.li = li_tags[i]);
}

/// Recursively progresses down the "ul" tree.
function quick_search(qs, symbols)
{
  var hasMatches = false; // Whether any item in the tree matched.
  var hasUnmatched = false; // Whether any item in the tree didn't match.
  for (var i = 0, len = symbols.length; i < len; i++)
  {
    if (qs.cancelSearch) // Did the user cancel?
      return hasMatches | (hasUnmatched << 1);
    var symbol = symbols[i];
    var itemMatched = false; // Whether the current item matched.
    var li = symbol.li; // The associated list item.
    // Reset classes.
    li.removeClass("match|parent_of_match|has_hidden|show_hidden");
    var texts = [symbol.name, symbol.fqn, symbol.qs_attrs];
    var tlist = [qs.query.regexps, qs.query.fqn_regexps, qs.query.attributes];
  SearchLoop:
    for (var j = 0; j < 3; j++)
    {
      var text = texts[j], terms = tlist[j];
      for (var k = 0, len2 = terms.length; k < len2; k++)
        if (text.search(terms[k]) != -1) {
          itemMatched = true;
          break SearchLoop;
        }
    }
    if (itemMatched)
      (li.className += " match"), (hasMatches = true);
    else
      hasUnmatched = true;
    // Visit subnodes.
    if (symbol.sub)
    {
      var res = quick_search(qs, symbol.sub);
      if ((res & 1) && !itemMatched)
        // Mark this if this item didn't match but children of it did.
        (li.className += " parent_of_match"), (hasMatches = true);
      if (res & 2)
        li.className += " has_hidden";
    }
  }
  return hasMatches | (hasUnmatched << 1);
}

/// Reverse iterates over the "ul" tags. No recursion needed.
/// Profiling showed this method is sometimes a bit faster and
/// sometimes a bit slower.
/// TODO: doesn't work atm, needs to be refactored.
function quick_search2(qs, main_ul)
{
  var words = qs.words;
  var ul_tags = qs.ul_tags;
  if (!ul_tags)
    ul_tags = qs.ul_tags = [main_ul].concat($("ul", main_ul).get());
  // Iterate over the list in reverse. Avoids function recursion.
  for (var i = ul_tags.length-1; i >= 0; i--)
  {
    var ul = ul_tags[i];
    var items = ul.childNodes;
    var hasMatches = false; // Whether any item in the tree matched.
    var hasUnmatched = false; // Whether any item in the tree didn't match.
    // Iterate forward over the li items in this ul tag.
    for (var j = 0, len = items.length; j < len; j++)
    {
      if (qs.cancelSearch) // Did the user cancel?
        return hasMatches;
      var item = items[j];
      var itemMatched = false; // Whether the current item matched.
      // Reset classes.
      item.removeClass("match|parent_of_match|has_hidden|show_hidden");
      // childNodes[1] is the <a/> tag or the text node (package names).
      var text = item.firstChild.nextSibling.childNodes[1].textContent;
      for (k in words)
        if (text.search(words[k], "i") != -1)
        {
          itemMatched = hasMatches = true;
          item.className += " match";
          break;
        }
      hasUnmatched |= !itemMatched;
      if (!itemMatched && item.lastChild.hasMatches)
        // Mark this if this item didn't match but children of it did.
        (item.className += " parent_of_match"), (hasMatches = true);
      if (item.lastChild.hasUnmatched)
        item.className += " has_hidden";
    }
    ul.hasMatches = hasMatches; // Whether this ul has any matches.
    ul.hasUnmatched = hasUnmatched; // Whether this ul has any non-matches.
  }
  return main_ul.hasMatches;
}
