/// Author: Aziz Köksal

/// Constructs a QuickSearch object.
function QuickSearch(id, tag, symbols, options)
{
  this.options = $.extend({
    text: "Filter...",
    delay: 500, // Delay time after key press until search kicks off.
    callback: quickSearchSymbols,
  }, options);

  this.input = $("<input id='"+id+"' class='filterbox'"+
                 " type='text' value='"+this.options.text+"'/>");
  this.tag = tag; // A selector string for jQuery.
  this.symbols = symbols;
  this.cancelSearch = false;
  this.timeoutId = 0;
  this.callback = this.options.callback;
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
  function firstClickHandler(e) {
    // Clear the text box when clicked the first time.
    $(this).val("").unbind("mousedown", firstClickHandler);
    prepareSymbols($(tag)[0], symbols);
  }
  this.resetFirstClickHandler = function() {
    this.input.mousedown(firstClickHandler);
  };
  this.resetFirstClickHandler();

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

/// Prepares the symbols data structure for the search algorithm.
function prepareSymbols(ul, symbols)
{
  var symlist = symbols.list;
  var li_s = ul.getElementsByTagName("li");
  if (li_s.length != symlist.length)
    throw "The number of symbols ("+li_s.length+") doesn't match the number "+
          "of list items ("+symlist.length+")!";
  for (var i = 0; i < symlist.length; i++)
    symlist[i].li = li_s[i]; // Assign a new property to the symbol.
}

function quickSearchSymbols(qs)
{
  var ul = $(qs.tag)[0]; // Get 'ul' tag.
  var symbols = [qs.symbols.root];
  // Remove the message if present.
  $(ul.lastChild).filter(".no_match_msg").remove();

  qs.words = qs.parse();
  if (qs.words.length == 0)
  {
    removeClasses(ul, "filtered");
    return; // Nothing to do if query is empty.
  }

  ul.className += " filtered";
  if (!(quick_search(qs, symbols) & 1)) // Start the search.
    $(ul).append("<li class='no_match_msg'>No match...</li>");
}

/// Recursively progresses down the "ul" tree.
function quick_search(qs, symbols)
{
  var hasMatches = false; // Whether any item in the tree matched.
  var hasUnmatched = false; // Whether any item in the tree didn't match.
  for (var i = 0; i < symbols.length; i++)
  {
    if (qs.cancelSearch) // Did the user cancel?
      return hasMatches | (hasUnmatched << 1);
    var symbol = symbols[i];
    var itemMatched = false; // Whether the current item matched.
    var li = symbol.li; // The associated list item.
    // Reset classes.
    removeClasses(li, "match parent_of_match has_hidden");
    var text = symbol.name.toLowerCase();
    for (j in qs.words)
      if (text.search(qs.words[j]) != -1)
      {
        itemMatched = hasMatches = true;
        li.className += " match";
        break;
      }
    hasUnmatched |= !itemMatched;
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
