/// Author: Aziz Köksal

/// The original module loaded normally by the browser (not JavaScript.)
var g_originalModuleFQN = "";
/// An object that represents the symbol tree.
var g_symbolTree = {};
/// An array of all the lines of this module's source code.
var g_sourceCode = [];

/// Execute when document is ready.
$(function() {
  g_originalModuleFQN = g_moduleFQN;

  $("#kandil-content").addClass("left_margin");

  // Create the navigation bar.
  var navbar = $("<div id='navbar'/>")
    .append("<p id='navtabs'><span id='apitab' class='current'>"+
                             getPNGIcon("variable")+"Symbols</span>"+
            "<span id='modtab'>"+getPNGIcon("module")+"Modules</span></p>")
    .append("<div id='panels'><div id='apipanel'/><div id='modpanel'/></div>");
  $("body").append(navbar);
  // Create the quick search text boxes.
  var qs = [new QuickSearch("apiqs", "#apipanel>ul", g_symbolTree),
            new QuickSearch("modqs", "#modpanel>ul", g_packageTree)];
  $("#apipanel").prepend(qs[0].input);
  $("#modpanel").prepend(qs[1].input).hide(); // Initially hidden.

  initAPIList();

  // Assign click event handlers for the tabs.
  function makeCurrentTab() {
    $("span.current", this.parentNode).removeClass('current');
    this.addClass('current');
    $("#panels > *:visible").hide(); // Hide all panels.
  }

  $("#apitab").click(makeCurrentTab)
              .click(function() {
    $("#apipanel").show(); // Display the API list.
  });

  $("#modtab").click(makeCurrentTab)
              .click(function lazyLoad() {
    $(this).unbind("click", lazyLoad); // Remove the lazyLoad handler.
    var modpanel = $("#modpanel");
    modpanel.append(createModulesUL(g_packageTree.root)); // Create the list.
    makeTreeview($("#modpanel > ul"));
    $(".tview a", modpanel).click(handleLoadingModule);
    g_packageTree.initList(); // Init the list property.
  }).click(function() { // Add the display handler.
    $("#modpanel").show(); // Display the modules list.
  });

  // $(window).resize(function(){
  //   $("#apipanel > ul").add("#modpanel > ul").each(setHeightOfPanel);
  // });
})

/// Adds treeview functionality to ul. Expects special markup.
function makeTreeview(ul)
{
  ul.addClass("tview");
  function handleIconClick(icon)
  {
    var li = icon.parentNode;
    // First two if-statements are for filtered treeviews.
    // Go from [.] -> [-] -> [+] -> [.]
    if (li.hasClass("has_hidden"))
    {
      if (li.hasClass("closed")) // [+] -> [.]
        li.removeClass("closed");
      else // [.] -> [-]
        li.addClass("show_hidden").removeClass("has_hidden");
    }
    else if (li.hasClass("show_hidden")) // [-] -> [+]
      li.addClass("has_hidden|closed").removeClass("show_hidden");
    else // Normal node. [-] <-> [+]
      li.toggleClass("closed");
  }
  var selected_li = $(">li", ul)[0]; // Default to first li.
  function setSelected(new_li)
  {
    new_li.addClass("selected");
    if (new_li == selected_li)
      return;
    selected_li.removeClass("selected");
    selected_li = new_li;
  }

  ul.mousedown(function(e) {
    var tagName = e.target.tagName;
    // The i-tag represents the icon of the tree node.
    if (tagName == "I")
      handleIconClick(e.target);
    else if (tagName == "A" || tagName == "LABEL" || tagName == "SUB")
    {
      var li = e.target;
      for (; li && li.tagName != "LI";)
        li = li.parentNode;
      if (li) setSelected(li);
    }
  });
}

// Handles a mouse click on a module list item.
function handleLoadingModule(event)
{
  event.preventDefault();
  var modFQN = this.href.slice(this.href.lastIndexOf("/")+1,
                               this.href.lastIndexOf(".html"));
  loadNewModule(modFQN);
}

/*/// Sets the height of a panel. Works with FF, but not Opera :(
function setHeightOfPanel()
{
  var window_height = $(window).height();
  var pos = $(this).offset();
  $(this).css('max-height', window_height - pos.top - 10);
}
*/

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
  makeTreeview($("#apipanel > ul"));

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

  function extractContent(text)
  {
    var start = text.indexOf('<div class="module">'),
        end = text.lastIndexOf('</div>\n</body>');
    return text.slice(start, end);
  }

  function extractTitle(text)
  {
    var start = text.indexOf('<title>'), end = text.indexOf('</title>');
    return text.slice(start+7, end); // '<title>'.length = 7
  }

  displayLoadingGif("Loading module...");
  try {
    $.ajax({url: doc_url, dataType: "text", error: errorHandler,
      success: function(data) {
        // Reset some global variables.
        g_moduleFQN = modFQN;
        g_sourceCode = [];
        document.title = extractTitle(data);
        $("#kandil-content")[0].innerHTML = extractContent(data);
        $("#apipanel > ul").remove(); // Delete old API list.
        initAPIList();
        $("#apiqs")[0].qs.resetFirstClickHandler();
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
function initializeSymbolList(sym_tags)
{
  if (!sym_tags.length)
    return;
  // Prepare the symbol list.
  var header = sym_tags[0]; // Header of the page.
  sym_tags = sym_tags.slice(1); // Every other symbol.

  var symDict = {};
  var root = new M(g_moduleFQN);
  var list = [root];
  symDict[''] = root; // The empty string has to point to the root.
  for (var i = 0, len = sym_tags.length; i < len; i++)
  {
    var sym_tag = sym_tags[i];
    var sym = new Symbol(sym_tag.name, sym_tag.getAttribute("kind"));
    list.push(sym); // Append to flat list.
    symDict[sym.parent_fqn].sub.push(sym); // Append to parent.
    symDict[sym.fqn] = sym; // Insert the symbol itself.
  }
  g_symbolTree.root = root;
  g_symbolTree.list = list;
  // Create the HTML text and append it to the api panel.
  $("#apipanel").append(createSymbolsUL(root));
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

function createSymbolsUL(root)
{
  return "<ul class='tview'><li class='root'>"+
         "<i/>"+getPNGIcon("module")+
         "<label><a href='#m-"+root.fqn+"'>"+root.fqn+"</a></label>"+
         createSymbolsUL_(root.sub)+
         "</li></ul>";
}

function createModulesUL(root)
{
  return "<ul class='tview'><li class='root'>"+
         "<i/>"+getPNGIcon("package")+"<label>/</label>"+
         createModulesUL_(root.sub)+
         "</li></ul>";
}

/// Constructs a ul (enclosing nested ul's) from the symbols data structure.
function createSymbolsUL_(symbols)
{
  var list = "<ul>";
  for (var i = 0, len = symbols.length; i < len; i++)
  {
    var sym = symbols[i];
    var parts = sym.fqn.rpartition(':');
    var fqn = parts[0], count = parts[1];
    var hasSubSymbols = sym.sub && sym.sub.length;
    var leafClass = hasSubSymbols ? '' : ' class="leaf"';
    count = fqn ? "<sub>"+count+"</sub>" : ""; // An index.
    list += "<li"+leafClass+"><i/>"+getPNGIcon(sym.kind)+
            "<label><a href='#"+sym.fqn+"'>"+sym.name+count+"</a></label>";
    if (hasSubSymbols)
      list += createSymbolsUL_(sym.sub);
    list += "</li>";
  }
  return list + "</ul>";
}

/// Constructs a ul (enclosing nested ul's) from the package tree.
function createModulesUL_(symbols)
{
  var list = "<ul>";
  for (var i = 0, len = symbols.length; i < len; i++)
  {
    var sym = symbols[i];
    var hasSubSymbols = sym.sub && sym.sub.length;
    var leafClass = hasSubSymbols ? '' : ' class="leaf"';
    list += "<li"+leafClass+">"+ //  kind='"+sym.kind+"'
            "<i/>"+getPNGIcon(sym.kind)+"<label>";
    if (hasSubSymbols)
      list += sym.name + "</label>" + createModulesUL_(sym.sub);
    else
      list += "<a href='"+sym.fqn+".html'>"+sym.name+"</a></label>"
    list += "</li>";
  }
  return list + "</ul>";
}

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
    var lines = "", srcURL = getSourceCodeURL();
    for (var num = line_beg; num <= line_end; num++)
      lines += '<a href="' + srcURL + '#L' + num + '">' + num + '</a>\n';
    var table = $('<table class="d_code"/>');
    table.append('<tr><td class="d_codelines"><pre>'+lines+'</pre></td>'+
                 '<td class="d_codetext"><pre>'+code+'</pre></td></tr>');
    // Create a container div.
    var div = $('<div class="loaded_code"/>');
    div.append(table);
    $(dt_tag).after(div);
    // Store the created div.
    dt_tag.code_div = div;
  }

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
