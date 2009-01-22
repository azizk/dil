/// Author: Aziz Köksal

/// Constructs a QuickSearch object.
function QuickSearch(id, symlist, callback, options)
{
  this.options = $.extend({
    text: "Filter...",
    delay: 500, // Delay time after key press until search kicks off.
  }, options);

  this.input = $("<input id='"+id+"' class='filterbox'"+
                 " type='text' value='"+this.options.text+"'/>");
  this.symlist = symlist; // A selector string for jQuery.
  this.cancelSearch = false;
  this.timeoutId = 0;
  this.callback = callback;
  this.delayCallback = function() {
    clearTimeout(this.timeoutId);
    QS = this;
    this.timeoutId = setTimeout(function() {
      if (!QS.cancelSearch) QS.callback(QS);
    }, this.options.delay);
  };
  this.input[0].qs = this;
  this.input.keyup(function(e) {
    switch (e.keyCode) {
    case 0:case 9:case 13:case 16:case 17:case 18:
    case 20:case 35:case 36:case 37:case 39:
      break; // Ignore meta keys and other keys.
    case 27: // Escape key.
      this.qs.cancelSearch = true;
      clearTimeout(this.qs.timeoutId);
      break;
    default:
      this.qs.cancelSearch = false;
      this.qs.delayCallback();
    }
  });
  this.input.mousedown(function clearInput(e) {
    // Clear the text box when clicked the first time.
    $(this).val("").unbind("mousedown", clearInput);
  });

  this.str = "";
  this.parse = function() { // Parses the query.
    this.sanitizeStr();
    if (this.str.length == 0)
      return []
    var words = this.str.toLowerCase().split(/\s+/);
    // var attributes = [];
    // for (i in words)
    //   if (words[i][0] == ':')
    //     attributes = words[i];
    return words;
  };
  this.sanitizeStr = function() {
    // Strip leading and trailing whitespace.
    this.str = this.input.val();
    this.str = this.str.replace(/^\s+/, "").replace(/\s+$/, "");
    return this.str;
  };
  return this;
}

/// Removes one or more CSS classes (separated by ' ') from a node.
function removeClasses(node, classes)
{
  classes = classes.split(" ").join("\\b|\\s*\\b");
  rx = RegExp("\\s*\\b"+classes+"\\b", "g");
  node.className = node.className.replace(rx, "");
}

function quickSearchSymbols(qs)
{
  var symlist = $(qs.symlist)[0]; // Get 'ul' tag.
  // Remove the message if present.
  $(symlist.lastChild).filter(".no_match_msg").remove();

  qs.words = qs.parse();
  if (qs.words.length == 0)
  {
    removeClasses(symlist, "filtered");
    // Reset classes. May be needed in the future.
    // var items = symlist.getElementsByTagName("li");
    // for (var i = 0; i < items.length; i++)
    //   items[i].className = "";
    return; // Nothing to do if query is empty.
  }

  symlist.className += " filtered";
  if (!quick_search(qs, symlist)[0]) // Start the search.
    $(symlist).append("<li class='no_match_msg'>No match...</li>");
}

/// Recursively progresses down the "ul" tree.
function quick_search(qs, ul)
{
  var items = ul.childNodes;
  var hasMatches = false; // Whether any item in the tree matched.
  var hasUnmatched = false; // Whether any item in the tree didn't match.
  for (var i = 0; i < items.length; i++)
  {
    if (qs.cancelSearch) // Did the user cancel?
      return hasMatches;
    var item = items[i];
    var itemMatched = false; // Whether the current item matched.
    removeClasses(item, "match parent_of_match has_hidden"); // Reset classes.
    // childNodes[1] is the <a/> tag or the text node (package names).
    var text = item.firstChild.nextSibling.childNodes[1].textContent.toLowerCase();
    for (j in qs.words)
      if (text.search(qs.words[j]) != -1)
      {
        itemMatched = hasMatches = true;
        item.className += " match";
        break;
      }
    hasUnmatched |= !itemMatched;
    // Visit subnodes.
    if (item.lastChild.tagName == "UL")
    {
      var res = quick_search(qs, item.lastChild);
      if (res[0] && !itemMatched)
        // Mark this if this item didn't match but children of it did.
        (item.className += " parent_of_match"), (hasMatches = true);
      if (res[1])
        item.className += " has_hidden";
    }
  }
  return [hasMatches, hasUnmatched];
}

/// Reverse iterates over the "ul" tags. No recursion needed.
/// Profiling showed this method is sometimes a bit faster and
/// sometimes a bit slower.
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
    for (var j = 0; j < items.length; j++)
    {
      if (qs.cancelSearch) // Did the user cancel?
        return hasMatches;
      var item = items[j];
      var itemMatched = false; // Whether the current item matched.
      // Reset classes.
      removeClasses(item, "match parent_of_match has_hidden");
      // childNodes[1] is the <a/> tag or the text node (package names).
      var text = item.firstChild.nextSibling.childNodes[1].textContent.toLowerCase();
      for (k in words)
        if (text.search(words[k]) != -1)
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
