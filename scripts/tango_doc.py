#!/usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re
from shutil import copy, copytree
from path import Path
from common import *

def find_source_files(source, found):
  """ Finds the source files of Tango. """
  for root, dirs, files in source.walk():
    found += [root/file for file in map(Path, files) # Iter. over Path objects.
                          if file.ext.lower() in ('.d','.di')]

def copy_files(DATA, KANDIL, TANGO_DIR, CANDYDOC, HTML_SRC, DEST):
  """ Copies required files to the destination folder. """
  DEST_JS, DEST_CSS, DEST_IMG = DEST//("js","css","img")
  # Create the destination folders.
  for path in (DEST_JS, DEST_CSS): path.exists or path.mkdir()
  # Copy candydoc files.
  for f in ("explorer", "tree", "util"):    copy(CANDYDOC/f+".js", DEST_JS)
  for f in ("decant", "ie56hack", "style"): copy(CANDYDOC/f+".css", DEST_CSS)
  # Avoid possible exception: only copy if the folder doesn't exist.
  not DEST_IMG.exists and copytree(CANDYDOC/"img", DEST_IMG)

  # Syntax highlighted files need html.css.
  copy(DATA/"html.css", HTML_SRC)
  # Tango's license.
  copy(TANGO_DIR/"LICENSE", DEST/"License.txt")

  copy(KANDIL/"style.css", DEST_CSS)
  copy(KANDIL/"navigation.js", DEST_JS)

def generate_docs(DEST, MODLIST, FILES):
  """ Generates documenation files. """
  files_str = ' '.join(FILES)
  args = {'DEST':DEST, 'FILES':files_str, 'MODLIST':MODLIST}
  os.system("dil ddoc %(DEST)s -v -m=%(MODLIST)s -version=Tango -version=Windows -version=DDoc %(FILES)s" % args)

def generate_shl_files(dest, prefix_path, files):
  """ Generates syntax highlighted files. """
  for filepath in files:
    htmlfile = get_module_fqn(prefix_path, filepath) + ".html"
    args = (filepath, dest/htmlfile)
    yield args
    os.system('dil hl --lines --syntax --html %s > "%s"' % args)

def get_tango_version(path):
  for line in open(path):
    m = re.search("Major\s*=\s*(\d+)", line)
    if m: major = int(m.group(1))
    m = re.search("Minor\s*=\s*(\d+)", line)
    if m: minor = int(m.group(1))
  return "%s.%s.%s" % (major, minor/10, minor%10)

def write_tango_ddoc(path):
  open(path, "w").write(
"""LICENSE = see $(LINK2 http://www.dsource.org/projects/tango/wiki/LibraryLicense, license.txt)
CODEURL =
MEMBERTABLE = <table>$0</table>
ANCHOR = <a name="$0"></a>
LP = (
RP = )
LB = [
RB = ]
SQRT = √
NAN = NaN
SUP = <sup>$0</sup>
BR = <br/>"""
  )

def main():
  from sys import argv
  from optparse import OptionParser
  if len(argv) <= 1:
    print "Usage: ./scripts/tango_doc.py /home/user/tango/ [tangodoc/]"
    return

  # The version of Tango we're dealing with.
  VERSION   = ""
  # Root of the Tango source code (from SVN.)
  TANGO_DIR = Path(argv[1])
  # The source code folder of Tango.
  TANGO_SRC = TANGO_DIR/"tango"
  # Destination of doc files.
  DEST      = Path(argv[2] if len(argv) > 2 else 'tangodoc')
  # The JavaScript folder.
  DEST_JS   = DEST/"js"
  # Destination of syntax highlighted source files.
  HTML_SRC  = DEST/"htmlsrc"
  # Dil's data/ directory.
  DATA      = Path('data')
  # Dil's fancy documentation format.
  KANDIL    = Path("kandil")
  # Temporary directory, deleted in the end.
  TMP       = DEST/"tmp"
  # Some DDoc macros for Tango.
  TANGO_DDOC= TMP/"tango.ddoc"
  # The list of module files (with info) that have been processed.
  MODLIST   = TMP/"modules.txt"
  # Candydoc folder.
  CANDYDOC  = TANGO_DIR/"doc"/"html"/"candydoc"
  # The files to generate documentation for.
  FILES     = []

  if not TANGO_DIR.exists:
    print "The path '%s' doesn't exist." % TANGO_DIR
    return
  if not CANDYDOC.exists:
    print "Warning: can't find candydoc folder, the path '%s' doesn't exist." % CANDYDOC
    return

  VERSION = get_tango_version(TANGO_SRC/"core"/"Version.d")

  # Create directories.
  DEST.exists or DEST.makedirs()
  HTML_SRC.exists or HTML_SRC.mkdir()
  TMP.exists or TMP.mkdir()
  DEST_JS.exists or DEST_JS.mkdir()

  find_source_files(TANGO_SRC, FILES)

  write_tango_ddoc(TANGO_DDOC)
  DOC_FILES = [KANDIL/"kandil.ddoc", TANGO_DDOC] + FILES
  generate_docs(DEST, MODLIST, DOC_FILES)

  modlist = read_modules_list(MODLIST)
  generate_modules_js(modlist, DEST_JS/"modules.js")

  for args in generate_shl_files(HTML_SRC, TANGO_DIR, FILES):
    print "dil hl %s > %s" % args;

  copy_files(DATA, KANDIL, TANGO_DIR, CANDYDOC, HTML_SRC, DEST)
  download_jquery(DEST/"js"/"jquery.js")

  TMP.rmtree()

  # TODO: create archive (optionally.)
  #from zipfile import ZipFile, ZIP_DEFLATED
  #zfile = ZipFile(DEST/".."/"Tango_doc_"+VERSION+".zip", "w", ZIP_DEFLATED)

if __name__ == "__main__":
  main()
