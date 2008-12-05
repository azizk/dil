$(function() {
  // Move permalinks to the end of the node list.
  $(".symlink").each(function() {
    $(this).appendTo(this.parentNode)
           .css({position: "static", right: ""});
  })

  var symbols = $(".symbol");
  // Add code display functionality to symbol links.
  symbols.click(function(event) {
    event.preventDefault();
    showCode($(this));
  })


  var header = symbols[0];
  symbols = symbols.slice(1);

  var itemlist = {}
  itemlist.root = new SymbolItem(header.textContent, "module", header.textContent);
  itemlist[''] = itemlist.root; // The empty string has to point to the root.
  function insertIntoList()
  {
    [parentFQN, name] = rpartition(this.name, '.')
    var sym = new SymbolItem(this.textContent, $(this).attr("kind"), this.name);
    itemlist[parentFQN].sub.push(sym);
    itemlist[sym.fqn] = sym;
  }
  symbols.each(insertIntoList);

  $("#apilist").append(createSymbolsUL(itemlist.root.sub));

//   $("#apilist > ul").treeview({
//     animated: "fast",
//     collapsed: true
//   })

  function makeCurrentTab() {
    $("span.current", this.parentNode).removeClass('current');
    $(this).addClass('current');
  }

  // Assign click event handlers for the tabs.
  $("#apitab").click(makeCurrentTab)
              .click(function() {
    var container = $("#panels");
    $("> div:visible", container).hide();
    $("#apilist", container).show(); // Display the API list.
  })
  $("#modtab").click(makeCurrentTab)
              .click(function() {
    var container = $("#panels");
    $("> div:visible", container).hide();
    var list = $("#modlist:has(ul)", container);
    if (!list.length) {
      list = createModulesList();
      container.append(list.hide()); // Append hidden.
    }
    list.show(); // Display the modules list.
  })
})

/// A tree item for symbols.
function SymbolItem(label, kind, fqn)
{
  this.name = name; /// The text to be displayed.
  this.kind = kind; /// The kind of this symbol.
  this.fqn = fqn; /// The fully qualified name.
  this.sub = []; /// Sub-symbols.
  return this;
}

/// Constructs an unordered list from the symbols data structure.
function createSymbolsUL(symbols)
{
  var list = "<ul>";
  for (i in symbols)
  {
    var sym = symbols[i];
    list += "<li kind='"+sym.kind+"'><a href='#"+sym.fqn+"'>"+sym.name+"</a>";
    if (sym.sub)
      list += createSymbolsUL(sym.sub);
    list += "</li>"
  }
  return list + "</ul>";
}

function createModulesUL(symbols)
{
  var list = "<ul>";
  for (i in symbols)
  {
    var sym = symbols[i];
    list += "<li kind='"+sym.kind+"'><a href='"+sym.fqn+".html'>"+sym.name+"</a>";
    if (sym.sub)
      list += createModulesUL(sym.sub);
    list += "</li>"
  }
  return list + "</ul>";
}

/// Creates an unordered list from the global modules list and appends
/// it to the modlist panel.
function createModulesList()
{
  return $("#modlist").append(createModulesUL(g_moduleObjects));
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
      $(dt_tag).after(msg);
      setTimeout(function(){msg.fadeOut(400, function(){$(this).remove()})}, 4000);
    }

    try {
      $.ajax({url: doc_url, dataType: "text", error: errorHandler,
        success: function(data) {
          setSourceCode(data);
          show();
        }
      });
    }
    catch(e){ errorHandler(); }
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
