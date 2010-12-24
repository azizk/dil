#!/usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
from common import *
from html2pdf import PDFGenerator
from doc_funcs import *

def copy_files(DIL, TANGO, DEST):
  """ Copies required files to the destination folder. """
  for FILE, DIR in (
      (TANGO.license, DEST/"License.txt"), # Tango's license.
      (DIL.DATA/"html.css", DEST.HTMLSRC),
      (DIL.KANDIL.style,    DEST.CSS)):
    FILE.copy(DIR)
  if TANGO.favicon.exists:
    TANGO.favicon.copy(DEST.IMG/"favicon.png")
  for FILE in DIL.KANDIL.jsfiles:
    FILE.copy(DEST.JS)
  for img in DIL.KANDIL.images:
    img.copy(DEST.IMG)

def get_tango_version(path):
  for line in open(path):
    m = re.search("Major\s*=\s*(\d+)", line)
    if m: major = int(m.group(1))
    m = re.search("Minor\s*=\s*(\d+)", line)
    if m: minor = int(m.group(1))
  return "%s.%s.%s" % (major, minor/10, minor%10)

def write_tango_ddoc(path, favicon, revision):
  revision = "?rev=" + revision if revision != None else ''
  favicon = "" if not favicon.exists else \
    'FAVICON = <link href="img/favicon.png" rel="icon" type="image/png"/>'
  open(path, "w").write(("""
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
""" % locals()).encode("utf-8")
  )

def write_PDF(DIL, SRC, VERSION, TMP):
  TMP = TMP/"pdf"
  TMP.mkdir()

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
  #symlink = "http://dil.googlecode.com/svn/doc/Tango_%s" % VERSION
  symlink = "http://www.dsource.org/projects/tango/docs/" + VERSION
  params = {
    "pdf_title": "Tango %s API" % VERSION,
    "cover_title": "Tango %s<br/><b>API</b>%s" % (VERSION, logo),
    "author": "Tango Team",
    "subject": "Programming API",
    "keywords": "Tango standard library API documentation",
    "x_html": "HTML",
    "nested_toc": True,
    "symlink": symlink
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
  open(dest, 'w').write(text.encode("utf-8"))

def get_tango_path(path):
  path = firstof(Path, path, Path(path))
  path.SRC = path/"import"
  path.is_svn = not path.SRC.exists
  if path.is_svn:
    path.SRC = path/"tango"
    path.SRC.ROOT = path
  path.SRC.object_di = path/"object.di"
  path.license = path/"LICENSE.txt"
  path.favicon = Path("tango_favicon.png") # Look in CWD atm.
  return path

def main():
  from optparse import OptionParser

  usage = "Usage: scripts/tango_doc.py TANGO_DIR [DESTINATION_DIR]"
  parser = OptionParser(usage=usage)
  parser.add_option("--rev", dest="revision", metavar="REVISION", default=None,
    type="int", help="set the repository REVISION to use in symbol links"
                     " (unused atm)")
  parser.add_option("--docs", dest="docs", default=False, action="store_true",
    help="also generate docs if --7z/--pdf specified")
  parser.add_option("--posix", dest="posix", default=False, action="store_true",
    help="define version Posix instead of Win32 and Windows")
  parser.add_option("--7z", dest="_7z", default=False, action="store_true",
    help="create a 7z archive")
  parser.add_option("--pdf", dest="pdf", default=False, action="store_true",
    help="create a PDF document")
  parser.add_option("--pykandil", dest="pykandil", default=False, action="store_true",
    help="use Python code to handle kandil, don't pass --kandil to dil")

  (options, args) = parser.parse_args()
  if type(getitem(args, 0)) == str: # Convert args to unicode.
    args = map(lambda a: a.decode('utf-8'), args)

  if len(args) < 1:
    return parser.print_help()

  if not Path(args[0]).exists:
    return print("The path '%s' doesn't exist." % args[0])

  # True if --docs is given, or neither of --pdf and --7z is true.
  options.docs = options.docs or not (options.pdf or options._7z)

  # 1. Initialize some path variables.
  # Path to dil's root folder.
  dil_dir   = script_parent_folder(__file__) # Look here for dil by default.
  DIL       = dil_path(dil_dir)
  # The version of Tango we're dealing with.
  VERSION   = ""
  # Root of the Tango source code (either svn or zip.)
  TANGO     = get_tango_path(Path(args[0]).abspath)
  # Destination of doc files.
  DEST      = doc_path(getitem(args, 1) or 'tangodoc')
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
  DEST.makedirs()
  map(Path.mkdir, (DEST.HTMLSRC, DEST.JS, DEST.CSS, DEST.IMG, TMP))

  dil_retcode = 0
  if options.docs:
    # 1. Find source files.
    def filter_func(path):
      return path.folder.name in (".svn", "vendor", "rt")
    FILES = [TANGO.SRC.object_di] + find_source_files(TANGO.SRC, filter_func)

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
      return print("Error: dil return code: %d" % dil_retcode)

    # 4. Post processing.
    processed_files = read_modules_list(MODLIST)
    if TANGO.is_svn:
      author_link = 'https://www.ohloh.net/p/dtango/contributors?query={0}'
      rev_link = 'http://www.dsource.org/projects/tango/browser/trunk/{0}?rev={1}'
      insert_svn_info(processed_files, TANGO.SRC.ROOT, DEST,
        rev_link, author_link)

    # Use Python code to do some stuff for 'kandil'.
    if options.pykandil:
      MODULES_JS = (DEST/"js"/"modules.js").abspath
      generate_modules_js(processed_files, MODULES_JS)

    copy_files(DIL, TANGO, DEST)

  # Optionally generate a PDF document.
  if options.pdf:
    write_PDF(DIL, DEST, VERSION, TMP)

  TMP.rmtree()

  archive = "Tango.%s_doc" % VERSION
  create_archives(options, DEST.name, archive, DEST.folder.abspath)

  if dil_retcode == 0:
    print("Python script finished. Exiting normally.")

if __name__ == "__main__":
  main()
