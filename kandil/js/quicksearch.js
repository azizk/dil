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
  this.symlist = $(symlist)[0];
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

function quickSearchSymbols(qs)
{
  if ($(qs.symlist.lastChild).is("p.no_match"))
    qs.symlist.removeChild(qs.symlist.lastChild);

  var words = qs.parse();
  if (words.length == 0)
  {
    $(qs.symlist).removeClass("filtered");
    // Reset classes. Not really needed.
    // var items = symlist.getElementsByTagName("li");
    // for (var i = 0; i < items.length; i++)
    //   items[i].className = "";
    return; // Nothing to do if query is empty.
  }

  // Recursively progresses down the "ul" tree.
  function search(ul)
  {
    var items = ul.childNodes;
    var hasMatches = false;
    for (var i = 0; i < items.length; i++)
    {
      if (qs.cancelSearch) // Did the user cancel?
        return hasMatches;
      var item = items[i];
      item.className = ""; // Reset class.
      // childNodes[1] is the <a/> tag or the text node (package names).
      var text = item.childNodes[1].textContent.toLowerCase();
      for (j in words)
        if (text.search(words[j]) != -1)
        {
          hasMatches = true;
          item.className = "match";
          break;
        }
      // Visit subnodes.
      if (item.lastChild.tagName == "UL")
        if (search(item.lastChild) && item.className == "") // Recursive call.
          // Mark this if this item didn't match but children of it did.
          (item.className = "parent_of_match"), (hasMatches = true);
    }
    return hasMatches;
  }

  qs.symlist.className = "filtered";
  if (!search(qs.symlist.firstChild)) // Start the search.
    $(qs.symlist).append("<p class='no_match'>No match...</p>");
}
