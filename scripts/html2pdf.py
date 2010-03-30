# -*- coding: utf-8 -*-
# Author: Aziz Köksal
from __future__ import unicode_literals
import os, re
from path import Path
from subprocess import call
from common import *
from symbols import *
from time import gmtime, strftime


def write_bookmarks(write, package_tree, all_symbols, index):
  """ Notice how the li-tag has only the link and label attribute
  with no content between the tag itself.
  The purpose of this is to avoid inflating the size of the PDF, because
  PrinceXML cannot generate bookmarks from elements which have the style
  "display:none;".
  Using this technique it is possible to work around this shortcoming. """

  def write_symbol_tree(symbol):
    write('<ul>\n')
    for s in symbol.sub:
      write('<li link="%s" label="%s">' % (s.link, s.name))
      if len(s.sub): write_symbol_tree(s)
      write('</li>\n')
    write('</ul>\n')

  def write_module_tree(pckg):
    write('<ul>\n')
    for p in pckg.packages:
      write('<li link="#p-%s" label="%s">' % (p.fqn, p.name))
      if len(p.packages) or len(p.modules):
        write_module_tree(p)
      write('</li>\n')
    for m in pckg.modules:
      write('<li link="#m-%s" label="%s">' % (m.fqn, m.name))
      write_symbol_tree(m.symbolTree)
      write('</li>\n')
    write('</ul>\n')

  # Begin writing the main ul tag.
  write('<ul id="bookmarks">\n')
  # Write the module tree.
  write('<li link="#module-pages" label="Module Tree">')
  write_module_tree(package_tree.root)
  write('</li>\n') # Close Module Tree.
  write('<li link="#module-pages" label="Module List"><ul>')
  for m in package_tree.modules:
    write('<li link="#m-%s" label="%s">' % (m.fqn, m.name))
    write_symbol_tree(m.symbolTree)
    write('</li>\n')
  write('</ul></li>') # Close Module List.

  # Write the symbol bookmarks.
  write('<li link="#allsyms" label="Symbols">')
  # TODO: also write a subsection "Categorized"?
  # Write a flat list of all symbols.
  write('<ul>')
  current_letter = ''
  for s in all_symbols:
    symbol_letter = s.name[0].upper()
    if symbol_letter != current_letter:
      current_letter = symbol_letter
      write('<li link="#index-syms-%s" label="%s:"></li>' %
            ((current_letter,)*2))
    write('<li link="%s" label="%s">' % (s.link, s.name))
    write_symbol_tree(s)
    write('</li>')
  write('</ul>')
  write('</li>') # Close Symbols li.

  write('</ul>\n') # Close main ul.

def generate_pdf(module_files, dest, tmp, params, jsons):
  params_default = {
    "pdf_title": "",
    "cover_title": "Cover Title",
    "creation_date" : "",
    "author": "",
    "generator": "dil D compiler",
    "subject": "Programming API",
    "keywords": "D programming language",
    "x_html": "HTML", # HTML or XHTML.
    "css_file": "pdf.css",
    "symlink": "", # Prefix for symbol links.
    "nested_toc": False, # Use nested or flat ToC.
    "first_toc": "", # (X)HTML code to put first in the ToC.
    "last_toc": "",  # (X)HTML code to put last in the ToC.
    "before_files": [], # Files to put before module pages.
    "after_files": [],  # Files to put after module pages.
    "newpage_modules": [] # Which modules should force a page break.
  }
  # Override defaults with the provided parameters.
  params = dict(params_default, **params)
  if params["creation_date"] == "":
    params["creation_date"] = strftime("%Y-%m-%dT%H:%M:%S+00:00", gmtime())

  x_html = params["x_html"]
  symlink = params["symlink"]
  nested_TOC = params["nested_toc"]
  newpage_modules = params["newpage_modules"]
  before_files = params["before_files"]
  after_files = params["after_files"]
  first_toc = params["first_toc"]
  last_toc = params["last_toc"]

  # Define some regular expressions.
  # --------------------------------
  # Matches the name and href attributes of a symbol link.
  symbol_rx = re.compile(
    r'(<a class="symbol[^"]*" name=)"([^"]+)" href="htmlsrc/([^#]+)([^"]+)"')
  # Matches the href attribute of "h1.module > a".
  h1_href_rx = re.compile(
    r'(<h1 class="module"[^>]*><a href=)"htmlsrc/([^"]+)"')

  # For Table of Contents, bookmarks and indices.
  package_tree = PackageTree()

  # Add module page-break rules to pdf.css.
  # ---------------------------------------
  if newpage_modules:
    f = open(tmp/params["css_file"], "r+")
    module_page_breaks = "\n".join([
      "h1.module[id=m-%s] { page-break-before: always; }" % fqn
        for fqn in newpage_modules])
    css_text = f.read().replace("/*MODULE_PAGE_BREAKS*/", module_page_breaks)
    f.seek(0)
    f.write(css_text)
    f.truncate()

  # Prepare the HTML fragments.
  # ---------------------------
  print "Preparing HTML fragments."
  cat_dict_all = {} # Group symbols by their kind, e.g. class, struct etc.
  for html_file in module_files:
    html_str = open(html_file).read().decode("utf-8")
    # TODO: adjust links that link to other symbols.
    # e.g. href="#Culture.this" -> href="#m-tango.text.locale.core:Culture.this"

    # Extract module FQN.
    module_fqn = Path(html_file).namebase
    # Extract symbols list, before symbol_rx.
    sym_dict, cat_dict = get_symbols(jsons, module_fqn)
    # Add symlink as a prefix to "a.symbol" tags.
    # The name attribute must be prefixed with "m-%MODULE_FQN%",
    # in order to make the anchor unique in the entire document.
    html_str = symbol_rx.sub(
      r'\1"m-%s:\2" href="%s/\3#\2"' % (module_fqn, symlink), html_str)
    # Add symlink as a prefix to the "h1>a.symbol" tag.
    html_str = h1_href_rx.sub(r'\1"%s/\2"' % symlink, html_str)
    # Extract "#content>.module".
    start = html_str.find('<div class="module">')
    end = html_str.rfind('<div id="kandil-footer">')
    content = html_str[start:end]

    # Add a new module to the tree.
    module = Module(module_fqn)
    module.sym_dict = sym_dict
    module.cat_dict = cat_dict # Symbols categorized by kind.
    module.html_str = content
    package_tree.addModule(module)

    # Group the symbols in this module.
    for kind, symbol_list in cat_dict.iteritems():
      cat_dict_all.setdefault(kind, []).extend(symbol_list)

  # Sort the list of packages and modules.
  package_tree.sortTree()
  # Sort the list of symbols.
  map(list.sort, cat_dict_all.itervalues())

  # Join the HTML fragments.
  # ------------------------
  print "Joining HTML fragments into a single file."
  html_src = tmp/("html2pdf.%s" % x_html.lower())
  html_doc = open(html_src, "w")

  def write(text):
    """ Passes text encoded as UTF-8 to a writer function. """
    if type(text) == unicode: # 'str' objects are assumed to be in UTF-8.
      text = text.encode("utf-8")
    write.out(text)
  write.out = html_doc.write

  # Write the head of the document.
  params = dict(params, doctype="", xmlns="")
  if x_html == "XHTML":
    params = dict(params, doctype=
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"'
      ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">\n',
      xmlns=' xmlns="http://www.w3.org/1999/xhtml"')
  head = u"""%(doctype)s<html%(xmlns)s>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <meta name="author" content="%(author)s"/>
  <meta name="subject" content="%(subject)s"/>
  <meta name="keywords" content="%(keywords)s"/>
  <meta name="date" content="%(creation_date)s"/>
  <meta name="generator" content="%(generator)s"/>
  <link href="%(css_file)s" type="text/css" rel="stylesheet" media="all"/>
  <title>%(pdf_title)s</title>
</head>
<body>
<p class="covertitle">%(cover_title)s</p>
<p id="generated_by">generated by <a href="http://code.google.com/p/dil">dil</a></p>
<div id="toc">
  <p class="toc_header">Table of Contents</p>
"""
  write(head % params)

  # Write the Table of Contents.
  # ----------------------------
  def write_module_tree(pckg):
    write('\n<ul>')
    for p in pckg.packages:
      write(('<li kind="p">'
        '<img src="img/icon_package.svg" class="icon" width="16" height="16"/>'
        ' <a href="#p-%s">%s</a>') % (p.fqn, p.name))
      if len(p.packages) or len(p.modules):
        write_module_tree(p)
      write('</li>\n')
    for m in pckg.modules:
      write(('<li kind="m">'
        '<img src="img/icon_module.svg" class="icon" width="14" height="14"/>'
        ' <a href="#m-%s">%s</a></li>') % (m.fqn, m.name))
    write('</ul>\n')

  if first_toc:
    write(first_toc)

  write('<h1>Modules</h1>\n')
  if nested_TOC: # Write a nested list of modules.
    write('<div class="modlist nested">')
    write_module_tree(package_tree.root)
    write('</div>')
  else: # Write a flat list of modules.
    write('<div class="modlist flat"><ul>')
    for m in package_tree.modules:
      write('<li><a href="#m-%s">%s</a></li>' % ((mod_fqn,)*2))
    write('</ul></div>')

  if last_toc:
    write(last_toc)

  write('<h1>Indices</h1>\n<ul>\n'
    '<li><a href="#allsyms">Index of classes, interfaces, structs, unions</a></li>'
    '</ul>\n')

  # Close <div id="toc">
  write('</div>\n')

  # Write the HTML fragments.
  # -------------------------
  def write_nested_fragments(pckg):
    for p in pckg.packages:
      write('<h1 id="p-%s" class="package">%s</h1>\n' % ((p.fqn,)*2))
      write('<div>')
      if len(p.packages):
        write('<p><b>Packages:</b> ' +
          ', '.join(['<a href="#p-%s">%s</a>' % (p_.fqn, p_.name)
                      for p_ in p.packages]) +
          '</p>\n')
      if len(p.modules):
        write('<p><b>Modules:</b> ' +
          ', '.join(['<a href="#m-%s">%s</a>' % (m.fqn, m.name)
                      for m in p.modules]) +
          '</p>\n')
      write('</div>')
      write_nested_fragments(p)
    for m in pckg.modules:
      write(m.html_str)

  if before_files:
    write('<div class="before_pages">')
    for f in before_files:
      write(open(f).read())
    write('</div>')

  write('<div id="module-pages">\n')
  if nested_TOC:
    write_nested_fragments(package_tree.root)
  else:
    for m in package_tree.modules:
      write(m.html_fragment)
  write('</div>\n')

  if after_files:
    write('<div class="after_pages">')
    for f in after_files:
      write(open(f).read())
    write('</div>')

  # Prepare indices:
  # ----------------
  all_symbols = [] # List of all aggregate types.
  for x in ('class', 'interface', 'struct', 'union'):
    if x in cat_dict_all:
      all_symbols.extend(cat_dict_all[x])
  all_symbols.sort()

  index_by_letter = get_index(all_symbols)

  # Write the bookmarks tree.
  # -------------------------
  write_bookmarks(write, package_tree, all_symbols, index_by_letter)

  # Write the indices.
  # ------------------
  write('<div id="indices">\n'
        '<h1 id="allsyms" label="Index of Symbols">Index of Symbols</h1>\n'
        '<dl>\n')
  letter_dict, letter_list = index_by_letter
  for letter in letter_list:
    write('<dt id="index-syms-%s">%s</dt>\n' % (letter, letter))
    for sym in letter_dict[letter]:
      write('<dd><a href="%s">%s</a></dd>\n' % (sym.link, sym.name))
  write('</dl>\n'
        '</div>\n')

  # Close the document.
  write('</body></html>')
  html_doc.flush()
  html_doc.close()

  # Finally write the PDF document.
  print "Writing PDF document to '%s'." % dest
  call_prince(html_src, dest)

def call_prince(src, dest):
  call(["prince", src, "-o", dest, "-v"])

class PDFGenerator:
  def fetch_files(self, SRC, TMP):
    (SRC.DATA/"pdf.css").copy(TMP)
    (TMP/"img").mkdir()
    for img in ("icon_module.svg", "icon_package.svg"):
      (SRC.KANDIL.IMG/img).copy(TMP/"img")

  def run(self, *args):
    html_files = args[0]
    args += (html_files[0].folder/"symbols",)
    generate_pdf(*args)
