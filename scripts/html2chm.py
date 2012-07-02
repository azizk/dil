# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import print_function
from common import *
from symbols import *

def win_path(p):
  """ Converts a Unix path to a Windows path. """
  return call_read("winepath", "-w", p)[:-1]

def win_paths(ps):
  return map(win_path, ps)

if is_win32: # No conversion needed if on Windows.
  def win_path(p): return p
  def win_paths(ps): return ps

# Binary format documentation: http://www.russotto.net/chm/chmformat.html
def generate_chm(module_files, dest, tmp, params, jsons):
  # On Linux the paths in the project file (hhp) must be in Windows style.
  dest = win_path(dest.abspath)
  hhp, hhc, hhk = tmp//("chm.hhp", "chm.hhc", "chm.hhk")
  params_default = {
    "compatibility": "1.1",
    "default_window": "main",
    "default_topic": "index.html",
    "full_text_search": "YES",
    "title": "CHM",
    "binary_toc": "YES",
    "language": "0x409 English (United States)"
  }
  params = dict(params_default, **params)
  paths = zip(["hhp", "hhc", "hhk"], win_paths([hhp, hhc, hhk]))
  params = dict(params, **dict(paths))
  params["default_topic"] = win_path(tmp/params["default_topic"])

  # List all files to be included in the CHM file:
  file_list = [win_path(tmp/f.name) for f in module_files]
  for folder in ("img", "css", "js"):
    file_list += win_paths((tmp/folder).glob("*"))
  file_list = "\n".join(file_list)

  # Write the project file.
  # -----------------------
  hhp.write("""[OPTIONS]
Compiled file=%(dest)s
Compatibility=%(compatibility)s
Full-text search=%(full_text_search)s
Contents file=%(hhc)s
Default Window=%(default_window)s
Default topic=%(default_topic)s
Index file=%(hhk)s
Language=%(language)s
Binary TOC=%(binary_toc)s
Title=%(title)s

[FILES]
%(file_list)s
""" % dict(locals(), **params))

  # Extract symbols and build the package tree.
  package_tree = PackageTree()
  cat_dict_all = {} # Group symbols by their kind, e.g. class, struct etc.
  for html_file in module_files:
    # Get module FQN.
    module_fqn = Path(html_file).namebase.uni
    # Load the module from a JSON file.
    m = ModuleJSON(jsons, module_fqn)
    package_tree.addModule(m)
    # Group the symbols in this module.
    for kind, symbol_list in m.cat_dict.iteritems():
      cat_dict_all.setdefault(kind, []).extend(symbol_list)

  # Sort the list of packages and modules.
  package_tree.sortTree()
  # Sort the list of symbols.
  map(list.sort, cat_dict_all.itervalues())

  # CHM files don't support UTF-8. Therefore Unicode characters
  # are encoded with numerical HTML entities.
  # The regexp matches any non-ASCII character.
  non_ascii_rx = re.compile("[^\x00-\x7F]") #\u0080-\U0010FFFF
  def escape_uni(text):
    return non_ascii_rx.sub(lambda m: "&#%d;" % ord(m.group(0)), text)

  # Open the files, modify and write them to the tmp dir.
  for html_file in module_files:
    text = html_file.open().read()
    text = escape_uni(text)
    # TODO: deactivate navigation bar somehow.
    (tmp/html_file.name).open("w", encoding=None).write(text)

  doc_head = """<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>\n<head><meta name="generator" content="DIL"></head>
<body>\n"""
  doc_end = "</body>\n</html>"

  def objtag(*args):
    """ Returns an object tag with any number of param tags. """
    ptag = '<param name="%s" value="%s">'
    m = {"name":"Name", "link":"Local", "img":"ImageNumber"}
    tags = "\n".join([ptag % (m[a[0]], a[1]) for a in args])
    return escape_uni('<object type="text/sitemap">\n'+tags+'\n</object>')

  # Write the content references.
  # -----------------------------
  f = open(hhc, "w")
  write = f.write
  write(doc_head)

  def write_symbol_tree(symbol):
    write("<ul>\n")
    for s in symbol.sub:
      symbo_link = "%s.html#%s" % (s.modfqn, s.fqn)
      write("<li>" + objtag(('name',s.name), ('link',symbo_link)))
      if len(s.sub): write_symbol_tree(s)
      write("</li>\n")
    write("</ul>\n")

  def write_module_tree(pckg):
    write("<ul>\n")
    for p in pckg.packages:
      write("<li>" + objtag(('name',p.name+"/")))
      if len(p.packages) or len(p.modules): write_module_tree(p)
      write("</li>\n")
    for m in pckg.modules:
      write("<li>" + objtag(('name',m.name), ('link',m.fqn+".html")))
      write_symbol_tree(m.symbolTree)
      write("</li>\n")
    write("</ul>\n")

  write("<ul>\n")
  write('<li>' + objtag(('name',"Modules")))
  write_module_tree(package_tree.root)
  write('</li>')
  # TODO: write references
  write("</ul>\n")

  write(doc_end)
  f.close()

  # Write the index.
  # ----------------
  f = open(hhk, "w")
  write = f.write
  write(doc_head)

  # TODO:

  write(doc_end)
  f.close()

  # Finally write the CHM file.
  print("Writing CHM file to '%s'." % dest)
  call_hhc(win_path(hhp))

# A script to install HHW on Linux is located here:
# http://code.google.com/p/dil/source/browse/misc/install_hhw.sh
def call_hhc(project_hhp):
  # Get the %ProgramFiles% environment variable.
  # "[is_win32:]" slices off "wine" if on Windows.
  echo_cmd = ["wine", "cmd", "/c", "echo", "%ProgramFiles%"][is_win32:]
  ProgramFiles = call_read(echo_cmd).rstrip("\r\n")
  # See if "C:\Program Files\HTML Help Workshop\hhc.exe" exists.
  hhc_exe = ProgramFiles + "\\HTML Help Workshop\\hhc.exe"
  # Convert back to Unix path if not on Windows.
  if not is_win32:
    hhc_exe = call_read("winepath", "-u", hhc_exe)[:-1]
  if not Path(hhc_exe).exists:
    hhc_exe = "hhc.exe" # Assume the exe is in PATH.

  hhc_cmd = ["wine", hhc_exe, project_hhp][is_win32:]
  call_proc(hhc_cmd)

class CHMGenerator:
  def fetch_files(self, SRC, TMP):
    for folder in ("img", "css", "js"):
      (SRC/folder).copytree(TMP/folder)

  def run(self, *args):
    html_files = args[0]
    args += (html_files[0].folder/"symbols",)
    generate_chm(*args)
