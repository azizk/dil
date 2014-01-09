#!/usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
from html2pdf import PDFGenerator
from doc_funcs import *
__file__ = tounicode(__file__)

def copy_files(DIL, TANGO, DEST):
  """ Copies required files to the destination folder. """
  Paths(TANGO.license,   DIL.DATA/"html.css", DIL.KANDIL.style).copy(\
    (DEST/"License.txt", DEST.HTMLSRC,        DEST.CSS))
  if TANGO.favicon.exists:
    TANGO.favicon.copy(DEST.IMG/"favicon.png")
  DIL.KANDIL.jsfiles.copy(DEST.JS)
  DIL.KANDIL.images.copy(DEST.IMG)

def get_tango_version(path):
  txt = path.open().read()
  numbers = re.findall("(?:Major|Minor)\s*=\s*(\d+)", txt)
  major, minor = map(int, numbers) # Convert the two strings to integers.
  return "%s.%s.%s" % (major, minor/10, minor%10)

def write_tango_ddoc(path, favicon, revision):
  revision = "?rev=" + revision if revision != None else ''
  favicon = "" if not favicon.exists else \
    'FAVICON = <link href="img/favicon.png" rel="icon" type="image/png"/>'
  path.write("""
LICENSE = see $(LINK2 http://www.dsource.org/projects/tango/wiki/LibraryLicense, license.txt)
REPOFILE = http://www.dsource.org/projects/tango/browser/trunk/$(DIL_MODPATH)%(revision)s
EMAIL = &lt;<a href="mailto:$0">$0</a>&gt;
CODEURL =
MEMBERTABLE = <table>$0</table>
ANCHOR = <a name="$0"></a>
LB = [
RB = ]
SQRT = √
NAN = NaN
SUP = <sup>$0</sup>
BR = <br/>
SUB = $1<sub>$2</sub>
POW = $1<sup>$2</sup>
_PI = $(PI $0)
D = <span class="inlcode">$0</span>
LE = &lt;
GT = &gt;
CLN = :
%(favicon)s
""" % locals()
  )

def write_PDF(DIL, SRC, VERSION, TMP):
  TMP = (TMP/"pdf").mkdir()

  pdf_gen = PDFGenerator()
  pdf_gen.fetch_files(DIL, TMP)
  # Get a list of the HTML files.
  html_files = SRC.glob("*.html")
  html_files = filter(lambda path: path.name != "index.html", html_files)
  # Get the logo if present.
  logo_file = Path("logo_tango.png")
  logo = ''
  if logo_file.exists:
    logo_file.copy(TMP)
    logo = "<br/><br/><img src='%s'/>" % logo_file.name
  # Go to this URL when a D symbol is clicked.
  #sym_url = "http://dl.dropbox.com/u/17101773/doc/tango.%s/{0}" % VERSION
  sym_url = "http://www.dsource.org/projects/tango/docs/%s/{0}" % VERSION
  params = {
    "pdf_title": "Tango %s API" % VERSION,
    "cover_title": "Tango %s<br/><b>API</b>%s" % (VERSION, logo),
    "author": "Tango Team",
    "subject": "Programming API",
    "keywords": "Tango standard library API documentation",
    "x_html": "HTML",
    "nested_toc": True,
    "sym_url": sym_url
  }
  pdf_file = SRC/("Tango.%s.API.pdf" % VERSION)
  pdf_gen.run(html_files, pdf_file, TMP, params)

def create_index(dest, prefix_path, files):
  files.sort()
  text = ""
  for filepath in files:
    fqn = get_module_fqn(prefix_path, filepath)
    text += '  <li><a href="%(fqn)s.html">%(fqn)s</a></li>\n' % locals()
  style = "list-style-image: url(img/icon_module.png)"
  text = ("Ddoc\n<ul style='%s'>\n%s\n</ul>"
          "\nMacros:\nTITLE = Index") % (style, text)
  dest.write(text)

def get_tango_path(path):
  path = firstof(Path, path, Path(path))
  path.is_git = (path/".git").exists
  path.SRC = path/"tango" if path.is_git else path/"import"
  path.SRC.ROOT = path
  # path.SRC.object_di = path/"object.di"
  path.license = path/"LICENSE.txt"
  path.favicon = Path("tango_favicon.png") # Look in CWD atm.
  return path

def main():
  from argparse import ArgumentParser

  parser = ArgumentParser()
  addarg = parser.add_argument
  addarg("tango_dir", metavar="TANGO_DIR", nargs=1,
    help="the source dir of Tango")
  addarg("dest_dir", metavar="DESTINATION_DIR", nargs='?',
    help="destination dir of the generated docs")
  addarg("--rev", dest="revision", metavar="REVISION", type=int,
    help="set the repository REVISION to use in symbol links (unused atm)")
  addarg("--docs", dest="docs", action="store_true",
    help="also generate docs if --7z/--pdf specified")
  addarg("--posix", dest="posix", action="store_true",
    help="define version Posix instead of Win32 and Windows")
  addarg("--7z", dest="_7z", action="store_true",
    help="create a 7z archive")
  addarg("--pdf", dest="pdf", action="store_true",
    help="create a PDF document")
  addarg("--pykandil", dest="pykandil", action="store_true",
    help="use Python code to handle Kandil, don't pass --kandil to DIL")

  options = args = parser.parse_args(sys.uargv[1:])

  if not Path(args.tango_dir).exists:
    return print("The path '%s' doesn't exist." % args.tango_dir)

  # True if --docs is given, or neither of --pdf and --7z is true.
  options.docs = options.docs or not (options.pdf or options._7z)

  # 1. Initialize some path variables.
  # Path to DIL's root folder.
  dil_dir   = script_parent_folder(__file__) # Look here for DIL by default.
  DIL       = dil_path(dil_dir)
  # The version of Tango we're dealing with.
  VERSION   = ""
  # Root of the Tango source code (either svn or zip.)
  TANGO     = get_tango_path(Path(args.tango_dir).abspath)
  # Destination of doc files.
  DEST      = doc_path(args.dest_dir or 'tangodoc')
  # Temporary directory, deleted in the end.
  TMP       = (DEST/"tmp").abspath
  # Some DDoc macros for Tango.
  TANGO_DDOC= TMP/"tango.ddoc"
  # The list of module files (with info) that have been processed.
  MODLIST   = TMP/"modules.txt"
  # The files to generate documentation for.
  FILES     = []

  build_dil_if_inexistant(DIL.EXE)

  # 2. Read the version number.
  VERSION = get_tango_version(TANGO.SRC.ROOT/"tango"/"core"/"Version.d")

  # 3. Create directories.
  Paths(DEST, DEST.HTMLSRC, DEST.JS, DEST.CSS, DEST.IMG, TMP).mkdirs()

  dil_retcode = 0
  if options.docs:
    # 1. Find source files.
    def prunedir(path): return path.name in (".svn", ".git", "vendor", "rt")
    # FILES = [TANGO.SRC.object_di] + find_source_files(TANGO.SRC, filter_func)
    FILES = find_source_files(TANGO.SRC, prunedir=prunedir)

    # 2. Prepare files and options to call generate_docs().
    create_index(TMP/"index.d", TANGO.SRC.ROOT, FILES)
    write_tango_ddoc(TANGO_DDOC, TANGO.favicon, options.revision)
    DOC_FILES = [TANGO_DDOC, TMP/"index.d"] + FILES

    versions = ["Tango", "TangoDoc"] + \
               [["Windows", "Win32"], ["Posix"]][options.posix]
    dil_options = ['-v', '-hl', '--kandil']
    if options.pykandil:
      dil_options.pop() # Removes '--kandil'.
      DOC_FILES.insert(0, DIL.KANDIL.ddoc)

    # 3. Generate the documentation.
    dil_retcode = generate_docs(DIL.EXE, DEST.abspath, MODLIST,
      DOC_FILES, versions, dil_options, cwd=DIL)

    if dil_retcode != 0:
      return print("Error: DIL return code: %d" % dil_retcode)

    # 4. Post processing.
    processed_files = read_modules_list(MODLIST)
    if TANGO.is_git:
      pass

    # Use Python code to do some stuff for 'kandil'.
    if options.pykandil:
      MODULES_JS = (DEST/"js"/"modules.js").abspath
      generate_modules_js(processed_files, MODULES_JS)

    copy_files(DIL, TANGO, DEST)

  # Optionally generate a PDF document.
  if options.pdf:
    write_PDF(DIL, DEST, VERSION, TMP)

  TMP.rm()

  archive = "Tango.%s_doc" % VERSION
  create_archives(options, DEST.name, archive, DEST.folder.abspath)

  if dil_retcode == 0:
    print("Python script finished. Exiting normally.")

if __name__ == "__main__":
  main()
