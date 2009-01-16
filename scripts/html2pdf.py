# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re
from path import Path
from subprocess import call
from common import *

def get_symbols(html_str, module_fqn):
  """ Extracts the symbols from a HTML document. """
  rx = re.compile(r'<a class="symbol [^"]+" name="(?P<fqn>[^"]+)"'
                  r' href="(?P<src>[^"]+)" kind="(?P<kind>[^"]+)"'
                  r' beg="(?P<beg>\d+)" end="(?P<end>\d+)">'
                  r'(?P<name>[^<]+)</a>')
  root = dict(fqn=module_fqn, src="", kind="module", beg="", end="", sub=[])
  symbol_list = {"" : root}
  for m in rx.finditer(html_str):
    symbol = m.groupdict()
    symbol["sub"] = []
    sym_fqn = symbol["fqn"]
    parent_fqn, sep, name = sym_fqn.rpartition('.')
    symbol_list[parent_fqn]["sub"] += [symbol]
    symbol_list[sym_fqn] = symbol
  return symbol_list

def generate_pdf(module_files, dest, tmp, params):
  params_default = {
    "pdf_title": "",
    "cover_title": "Cover Title",
    "author": "",
    "generator": "dil D compiler",
    "subject": "Programming API",
    "keywords": "D programming language",
    "x_html": "HTML", # HTML or XHTML.
    "css_file": "pdf.css",
    "symlink": "", # Prefix for symbol links.
    "nested_toc": False, # Use nested or flat ToC.
    "before_files": [], # Files to put before module pages.
    "after_files": [],  # Files to put after module pages.
    "newpage_modules": [] # Which modules should force a page break.
  }
  params_default.update(params)
  params = params_default

  x_html = params["x_html"]
  symlink = params["symlink"]
  nested_TOC = params["nested_toc"]
  newpage_modules = params["newpage_modules"]
  before_files = params["before_files"]
  after_files = params["after_files"]

  # Define some regular expressions.
  # --------------------------------
  # Matches the href attribute of a symbol link.
  symbol_href_rx = re.compile(r'(<a class="symbol[^"]+" name="[^"]+"'
                              r' href=)"./([^"]+)"')
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
  for html_file in module_files:
    html_str = open(html_file).read()
    # Add symlink as a prefix to "a.symbol" tags.
    html_str = symbol_href_rx.sub(r'\1"%s/\2"' % symlink, html_str)
    # Add symlink as a prefix to the "h1>a.symbol" tag.
    html_str = h1_href_rx.sub(r'\1"%s/\2"' % symlink, html_str)
    # Extract "#content>.module".
    start = html_str.find('<div class="module">')
    end = html_str.rfind('</div>\n<div id="kandil-footer">')
    content = html_str[start:end]
    # Extract module FQN.
    module_fqn = Path(html_file).namebase
    # Extract symbols list.
    symbols = get_symbols(content, module_fqn)
    # Push a tuple.
    html_fragments += [(content, module_fqn, symbols)]
    # Add a new module to the tree.
    module = Module(module_fqn)
    module.symbols = symbols
    module.html_str = content
    package_tree.addModule(module)
  # Sort the list of packages and modules.
  package_tree.sortTree()

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
      '  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
      xmlns=' xmlns="http://www.w3.org/1999/xhtml"')
  html_doc.write(u"""%(doctype)s<html%(xmlns)s>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
  <meta name="author" content="%(author)s"/>
  <meta name="subject" content="%(subject)s"/>
  <meta name="keywords" content="%(keywords)s"/>
  <meta name="generator" content="%(generator)s"/>
  <link href="%(css_file)s" type="text/css" rel="stylesheet" media="all"/>
  <title>%(pdf_title)s</title>
</head>
<body>
<p class="covertitle">%(cover_title)s</p>
<p id="generated_by">generated by <a href="http://code.google.com/p/dil">dil</a></p>
<div id="toc">
  <p class="toc_header">Table of Contents</p>
""".encode("utf-8") % params)

  # Write the Table of Contents.
  # ----------------------------
  def write_nested_TOC(pckg):
    html_doc.write("<ul>")
    for p in pckg.packages:
      html_doc.write("<li kind='p'><a href='#p-%s'>%s</a>" % (p.fqn, p.name))
      if len(p.packages) or len(p.modules):
        write_nested_TOC(p)
      html_doc.write("</li>\n")
    for m in pckg.modules:
      html_doc.write("<li kind='m'><a href='#m-%s'>%s</a></li>\n" %
                     (m.fqn, m.name))
    html_doc.write("</ul>\n")

  html_doc.write("<p>Module list:</p>")
  if nested_TOC: # Write a nested list of modules.
    html_doc.write("<div class='modlist nested'>")
    write_nested_TOC(package_tree.root)
    html_doc.write("</div>")
  else: # Write a flat list of modules.
    html_doc.write("<div class='modlist flat'><ul>")
    for html_fragment, mod_fqn, symbols in html_fragments:
      html_doc.write("<li><a href='#m-%s'>%s</a></li>" % ((mod_fqn,)*2))
    html_doc.write("</ul></div>")
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

  if nested_TOC:
    write_nested_fragments(package_tree.root)
  else:
    for html_fragment, mod_fqn, symbols in html_fragments:
      html_doc.write(html_fragment.encode("utf-8"))

  if after_files:
    html_doc.write("<div class='after_pages'>")
    for f in after_files:
      html_doc.write(open(f).read())
    html_doc.write("</div>")

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