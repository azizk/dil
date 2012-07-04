#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
#
# This is the script that creates release packages for DIL.
#
from __future__ import unicode_literals, print_function
from common import *
from build import DMDCommand, LDCCommand
from html2pdf import PDFGenerator
from html2chm import CHMGenerator
__file__ = tounicode(__file__)

def copy_files(DIL):
  """ Copies required files to the destination folder. """
  for FILE, DIR in (
      (DIL.DATA/"html.css",  DIL.DOC.HTMLSRC),
      (DIL.KANDIL.style,     DIL.DOC.CSS)):
    FILE.copy(DIR)
  for FILE in DIL.KANDIL.jsfiles:
    FILE.copy(DIL.DOC.JS)
  for img in DIL.KANDIL.images:
    img.copy(DIL.DOC.IMG)

def writeMakefile():
  """ Writes a Makefile for building DIL. """
  # TODO: implement.
  pass

def get_totalsize_and_md5sums(FILES, root_index):
  from md5 import new as md5
  totalsize = 0
  md5sums = ""
  for f in FILES:
    totalsize += f.size
    data = f.open("rb", None).read()
    checksum = md5(data).hexdigest()
    md5sums += "%s  %s\n" % (checksum, f[root_index + 1:])
  return (totalsize/1024, md5sums)

def make_deb_package(SRC, DEST, VERSION, ARCH, TMP, PACKAGENUM=1):
  # 1. Create folders.
  TMP = (TMP/"debian").mkdir() # The root folder.
  BIN = (TMP/"usr"/"bin").mkdir()
  DOC = (TMP/"usr"/"share"/"doc"/("dil-"+VERSION)).mkdir()
  OPT = (TMP/"opt"/"dil").mkdir()
  ETC = (TMP/"etc").mkdir()
  DEBIAN = (TMP/"DEBIAN").mkdir()

  # 2. Copy DIL's files.
  for binary in SRC.BINS:
    binary.copy(BIN)
  dilconf = (SRC.DATA/"dilconf.d").open("r").read().replace(
    'DATADIR = "${BINDIR}/../data"', 'DATADIR = "/opt/dil/data"')
  (ETC/"dilconf.d").write(dilconf)
  copyright = "License: GPL3\nAuthors: See AUTHORS file.\n"
  (DOC/"copyright").write(copyright)
  (SRC/"AUTHORS").copy(DOC)
  (SRC.DATA).copytree(OPT/"data")
  (SRC.DOC).copytree(DOC/"api")

  # 3. Get all package files excluding the special DEBIAN folder.
  FILES = TMP.rxglob(".", prunedir=lambda p: p.name == "DEBIAN")

  # 4. Generate package files.
  SIZE, md5sums = get_totalsize_and_md5sums(FILES, len(TMP))

  control = """Package: dil
Version: {VERSION}-{PACKAGENUM}
Section: devel
Priority: optional
Architecture: {ARCH}
Depends:
Provides: d-compiler
Installed-Size: {SIZE}
Maintainer: Aziz Köksal <aziz.koeksal@gmail.com>
Bugs: https://github.com/azizk/dil/issues
Homepage: http://code.google.com/p/dil
Description: D compiler
  DIL is a feature-rich compiler for the D programming language
  written entirely in D.
"""
  control = control.format(**locals())

  # 5. Write the special files.
  (DEBIAN/"control").write(control)
  (DEBIAN/"md5sums").write(md5sums)

  # 6. Create the package.
  NAME = "dil_%s-%s_%s.deb" % (VERSION, PACKAGENUM, ARCH)
  call_proc("dpkg-deb", "--build", TMP, DEST/NAME)
  TMP.rmtree()

def build_dil(CmdClass, *args, **kwargs):
  cmd = CmdClass(*args, **kwargs)
  print(cmd)
  return cmd.call()

def update_version(path, major, minor, suffix):
  """ Updates the version info in the compiler's source code. """
  major, minor = int(major), int(minor)
  code = path.open().read()
  code = re.sub(r"(VERSION_MAJOR\s*=\s*)[\w\d]+;", r"\g<1>%s;" % major, code)
  code = re.sub(r"(VERSION_MINOR\s*=\s*)\d+;", r"\g<1>%s;" % minor, code)
  code = re.sub(r'(VERSION_SUFFIX\s*=\s*)"";', r'\g<1>"%s";' % suffix, code)
  path.write(code)

def write_VERSION(VERSION, DEST):
  (DEST/"VERSION").write("%s\n" % VERSION)

def write_PDF(DIL, SRC, VERSION, TMP):
  pdf_gen = PDFGenerator()
  pdf_gen.fetch_files(DIL, TMP)
  html_files = SRC.glob("*.html")
  sym_url = "http://dl.dropbox.com/u/17101773/doc/dil/{0}" # % VERSION

  params = {
    "pdf_title": "DIL %s API" % VERSION,
    "cover_title": "DIL %s<br/><b>API</b>" % VERSION,
    "author": "Aziz Köksal",
    "subject": "Compiler API",
    "keywords": "DIL D compiler API documentation",
    "x_html": "XHTML",
    "nested_toc": True,
    "sym_url": sym_url
  }
  dest = SRC/("dil.%s.API.pdf" % VERSION)
  pdf_gen.run(html_files, dest, TMP, params)

def write_CHM(DIL, SRC, VERSION, TMP):
  TMP = (TMP/"chm").mkdir()

  chm_gen = CHMGenerator()
  chm_gen.fetch_files(DIL.DOC, TMP)
  html_files = SRC.glob("*.html")
  params = {
    "title": "DIL %s API" % VERSION,
    "default_window": "main",
    "default_topic": "dilconf.html",
  }
  dest = SRC/("dil.%s.API.chm" % VERSION)
  chm_gen.run(html_files, dest, TMP, params)

def build_binaries(COMPILER, V_MAJOR, FILES, DEST):
  from functools import partial as func_partial
  CmdClass = COMPILER.CmdClass

  use_wine = False
  if is_win32:
    build_linux_binaries = False
    build_windows_binaries = True
  else:
    build_linux_binaries = True
    build_windows_binaries = use_wine = locate_command("wine") != None
    class BINPath(Path):
      def __div__(self, name):
        """ Converts a Unix path to a Windows path. """
        name = BINPath(Path.__div__(self, name))
        return name if name.ext != '.exe' else name.replace("/", r"\\")
    DEST = BINPath(DEST)
    if not build_windows_binaries:
      print("Warning: cannot build Windows binaries: 'wine' is not in PATH.")

  # Create partial functions with common parameters (aka. currying).
  # Note: the -inline switch makes the binaries significantly larger on Linux.
  # Enable inlining when DMDBUG #7967 is fixed.
  build_common  = func_partial(build_dil, CmdClass, FILES, exe=COMPILER,
    versions=["D"+V_MAJOR])
  build_release = func_partial(build_common,
    release=True, optimize=True, inline=False, versions=["D"+V_MAJOR])
  build_debug   = func_partial(build_common, debug_info=True)

  for arch in ("32", "64"):
    kwargs = {"m"+arch:True}
    if build_linux_binaries:
      print("\n***** Building Linux %sbit binaries *****\n" % arch)
      B = (DEST/"linux"/("bin" + arch)).mkdir()
      # Important order: ldl must come last, or it won't compile.
      dbgargs = dict(kwargs, lnk_args=["-ltango-dmd", "-lphobos2", "-ldl"])
      build_debug(B/"dil%s_dbg"%V_MAJOR, **dbgargs)
      build_release(B/"dil"+V_MAJOR, **kwargs)

    # No 64bit binaries for Windows yet.
    if build_windows_binaries and arch == "32":
      print("\n***** Building Windows %sbit binaries *****\n" % arch)
      kwargs.update(wine=use_wine)
      B = (DEST/"windows"/("bin" + arch)).mkdir()
      build_debug(B/"dil%s_dbg.exe"%V_MAJOR, **kwargs)
      build_release(B/"dil%s.exe"%V_MAJOR, **kwargs)



def main():
  from functools import partial as func_partial
  from optparse import OptionParser

  usage = "Usage: %s VERSION [Options]" % __file__
  parser = OptionParser(usage=usage)
  add_option = func_partial(parser.add_option, action="store_true",
                            default=False)
  add_option("-s", "--dsymbols", dest="debug_symbols",
    help="generate debug symbols for debug builds")
  add_option("-d", "--docs", dest="docs", help="generate documentation")
  add_option("-n", "--no-bin", dest="no_binaries", help="don't compile code")
  add_option("--7z", dest="_7z", help="create a 7z archive")
  add_option("--gz", dest="tar_gz", help="create a tar.gz archive")
  add_option("--bz2", dest="tar_bz2", help="create a tar.bz2 archive")
  add_option("--zip", dest="zip", help="create a zip archive")
  add_option("--deb", dest="deb", help="create deb files")
  add_option("--pdf", dest="pdf", help="create a PDF document")
  #add_option("--chm", dest="chm", help="create a CHM file")
  add_option("-m", dest="copy_modified",
    help="copy modified files from the (git) working directory")
  parser.add_option("--src", dest="src", metavar="SRC", default=None,
    help="use SRC folder instead of checking out code with git")
  parser.add_option("--cmp-exe", dest="cmp_exe", metavar="EXE_PATH",
    help="specify EXE_PATH if dmd/ldc is not in your PATH")
  add_option("--ldc", dest="ldc", help="use ldc instead of dmd")
  parser.add_option("--builddir", dest="builddir", metavar="DIR", default=None,
    help="where to build the release and archives (default is build/)")
  parser.add_option("--winpath", dest="winpath", metavar="P", default=None,
    help="permanently append P to PATH in the Windows (or wine's) registry. "
         "Exits the script.")

  (options, args) = parser.parse_args(sys.uargv[1:])

  if options.winpath != None:
    from env_path import append2PATH
    append2PATH(options.winpath, Path(""))
    return

  if len(args) < 1:
    return parser.print_help()
  if len(args) > 1:
    print("Warning! Arguments ignored: " + " ".join(args[1:]))

  change_cwd(__file__)

  # Validate the version argument.
  m = re.match(r"((\d)\.(\d{3})(?:-(\w+))?)", args[0])
  if not m:
    parser.error("invalid VERSION; format: /\d.\d\d\d(-\w+)?/ E.g.: 1.123")
  # The version of DIL to be built.
  VERSION, V_MAJOR, V_MINOR, V_SUFFIX = m.groups()
  V_SUFFIX = V_SUFFIX or ''

  # Pick a compiler for compiling DIL.
  CmdClass = (DMDCommand, LDCCommand)[options.ldc]
  COMPILER = Path(options.cmp_exe or CmdClass.exe)
  COMPILER.CmdClass = CmdClass
  if not COMPILER.exists and not locate_command(COMPILER):
    parser.error("The executable '%s' could not be located." % COMPILER)

  # Path to DIL's root folder.
  DIL       = dil_path()

  # Build folder.
  BUILD_DIR = Path(options.builddir or "build")
  # Destination of distributable files.
  DEST      = dil_path(BUILD_DIR/("dil."+VERSION), dilconf=False)
  DEST.DOC  = doc_path(DEST.DOC)

  # Temporary directory, deleted in the end.
  TMP       = DEST/"tmp"
  # The list of module files (with info) that have been processed.
  MODLIST   = TMP/"modules.txt"
  # The source files that need to be compiled and documentation generated for.
  FILES     = []

  # Create the build directory.
  BUILD_DIR.mkdir()
  # Check out a new working copy.
  DEST.rmtree() # First remove the tree.
  if options.src != None:
    # Use the source folder specified by the user.
    src = Path(options.src)
    if not src.exists:
      parser.error("the given SRC path (%s) doesn't exist" % src)
    #if src.ext in ('.zip', '.gz', 'bz2'):
      # TODO:
    src.copytree(DEST)
  else:
    if not locate_command('git'):
      parser.error("'git' is not in your PATH; specify --src instead")
    if not locate_command('tar'):
      parser.error("program 'tar' is not in your PATH")
    # Use git to checkout a clean copy.
    DEST.mkdir()
    TARFILE = DEST/"dil.tar"
    call_proc("git", "archive", "-o", TARFILE, "HEAD")
    call_proc("tar", "-xf", TARFILE.name, cwd=DEST)
    TARFILE.rm()
    if options.copy_modified:
      modified_files = call_read("git", "ls-files", "-m")[:-1]
      if modified_files != "":
        for f in modified_files.split("\n"):
          Path(f).copy(DEST/f)
  # Create other directories not available in a clean checkout.
  DOC = DEST.DOC
  map(Path.mkdir, (DOC, DOC.HTMLSRC, DOC.CSS, DOC.IMG, DOC.JS, TMP))

  # Rebuild the path object for kandil. (Images are globbed.)
  DEST.KANDIL = kandil_path(DEST/"kandil")

  print("***** Copying files *****")
  copy_files(DEST)

  # Find the source code files.
  FILES = find_dil_source_files(DEST.SRC)

  # Update the version info.
  update_version(DEST.SRC/"dil"/"Version.d", V_MAJOR, V_MINOR, V_SUFFIX)
  write_VERSION(VERSION, DEST)

  if options.docs:
    build_dil_if_inexistant(DIL.EXE)

    print("***** Generating documentation *****")
    DOC_FILES = DEST.DATA//("macros_dil.ddoc", "dilconf.d") + FILES
    versions = ["DDoc"]
    generate_docs(DIL.EXE, DEST.DOC, MODLIST, DOC_FILES,
                  versions, options=['-v', '-i', '-hl', '--kandil'])

  if options.pdf:
    write_PDF(DEST, DEST.DOC, VERSION, TMP)
  #if options.chm:
    #write_CHM(DEST, DEST.DOC, VERSION, TMP)

  if not options.no_binaries:
    build_binaries(COMPILER, V_MAJOR, FILES, DEST)
    for p in ("linux", "windows"):
      for bin in ("bin32", "bin64"):
        bin = DEST/p/bin
        if bin.exists: (DIL.DATA/"dilconf.d").copy(bin)

    if options.deb:
      # Make an archive for each version and architecture.
      SRC = Path(DEST)
      SRC.DATA  = DEST.DATA
      SRC.DOC   = DEST.DOC
      BIN_NAMES = ("dil"+V_MAJOR, "dil%s_dbg"%V_MAJOR)
      for bit, arch in (("32", "i386"), ("64", "amd64")):
        # Make 32bit and 64bit packages:
        SRC.BINS  = (SRC/"linux"/"bin"+bit)//BIN_NAMES
        make_deb_package(SRC, DEST.folder, VERSION, arch, DEST)

  # Removed unneeded directories.
  options.docs or DEST.DOC.rmtree()
  TMP.rmtree()

  # Build archives.
  assert DEST[-1] != Path.sep
  create_archives(options, DEST.name, DEST.name, DEST.folder)

  print("Done!")

if __name__ == '__main__':
  main()
