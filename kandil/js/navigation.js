/// Author: Aziz Köksal

/// A global object to access various properties of the application.
var kandil = {
  /// The original module loaded normally by the browser (not JavaScript.)
  originalModuleFQN: "",
  /// An object that represents the symbol tree.
  symbolTree: {},
  /// An array of all the lines of this module's source code.
  sourceCode: [],
  /// Represents the package tree (located in generated modules.js).
  packageTree: g_packageTree,
  /// Application settings.
  settings: {
    navbar_width: 250,    /// Initial navigation bar width.
    navbar_minwidth: 180, /// Minimum resizable width.
    default_tab: "#apitab", /// Initial, active tab ("#apitab", "#modtab").
    apitab_label: getPNGIcon("variable")+"Symbols",
    modtab_label: getPNGIcon("module")+"Modules",
  },
  saved: {
    splitbar_pos: function(pos) {
      return pos == undefined ? parseInt(cookie("splitbar_pos")) :
                                (cookie("splitbar_pos", pos, 30), pos);
    }
  },
  msg: {
    failed_module: "Failed loading the module from",
    failed_code: "Failed loading code from",
    loading_code: "Loading source code...",
  },
};

/// Execute when document is ready.
$(function() {
  kandil.originalModuleFQN = kandil.moduleFQN = g_moduleFQN;

  $("#kandil-content").addClass("left_margin");

  // Create the navigation bar.
  var navbar = $("<div id='navbar'/>")
    .append("<p id='navtabs'><span id='apitab' class='current'>"+
            kandil.settings.apitab_label+"</span>"+
            "<span id='modtab'>"+kandil.settings.modtab_label+"</span></p>")
    .append("<div id='panels'><div id='apipanel'/><div id='modpanel'/></div>");

  $("body").append(navbar);
  // Create the quick search text boxes.
  var qs = [new QuickSearch("apiqs", "#apipanel>ul", kandil.symbolTree),
            new QuickSearch("modqs", "#modpanel>ul", kandil.packageTree)];
  $("#apipanel").prepend(qs[0].input);
  $("#modpanel").prepend(qs[1].input).hide(); // Initially hidden.

  initAPIList();

  createSplitbar();

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
    // Create the list.
    createModulesUL(modpanel);
    makeTreeview($("#modpanel > ul"));
    $(".tview a", modpanel).click(handleLoadingModule);
    kandil.packageTree.initList(); // Init the list property.
  }).click(function() { // Add the display handler.
    $("#modpanel").show(); // Display the modules list.
  });

  $(kandil.settings.default_tab).trigger("click");
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
    if (ul.hasClass("filtered")) {
      if (li.hasClass("has_hidden")) {
        if (li.hasClass("closed")) // [+] -> [.]
          li.removeClass("closed");
        else // [.] -> [-]
          li.addClass("show_hidden").removeClass("has_hidden");
      }
      else if (li.hasClass("show_hidden")) // [-] -> [+]
        li.addClass("has_hidden|closed").removeClass("show_hidden");
    }
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

// Creates the split bar for resizing the navigation panel.
function createSplitbar()
{
  var splitbar = $("<div class='splitbar'><div class='handle'/></div>")[0];
  splitbar.isMoving = false; // Moving status of the splitbar.
  var navbar = $("#navbar"), content = $("#kandil-content"),
      body = $("body")[0];
  navbar.prepend(splitbar); // Insert the splitbar into the document.
  // The margin between the navbar and the content.
  var margin = parseInt(content.css("margin-left")) - navbar.width(),
      minwidth = kandil.settings.navbar_minwidth;
  splitbar.setPos = function(x) {
    if (x < minwidth)
      x = minwidth;
    if (x+50 > window.innerWidth)
      x = window.innerWidth - 50;
    navbar.css("width", x);
    content.css("margin-left", x + margin);
  };
  function mouseMoveHandler(e) { splitbar.setPos(e.pageX); }
  function mouseUpHandler(e) {
    if (splitbar.isMoving)
      (splitbar.isMoving = false),
      splitbar.removeClass("moving"), body.removeClass("moving_splitbar"),
      kandil.saved.splitbar_pos(e.pageX), // Save the position.
      $(document).unbind("mousemove", mouseMoveHandler)
                 .unbind("mouseup", mouseUpHandler);
  }
  function mouseDownHandler(e) {
    if (!splitbar.isMoving)
      (splitbar.isMoving = true),
      splitbar.addClass("moving"), body.addClass("moving_splitbar"),
      $(document).mousemove(mouseMoveHandler).mouseup(mouseUpHandler);
    e.preventDefault();
  }
  $(splitbar).mousedown(mouseDownHandler);
  // Set initial position.
  splitbar.setPos(kandil.saved.splitbar_pos() || kandil.navbar_width);
  return splitbar;
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
    if (kandil.originalModuleFQN != kandil.moduleFQN)
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
    var msg = $("<p class='ajaxerror'>'"+kandil.msg.failed_module+
                " '"+doc_url+"'.</p>");
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
        kandil.moduleFQN = modFQN;
        kandil.sourceCode = [];
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
  var root = new M(kandil.moduleFQN);
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
  kandil.symbolTree.root = root;
  kandil.symbolTree.list = list;
  // Create the HTML text and append it to the api panel.
  createSymbolsUL($("#apipanel"));
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

function createSymbolsUL(panel)
{ // TODO: put loading.gif in the center of ul and animate showing/hiding?
  var root = kandil.symbolTree.root;
  var ul = $("<ul class='tview'><li class='root'><i/>"+getPNGIcon("module")+
    "<label><a href='#m-"+root.fqn+"'>"+root.fqn+"</a></label></li>"+
    "<li><img src='img/loading.gif'/></li></ul>");
  panel.append(ul);
  if (root.sub.length)
    $(ul[0].firstChild).append(createSymbolsUL_(root.sub));
  $(ul[0].lastChild).remove();
}

function createModulesUL(panel)
{
  var root = kandil.packageTree.root;
  var ul = $("<ul class='tview'><li class='root'><i/>"+getPNGIcon("package")+
    "<label>/</label></li><li><img src='img/loading.gif'/></li></ul>");
  panel.append(ul);
  if (root.sub.length)
    $(ul[0].firstChild).append(createModulesUL_(root.sub));
  $(ul[0].lastChild).remove();
}

/// Constructs a ul (enclosing nested ul's) from the symbols data structure.
function createSymbolsUL_(symbols)
{
  var list = "<ul>";
  for (var i = 0, len = symbols.length; i < len; i++)
  {
    var sym = symbols[i];
    var hasSubSymbols = sym.sub && sym.sub.length;
    var leafClass = hasSubSymbols ? '' : ' class="leaf"';
    var parts = sym.name.partition(':');
    var label = parts[0], number = parts[1];
    label = number ? label+"<sub>"+number+"</sub>" : label; // An index.
    list += "<li"+leafClass+"><i/>"+getPNGIcon(sym.kind)+
            "<label><a href='#"+sym.fqn+"'>"+label+"</a></label>";
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

/// Extracts the code from the HTML file and sets kandil.sourceCode.
function setSourceCode(html_code)
{
  html_code = html_code.split(/<pre class="sourcecode">|<\/pre>/);
  if (html_code.length == 3)
  { // Get the code between the pre tags.
    var code = html_code[1];
    // Split on newline.
    kandil.sourceCode = code.split(/\n|\r\n?|\u2028|\u2029/);
  }
}

/// Returns the relative URL to the source code of this module.
function getSourceCodeURL()
{
  return "./htmlsrc/" + kandil.moduleFQN + ".html";
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
      line_end = kandil.sourceCode.length -2;
    }
    // Get the code lines.
    var code = kandil.sourceCode.slice(line_beg, line_end+1);
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

  if (kandil.sourceCode.length == 0)
  { // Load the HTML source code file.
    var doc_url = getSourceCodeURL();

    function errorHandler(request, error, exception)
    {
      var msg = $("<p class='ajaxerror'>"+kandil.msg.failed_code+
                  " '"+doc_url+"'.</p>");
      $("body").after(msg);
      fadeOutRemove(msg, 5000, 500);
    }

    displayLoadingGif(kandil.msg.loading_code);
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
