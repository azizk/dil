#!/usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os
from shutil import copy, copytree
from path import Path
from common import getModuleFQN

def find_source_files(source, found):
  """ Finds the source files of Tango. """
  for root, dirs, files in source.walk():
    found += [root/file for file in map(Path, files) # Iter. over Path objects.
                          if file.ext.lower() in ('.d','.di')]

def copy_files(DATA, TANGO_DIR, CANDYDOC, HTML_SRC, DEST):
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

def generate_docs(DEST, FILES):
  """ Generates documenation files. """
  files_str = ' '.join(FILES)
  args = {'DEST':DEST, 'FILES':files_str}
  os.system("dil ddoc %(DEST)s -v -version=Tango -version=Windows -version=DDoc %(FILES)s" % args)

def generate_modules_js():
  # TODO: generate DEST_JS/modules.js
  pass

def generate_shl_files(dest, prefix_path, files):
  """ Generates syntax highlighted files. """
  for filepath in files:
    htmlfile = getModuleFQN(prefix_path, filepath) + ".html"
    args = (filepath, dest/htmlfile)
    yield args
    os.system('dil hl --lines --syntax --html %s > "%s"' % args)

def main():
  from sys import argv
  if len(argv) <= 1:
    print "Usage: ./scripts/tango_doc.py /home/user/tango/ [tangodoc/]"
    return

  # Root of the tango source code (from SVN.)
  TANGO_DIR = Path(argv[1])
  # The source code folder of tango.
  TANGO_SRC = TANGO_DIR/"tango"
  # Destination of doc files.
  DEST      = Path(argv[2] if len(argv) > 2 else 'tangodoc')
  # Destination of syntax highlighted source files.
  HTML_SRC  = DEST/"htmlsrc"
  # Dil's data/ directory.
  DATA      = Path('data')
  # Candydoc folder.
  CANDYDOC  = TANGO_DIR/"doc"/"html"/"candydoc"
  # The files to generate documentation for.
  FILES = []

  if not TANGO_DIR.exists:
    print "The path '%s' doesn't exist." % TANGO_DIR
    return
  if not CANDYDOC.exists:
    print "Warning: can't find candydoc folder, the path '%s' doesn't exist." % CANDYDOC
    return

  DEST.exists or DEST.makedirs()
  HTML_SRC.exists or HTML_SRC.mkdir()

  find_source_files(TANGO_SRC, FILES)
  generate_modules_js()
  generate_docs(DEST, [CANDYDOC/"candy.ddoc"]+FILES)
  for args in generate_shl_files(DEST, TANGO_SRC, FILES):
    print "dil hl %s > %s" % args;
  copy_files(DATA, TANGO_DIR, CANDYDOC, HTML_SRC, DEST)

if __name__ == "__main__":
  main()
