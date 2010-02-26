# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re
from path import Path
from subprocess import call
from common import *
from symbols import *
from time import gmtime, strftime

def write_bookmarks(html_doc, package_tree, sym_dict_all,
                    kind_title_list, kind_list, indices):
  # Notice how the li-tag has only the link and label attribute
  # with no content between the tag itself.
  # The purpose of this is to avoid inflating the size of the PDF, because
  # PrinceXML cannot generate bookmarks from elements which have the style
  # "display:none;".
  # Using this technique it is possible to work around this shortcoming.
  def write_symbol_list(kind, symlist, index):
    letter_dict, letter_list = index
    html_doc.write("<ul>\n")
    # A list of all symbols under the item 'All'.
    html_doc.write("<li link='#index-%s' label='All'>\n" % kind)
    html_doc.write("<ul>\n")
    for s in symlist:
      html_doc.write("<li link='%s' label='%s'></li>\n" %
                     (s.link, s.name))
    html_doc.write("</ul>\n</li>\n")
    # A list of all symbols categorized by their initial letter.
    for letter in letter_list:
      html_doc.write("<li link='#index-%s-%s' label='%s'>" %
                     (kind, letter, letter))
      html_doc.write("<ul>\n")
      for s in letter_dict[letter]:
        html_doc.write("<li link='%s' label='%s'></li>" %
                       (s.link, s.name))
      html_doc.write("</ul>\n</li>\n")
    html_doc.write("</ul>\n")

  def write_symbol_tree(symbol):
    html_doc.write("<ul>\n")
    for s in symbol.sub:
      html_doc.write("<li link='%s' label='%s'>" %
                     (s.link, s.name))
      if len(s.sub): write_symbol_tree(s)
      html_doc.write("</li>\n")
    html_doc.write("</ul>\n")

  def write_module_tree(pckg):
    html_doc.write("<ul>\n")
    for p in pckg.packages:
      html_doc.write("<li link='#p-%s' label='%s'>" %
                     (p.fqn, p.name))
      if len(p.packages) or len(p.modules):
        write_module_tree(p)
      html_doc.write("</li>\n")
    for m in pckg.modules:
      html_doc.write("<li link='#m-%s' label='%s'>" %
                     (m.fqn, m.name))
      write_symbol_tree(m.symbolTree)
      html_doc.write("</li>\n")
    html_doc.write("</ul>\n")

  html_doc.write("<ul id='bookmarks'>\n")
  # Modules.
  html_doc.write("<li link='#module-pages' label='Modules'>")
  write_module_tree(package_tree.root)
  html_doc.write("</li>\n")
  # Indices.
  for label, kind in zip(kind_title_list, kind_list):
    if kind in sym_dict_all:
      html_doc.write("<li link='#index-%s' label='%s'>" % (kind, label))
      write_symbol_list(kind, sym_dict_all[kind], indices[kind])
      html_doc.write("</li>\n")
  html_doc.write("</ul>\n")

def generate_pdf(module_files, dest, tmp, params):
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
  symbol_rx = re.compile(r'(<a class="symbol[^"]+" name=)"([^"]+)"'
                         r' href="./([^"]+)"')
  # Matches the href attribute of "h1.module > a".
  h1_href_rx = re.compile(r'(<h1 class="module"[^>]+><a href=)"./([^"]+)"')

  package_tree = PackageTree() # For Table of Contents.

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
  html_fragments = []
  sym_dict_all = {} # Group symbols by their kind, e.g. class, struct etc.
  for html_file in module_files:
    html_str = open(html_file).read().decode("utf-8")
    # Extract module FQN.
    module_fqn = Path(html_file).namebase
    # Extract symbols list, before symbol_rx.
    sym_dict, cat_dict = get_symbols(html_str, module_fqn)
    # Add symlink as a prefix to "a.symbol" tags.
    html_str = symbol_rx.sub(r'\1"m-%s:\2" href="%s/\3"' %
                             (module_fqn, symlink), html_str)
    # Add symlink as a prefix to the "h1>a.symbol" tag.
    html_str = h1_href_rx.sub(r'\1"%s/\2"' % symlink, html_str)
    # Extract "#content>.module".
    start = html_str.find('<div class="module">')
    end = html_str.rfind('<div id="kandil-footer">')
    content = html_str[start:end]
    # Push a tuple.
    html_fragments += [(content, module_fqn, sym_dict)]
    # Add a new module to the tree.
    module = Module(module_fqn)
    module.sym_dict = sym_dict
    module.cat_dict = cat_dict
    module.html_str = content
    package_tree.addModule(module)
    # Group the symbols in this module.
    for kind, sym_list in cat_dict.iteritems():
      items = sym_dict_all.setdefault(kind, [])
      items += sym_list
  # Sort the list of packages and modules.
  package_tree.sortTree()
  # Sort the list of symbols.
  map(list.sort, sym_dict_all.itervalues())

  # Used for indices and ToC.
  kind_title_list = "Classes Interfaces Structs Unions".split(" ")
  kind_list = "class interface struct union".split(" ")

  # Join the HTML fragments.
  # ------------------------
  print "Joining HTML fragments."
  html_src = tmp/("html2pdf.%s" % x_html.lower())
  html_doc = open(html_src, "w")

  # Write the head of the document.
  params = dict(params, doctype="", xmlns="")
  if x_html == "XHTML":
    params = dict(params, doctype=
      '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"'
      ' "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
      xmlns=' xmlns="http://www.w3.org/1999/xhtml"')
  head = u"""%(doctype)s\n<html%(xmlns)s>
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
  html_doc.write((head % params).encode("utf-8"))
  # Write the Table of Contents.
  # ----------------------------
  def write_module_tree(pckg):
    html_doc.write("\n<ul>")
    for p in pckg.packages:
      html_doc.write("<li kind='p'><a href='#p-%s'>%s</a>" % (p.fqn, p.name))
      if len(p.packages) or len(p.modules):
        write_module_tree(p)
      html_doc.write("</li>\n")
    for m in pckg.modules:
      html_doc.write("<li kind='m'><a href='#m-%s'>%s</a></li>" %
                     (m.fqn, m.name))
    html_doc.write("</ul>\n")

  if first_toc:
    html_doc.write(first_toc)

  html_doc.write("<p>Module list:</p>\n")
  if nested_TOC: # Write a nested list of modules.
    html_doc.write("<div class='modlist nested'>")
    write_module_tree(package_tree.root)
    html_doc.write("</div>")
  else: # Write a flat list of modules.
    html_doc.write("<div class='modlist flat'><ul>")
    for html_fragment, mod_fqn, sym_dict in html_fragments:
      html_doc.write("<li><a href='#m-%s'>%s</a></li>" % ((mod_fqn,)*2))
    html_doc.write("</ul></div>")

  if last_toc:
    html_doc.write(last_toc)

  html_doc.write("<p>Indices:</p>\n")
  html_doc.write("<ul>\n")
  for label, kind in zip(kind_title_list, kind_list):
    if kind in sym_dict_all:
      html_doc.write("<li><a href='#index-%s'>%s</a></li>\n" % (kind, label))
  html_doc.write("</ul>\n")

  # Close <div id="toc">
  html_doc.write("</div>\n")

  # Write the HTML fragments.
  # -------------------------
  def write_nested_fragments(pckg):
    for p in pckg.packages:
      html_doc.write('<h1 id="p-%s" class="package">%s</h1>\n' % ((p.fqn,)*2))
      html_doc.write('<div>')
      if len(p.packages):
        html_doc.write("<p><b>Packages:</b> ")
        html_doc.write(", ".join(["<a href='#p-%s'>%s</a>" % (p_.fqn, p_.name)
                                   for p_ in p.packages]))
        html_doc.write("</p>\n")
      html_doc.write("<p><b>Modules:</b> ")
      html_doc.write(", ".join(["<a href='#m-%s'>%s</a>" % (m.fqn, m.name)
                                 for m in p.modules]))
      html_doc.write("</p>\n</div>")
      write_nested_fragments(p)
    for m in pckg.modules:
      html_doc.write(m.html_str.encode("utf-8"))

  if before_files:
    html_doc.write("<div class='before_pages'>")
    for f in before_files:
      html_doc.write(open(f).read())
    html_doc.write("</div>")

  html_doc.write("<div id='module-pages'>\n")
  if nested_TOC:
    write_nested_fragments(package_tree.root)
  else:
    for html_fragment, mod_fqn, sym_dict in html_fragments:
      html_doc.write(html_fragment.encode("utf-8"))
  html_doc.write("</div>\n")

  if after_files:
    html_doc.write("<div class='after_pages'>")
    for f in after_files:
      html_doc.write(open(f).read())
    html_doc.write("</div>")

  # Prepare indices:
  # ----------------
  # Get {"class": index, "interface": index, ...}.
  indices = dict([(kind, get_index(sym_dict_all[kind]))
                   for kind in kind_list
                     if kind in sym_dict_all])

  # Write the bookmarks tree.
  # -------------------------
  write_bookmarks(html_doc, package_tree, sym_dict_all,
                  kind_title_list, kind_list, indices)

  # Write the indices.
  # ------------------
  html_doc.write("<div id='indices'>\n")
  index_titles= ("Class index,Interface index,"
                 "Struct index,Union index").split(",")
  for title, kind, label in zip(index_titles, kind_list, kind_title_list):
    if kind in sym_dict_all:
      letter_dict, letter_list = indices[kind]
      html_doc.write("<h1 id='index-%s' label='%s'>%s</h1>\n" %
                     (kind, label, title))
      html_doc.write("<dl>\n")
      for letter in letter_list:
        html_doc.write("<dt id='index-%s-%s'>%s</dt>\n" %
                       (kind, letter, letter))
        for sym in letter_dict[letter]:
          html_doc.write("<dd><a href='%s'>%s</a></dd>\n" %
                         (sym.link, sym.name))
      html_doc.write("</dl>\n")
  html_doc.write("</div>\n")

  # Close the document.
  html_doc.write("</body></html>")
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
    for img in ("icon_module.png", "icon_package.png"):
      (SRC.KANDIL.IMG/img).copy(TMP/"img")

  def run(self, *args):
    generate_pdf(*args)
