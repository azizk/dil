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
  hpp_file = open(hhp, "w")
  hpp_file.write("""[OPTIONS]
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
  # Close the project file.
  hpp_file.close()

  # Extract symbols and build the package tree.
  package_tree = PackageTree()
  sym_dict_all = {} # Group symbols by their kind, e.g. class, struct etc.
  for html_file in module_files:
    html_str = open(html_file).read()
    # Extract module FQN.
    module_fqn = Path(html_file).namebase
    # Extract symbols list.
    sym_dict, cat_dict = get_symbols(jsons, module_fqn)
    # Add a new module to the tree.
    module = Module(module_fqn)
    module.sym_dict = sym_dict
    package_tree.addModule(module)
    # Group the symbols in this module.
    for kind, sym_list in cat_dict.iteritems():
      items = sym_dict_all.setdefault(kind, [])
      items += sym_list

  # Sort the list of packages and modules.
  package_tree.sortTree()

  # CHM files don't support UTF-8. Therefore Unicode characters
  # are encoded with numerical HTML entities.
  # This step must come after extracting symbols, since
  # symbol links/names may contain Unicode characters.
  def to_num_entity(m):
    return "&#%d;" % ord(m.group(0))
  # Matches any non-ASCII character.
  non_ascii_rx = re.compile(u"[^\x00-\x7F]") #\u0080-\U0010FFFF

  for f in module_files:
    text = unicode(open(f).read())
    text = non_ascii_rx.sub(to_num_entity, text)
    # TODO: deactivate navigation bar somehow.
    open(tmp/f.name, "w").write(text)

  doc_head = """<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
<html>\n<head><meta name="generator" content="dil"></head>
<body>\n"""
  doc_end = "</body>\n</html>"

  def objtag(**kwargs):
    """ Returns an object tag with param tags (can be ommitted.) """
    tags = (("name", '<param name="Name" value="%(name)s">'),
            ("link", '<param name="Local" value="%(link)s">'),
            ("img",  '<param name="ImageNumber" value="%(img)s">'))
    tags = [tag for key, tag in tags if key in kwargs]
    return ('<object type="text/sitemap">'+"".join(tags)+'</object>') % kwargs

  # Write the content references.
  # -----------------------------
  f = open(hhc, "w")
  f.write(doc_head)

  def write_symbol_tree(symbol):
    f.write("<ul>\n")
    for s in symbol.sub:
      symbo_link = "%s.html#%s" % (s.modfqn, s.fqn)
      f.write("<li>" + objtag(name=s.name, link=symbo_link))
      if len(s.sub): write_symbol_tree(s)
      f.write("</li>\n")
    f.write("</ul>\n")

  def write_module_tree(pckg):
    f.write("<ul>\n")
    for p in pckg.packages:
      f.write("<li>" + objtag(name=p.name+"/"))
      if len(p.packages) or len(p.modules): write_module_tree(p)
      f.write("</li>\n")
    for m in pckg.modules:
      f.write("<li>" + objtag(name=m.name, link=m.fqn+".html"))
      write_symbol_tree(m.symbolTree)
      f.write("</li>\n")
    f.write("</ul>\n")

  f.write("<ul>\n")
  f.write('<li>' + objtag(name="Modules"))
  write_module_tree(package_tree.root)
  f.write('</li>')
  # TODO: write references
  f.write("</ul>\n")

  f.write(doc_end)
  f.close()

  # Write the index.
  # ----------------
  f = open(hhk, "w")
  f.write(doc_head)

  # TODO:

  f.write(doc_end)
  f.close()

  # Finally write the CHM file.
  print("Writing CHM file to '%s'." % dest)
  call_hhc(win_path(hhp))

# A script to install HHW on Linux is located here:
# http://code.google.com/p/dil/source/browse/misc/install_hhw.sh
def call_hhc(project_hhp):
  hhc_exe = "hhc.exe" # Assume the exe is in PATH.

  # Get the %ProgramFiles% environment variable.
  # "[is_win32:]" slices off "wine" if on Windows.
  echo_cmd = ["wine", "cmd.exe", "/c", "echo", "%ProgramFiles%"][is_win32:]
  program_files = call_read(echo_cmd)[:-1] # Remove \n.
  # See if "C:\Program Files\HTML Help Workshop\hhc.exe" exists.
  exe = program_files + "\\HTML Help Workshop\\" + hhc_exe
  # Convert back to Unix path if not on Windows.
  if not is_win32: exe = call_read("winepath", "-u", exe)[:-1]
  if Path(exe).exists: hhc_exe = exe

  hhc_exe = ["wine", hhc_exe][is_win32:]

  call(hhc_exe + [project_hhp])

class CHMGenerator:
  def fetch_files(self, SRC, TMP):
    for folder in ("img", "css", "js"):
      (SRC/folder).copytree(TMP/folder)

  def run(self, *args):
    html_files = args[0]
    args += (html_files[0].folder/"symbols",)
    generate_chm(*args)
