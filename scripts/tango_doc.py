#!/usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re
from path import Path
from common import *

def copy_files(DATA, KANDIL, TANGO_DIR, HTML_SRC, DEST):
  """ Copies required files to the destination folder. """
  DEST_JS, DEST_CSS, DEST_IMG = DEST//("js","css","img")
  # Create the destination folders.
  map(Path.mkdir, (DEST_JS, DEST_CSS, DEST_IMG))

  for FILE, DIR in (
      (DATA/"html.css", HTML_SRC), # Syntax highlighted files need html.css.
      (TANGO_DIR/"LICENSE", DEST/"License.txt"), # Tango's license.
      (KANDIL/"style.css", DEST_CSS),
      (KANDIL/"navigation.js", DEST_JS),
      (KANDIL/"loading.gif", DEST_IMG)):
    FILE.copy(DIR)

def get_tango_version(path):
  for line in open(path):
    m = re.search("Major\s*=\s*(\d+)", line)
    if m: major = int(m.group(1))
    m = re.search("Minor\s*=\s*(\d+)", line)
    if m: minor = int(m.group(1))
  return "%s.%s.%s" % (major, minor/10, minor%10)

def write_tango_ddoc(path, revision):
  revision = "?rev=" + revision if revision != None else ''
  open(path, "w").write("""
LICENSE = see $(LINK2 http://www.dsource.org/projects/tango/wiki/LibraryLicense, license.txt)
REPOFILE = http://www.dsource.org/projects/tango/browser/trunk/$(DIL_MODPATH)%s
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
BR = <br/>""" % revision
  )

def main():
  from optparse import OptionParser

  usage = "Usage: scripts/tango_doc.py TANGO_DIR [DESTINATION_DIR]"
  parser = OptionParser(usage=usage)
  parser.add_option("--rev", dest="revision", metavar="REVISION", default=None,
    type="int", help="set the repository REVISION to use in symbol links")

  (options, args) = parser.parse_args()

  if len(args) < 1:
    return parser.print_help()

  # Path to the executable of dil.
  DIL_EXE   = Path("bin")/"dil"
  # The version of Tango we're dealing with.
  VERSION   = ""
  # Root of the Tango source code (from SVN.)
  TANGO_DIR = Path(args[0])
  # The source code folder of Tango.
  TANGO_SRC = TANGO_DIR/"tango"
  # Destination of doc files.
  DEST      = Path(args[1] if len(args) > 1 else 'tangodoc')
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
  # The files to generate documentation for.
  FILES     = []

  build_dil_if_inexistant(DIL_EXE)

  if not TANGO_DIR.exists:
    print "The path '%s' doesn't exist." % TANGO_DIR
    return

  VERSION = get_tango_version(TANGO_SRC/"core"/"Version.d")

  # Create directories.
  DEST.makedirs()
  map(Path.mkdir, (HTML_SRC, TMP, DEST_JS))

  find_source_files(TANGO_SRC, FILES)

  write_tango_ddoc(TANGO_DDOC, options.revision)
  DOC_FILES = [KANDIL/"kandil.ddoc", TANGO_DDOC] + FILES
  versions = ["Windows", "Tango", "DDoc"]
  generate_docs(DIL_EXE, DEST, MODLIST, DOC_FILES, versions, options='-v')

  modlist = read_modules_list(MODLIST)
  generate_modules_js(modlist, DEST_JS/"modules.js")

  for args in generate_shl_files2(DIL_EXE, HTML_SRC, modlist):
    print "hl %s > %s" % args;

  copy_files(DATA, KANDIL, TANGO_DIR, HTML_SRC, DEST)
  download_jquery(DEST/"js"/"jquery.js")

  TMP.rmtree()

  # TODO: create archive (optionally.)
  #from zipfile import ZipFile, ZIP_DEFLATED
  #zfile = ZipFile(DEST/".."/"Tango_doc_"+VERSION+".zip", "w", ZIP_DEFLATED)

if __name__ == "__main__":
  main()
