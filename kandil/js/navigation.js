/// Author: Aziz Köksal

/// Execute when document is ready.
$(function() {
  g_originalModuleFQN = g_moduleFQN;

  $("#kandil-content").add("#kandil-footer").addClass("left_margin");

  // Create the navigation bar.
  var navbar = $("<div id='navbar'/>")
    .append("<p id='navtabs'><span id='apitab' class='current'>API</span>"+
                            "<span id='modtab'>Modules</span></p>")
    .append("<div id='panels'><div id='apipanel'/><div id='modpanel'/></div>");
  $("body").append(navbar);
  // Create the quick search text boxes.
  var qs = [new QuickSearch("apiqs", "#apipanel>ul", quickSearchSymbols),
            new QuickSearch("modqs", "#modpanel>ul", quickSearchSymbols)];
  $("#apipanel").prepend(qs[0].input);
  $("#modpanel").prepend(qs[1].input).hide(); // Initially hidden.

  initAPIList();

//   $("#apipanel > ul").treeview({
//     animated: "fast",
//     collapsed: true
//   })

  // Assign click event handlers for the tabs.
  function makeCurrentTab() {
    $("span.current", this.parentNode).removeClass('current');
    $(this).addClass('current');
    $("#panels > *:visible").hide(); // Hide all panels.
  }

  $("#apitab").click(makeCurrentTab)
              .click(function() {
    $("#apipanel").show(); // Display the API list.
  });

  $("#modtab").click(makeCurrentTab)
              .click(function lazyLoad() {
    // Create the list.
    $("#modpanel").append(createModulesUL(g_moduleObjects));
    $(this).unbind("click", lazyLoad); // Remove the lazyLoad handler.
    $("#modpanel > ul li[kind=module] > a").click(function(event) {
      event.preventDefault();
      var modFQN = this.href.slice(this.href.lastIndexOf("/")+1,
                                   this.href.lastIndexOf(".html"));
      loadNewModule(modFQN);
    });
  })          .click(function() { // Add the display handler.
    $("#modpanel").show(); // Display the modules list.
  });


  // $(window).resize(function(){
  //   $("#apipanel > ul").add("#modpanel > ul").each(setHeightOfPanel);
  // });
})

/*/// Sets the height of a panel. Works with FF, but not Opera :(
function setHeightOfPanel()
{
  var window_height = $(window).height();
  var pos = $(this).offset();
  $(this).css('max-height', window_height - pos.top - 10);
}
*/

/// The original module loaded normally by the browser (not JavaScript.)
var g_originalModuleFQN = "";

/// Adds click handlers to symbols and inits the symbol list.
function initAPIList()
{
  var symbols = $(".symbol");
  // Add code display functionality to symbol links.
  symbols.click(function(event) {
    event.preventDefault();
    showCode($(this));
  });
  initializeSymbolList(symbols);
  $(".symlink").click(function(event) {
    if (g_originalModuleFQN != g_moduleFQN)
      event.preventDefault();
    this.scrollIntoView();
  });
}

/// Delays for 'delay' ms, fades out an element in 'fade' ms and removes it.
function fadeOutRemove(tag, delay, fade)
{
  tag = $(tag);
  setTimeout(function(){
    tag.fadeOut(fade, function(){ tag.remove() });
  }, delay);
}

/// Loads a new module and updates the API panel and the content pane.
function loadNewModule(modFQN)
{
  // Load the module's file.
  var doc_url = modFQN + ".html";

  function errorHandler(request, error, exception)
  {
    var msg = $("<p class='ajaxerror'>Failed loading the module from '"+doc_url+"'.</p>");
    $("body").after(msg);
    fadeOutRemove(msg, 5000, 500);
  }

  function extractModule(text)
  {
    var start = text.indexOf('<div class="module">'),
        end = text.lastIndexOf('</div>\n<div id="kandil-footer">');
    return text.slice(start, end);
  }

  displayLoadingGif("Loading module...");
  try {
    $.ajax({url: doc_url, dataType: "text", error: errorHandler,
      success: function(data) {
        // Reset some global variables.
        g_moduleFQN = modFQN;
        g_sourceCode = [];
        $("#kandil-content")[0].innerHTML = extractModule(data);
        $("#apipanel > ul").remove(); // Delete old API list.
        initAPIList();
      }
    });
  }
  catch(e){ errorHandler(); }
  hideLoadingGif();
}

function displayLoadingGif(msg)
{
  if (!msg)
    msg = "";
  var loading = $("#kandil-loading");
  if (!loading.length)
    (loading = $("<div id='kandil-loading'><img src='img/loading.gif'/>&nbsp;<span/></div>")),
    $("body").append(loading);
  $("span", loading).html(msg);
}

function hideLoadingGif()
{
  fadeOutRemove($("#kandil-loading"), 1, 500);
}

/// Initializes the symbol list under the API tab.
function initializeSymbolList(symbols)
{
  if (!symbols.length)
    return;
  // Prepare the symbol list.
  var header = symbols[0]; // Header of the page.
  symbols = symbols.slice(1); // Every other symbol.

  var itemlist = {};
  itemlist.root = new SymbolItem(header.textContent, "module", header.textContent);
  itemlist[''] = itemlist.root; // The empty string has to point to the root.
  for (var i = 0; i < symbols.length; i++)
  {
    var symbol = symbols[i];
    var parts = rpartition(symbol.name, '.')
    var parentFQN = parts[0], name = parts[1];
    var item = new SymbolItem(symbol.textContent, $(symbol).attr("kind"),
                              symbol.name);
    itemlist[parentFQN].sub.push(item);
    itemlist[item.fqn] = item;
    // TODO: add D attribute information.
  }
  // Create the HTML text and append it to the api panel.
  $("#apipanel").append(createSymbolsUL(itemlist.root.sub));
}

/// A tree item for symbols.
function SymbolItem(name, kind, fqn)
{
  this.name = name; /// The text to be displayed.
  this.kind = kind; /// The kind of this symbol.
  this.fqn = fqn;   /// The fully qualified name.
  this.sub = [];    /// Sub-symbols.
  return this;
}

/// Returns an image tag for the provided kind of symbol.
function getPNGIcon(kind)
{
  var functionSet = {
    "function":1,"unittest":1,"invariant":1,"new":1,"delete":1,
    "invariant":1,"sctor":1,"sdtor":1,"ctor":1,"dtor":1,
  };
  // Other kinds: (they have their own PNG icons)
  // "variable","enummem","alias","typedef","class",
  // "interface","struct","union","template"
  if (functionSet[kind])
    kind = "function";
  return "<img src='img/icon_"+kind+".png' width='16' height='16'/>";
}

function addLIAttributes()
{
  $("#apipanel li").each(function() {
    // TODO:
  })
}

/// Constructs a ul (enclosing nested ul's) from the symbols data structure.
function createSymbolsUL(symbols)
{
  var list = "<ul>";
  for (i in symbols)
  {
    var sym = symbols[i];
    var parts = rpartition(sym.fqn, ':')
    var fqn = parts[0], count = parts[1];
    count = fqn ? "<sub>"+count+"</sub>" : ""; // An index.
    list += "<li>"+getPNGIcon(sym.kind)+
            "<a href='#"+sym.fqn+"'>"+sym.name+count+"</a>";
    if (sym.sub && sym.sub.length)
      list += createSymbolsUL(sym.sub);
    list += "</li>";
  }
  return list + "</ul>";
}

/// Constructs a ul (enclosing nested ul's) from g_moduleObjects.
function createModulesUL(symbols)
{
  var list = "<ul>";
  for (i in symbols)
  {
    var sym = symbols[i];
    list += "<li kind='"+sym.kind+"'>"+getPNGIcon(sym.kind);
    if (sym.sub && sym.sub.length)
      list += sym.name + createModulesUL(sym.sub);
    else
      list += "<a href='"+sym.fqn+".html'>"+sym.name+"</a>"
    list += "</li>";
  }
  return list + "</ul>";
}

/// An array of all the lines of this module's source code.
var g_sourceCode = [];

/// Extracts the code from the HTML file and sets g_sourceCode.
function setSourceCode(html_code)
{
  html_code = html_code.split(/<pre class="sourcecode">|<\/pre>/);
  if (html_code.length == 3)
  { // Get the code between the pre tags.
    var code = html_code[1];
    // Split on newline.
    g_sourceCode = code.split(/\n|\r\n?|\u2028|\u2029/);
  }
}

/// Returns the relative URL to the source code of this module.
function getSourceCodeURL()
{
  return "./htmlsrc/" + g_moduleFQN + ".html";
}

/// Shows the code for a symbol in a div tag beneath it.
function showCode(symbol)
{
  var dt_tag = symbol.parent()[0];
  var line_beg = parseInt(symbol.attr("beg"));
  var line_end = parseInt(symbol.attr("end"));

  if (dt_tag.code_div)
  { // Remove the displayed code div.
    dt_tag.code_div.remove();
    delete dt_tag.code_div;
    return;
  }

  function show()
  { // The function that actually displays the code.
    if ($(dt_tag).is("h1")) { // Special case.
      line_beg = 1;
      line_end = g_sourceCode.length -2;
    }
    // Get the code lines.
    var code = g_sourceCode.slice(line_beg, line_end+1);
    code = code.join("\n");
    // Create the lines column.
    var lines = "";
    for (var i = line_beg; i <= line_end; i++)
      lines += '<a href="'+getSourceCodeURL()+'#L'+i+'">' + i + '</a>\n';
    lines = '<pre class="lines_column">'+lines+'</pre>';
    // Create the code block.
    var block = '<pre class="d_code">'+code+'</pre>';
    var table = $('<table/>').append('<tr><td class="lines">'+lines+'</td><td>'+block+'</td></tr>');
    // Create a container div.
    var div = $('<div class="loaded_code"/>');
    div.append(table);
    $(dt_tag).after(div);
    // Store the created div.
    dt_tag.code_div = div;
  }

  var showCodeHandler;

  if (g_sourceCode.length == 0)
  { // Load the HTML source code file.
    var doc_url = getSourceCodeURL();

    function errorHandler(request, error, exception)
    {
      var msg = $("<p class='ajaxerror'>Failed loading code from '"+doc_url+"'.</p>");
      $("body").after(msg);
      fadeOutRemove(msg, 5000, 500);
    }

    displayLoadingGif("Loading source code...");
    try {
      $.ajax({url: doc_url, dataType: "text", error: errorHandler,
        success: function(data) {
          setSourceCode(data);
          show();
        }
      });
    }
    catch(e){ errorHandler(); }
    hideLoadingGif();
  }
  else // Already loaded. Show the code.
    show();
}

function reportBug()
{
  // TODO: implement.
}

/// Splits a string returning a tuple (head, tail).
function rpartition(str, sep)
{
  var sep_pos = str.lastIndexOf(sep);
  var head = (sep_pos == -1) ? "" : str.slice(0, sep_pos);
  var tail = str.slice(sep_pos+1);
  return [head, tail];
}
