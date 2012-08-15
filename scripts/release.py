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
from targets import *
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
    data = f.read(encoding=None)
    checksum = md5(data).hexdigest()
    md5sums += "%s  %s\n" % (checksum, f[root_index + 1:])
  return (totalsize/1024, md5sums)

def make_deb_package(SRC, DEST, VERSION, ARCH, TMP, MAINTAINER, PACKAGENUM=1):
  V_MAJOR = VERSION.MAJ
  # 1. Create folders.
  TMP = (TMP/"debian").mkdir() # The root folder.
  BIN = (TMP/"usr"/"bin").mkdir()
  DOC = (TMP/"usr"/"share"/"doc"/"dil"+V_MAJOR).mkdir()
  MAN = (TMP/"usr"/"share"/"man"/"man1").mkdir()
  SHR = (TMP/"usr"/"share"/"dil"+V_MAJOR).mkdir()
  ETC = (TMP/"etc").mkdir()
  DEBIAN = (TMP/"DEBIAN").mkdir()

  # 2. Copy DIL's files.
  for binary in SRC.BINS:
    binary.copy(BIN)
  dilconf = re.sub('DATADIR = ".+?"', 'DATADIR = "%s/data"' % SHR[len(TMP):],
    (SRC.DATA/"dilconf.d").read())
  (ETC/"dilconf.d").write(dilconf)
  copyright = "License: GPL3\nAuthors: See AUTHORS file.\n"
  (DOC/"copyright").write(copyright)
  CLOG = DOC/"changelog"
  CLOG.write("\n")
  CLOGDEB = DOC/"changelog.Debian"
  CLOGDEB.write("\n")
  (SRC/"AUTHORS").copy(DOC)
  SRC.DATA.copytree(SHR/"data")
  if SRC.DOC.exists:
    SRC.DOC.copytree(DOC/"api")
  MANPAGE = MAN/"dil%s.1" % V_MAJOR
  MANPAGE.write("\n")
  for f in (MANPAGE, CLOG, CLOGDEB):
    call_proc("gzip", "--best", f)
  (MANPAGE+".gz").copy(MAN/"dil%s_dbg.1.gz" % V_MAJOR)

  # 3. Get all package files excluding the special DEBIAN folder.
  FILES = TMP.rxglob(".", prunedir=lambda p: p.name == "DEBIAN")

  # 4. Generate package files.
  SIZE, md5sums = get_totalsize_and_md5sums(FILES, len(TMP))

  # Replace the dash with a dot, because there may be a suffix.
  VERSION = VERSION.replace("-", ".")

  control = """Package: dil{V_MAJOR}
Version: {VERSION}-{PACKAGENUM}
Section: devel
Priority: optional
Architecture: {ARCH}
Depends: libc6
Provides: d-compiler
Installed-Size: {SIZE}
Maintainer: {MAINTAINER}
Bugs: https://github.com/azizk/dil/issues
Homepage: http://code.google.com/p/dil
Description: D compiler
 DIL is a feature-rich compiler for the D programming language
 written entirely in D.
"""
  control = control.format(**locals())

  conffiles = "/etc/dilconf.d\n"

  # 5. Write the special files.
  (DEBIAN/"control").write(control)
  (DEBIAN/"conffiles").write(conffiles)
  (DEBIAN/"md5sums").write(md5sums)
  SCRIPTS = DEBIAN//("postinst", "prerm")
  for script in SCRIPTS:
    script.write("#!/bin/sh\nexit 0\n") # Write empty scripts for now.

  # 6. Set file/dir permissions.
  ALLDIRS = []
  TMP.rxglob(".", prunedir=lambda p: ALLDIRS.append(p))

  for d in ALLDIRS + BIN.rxglob(".") + SCRIPTS:
    call_proc("chmod", "755", d)

  for f in FILES + DEBIAN//("control", "conffiles", "md5sums"):
    call_proc("chmod", "644", f)

  # 7. Create the package.
  NAME = "dil%s_%s-%s_%s.deb" % (V_MAJOR, VERSION, PACKAGENUM, ARCH)
  call_proc("fakeroot", "dpkg-deb", "--build", TMP, DEST/NAME)
  TMP.rmtree()

def get_MAINTAINER(M):
  if M == None:
    if locate_command("git"): # Fetch from git if available.
      name_email = [call_read("git", "config", "user."+x)[:-1]
                    for x in ("name", "email")]
      M = "{} <{}>".format(*name_email)
    else:
      M = "Unknown <un@kn.own>"
  if not re.match(r"^.+? <[^>@]+@[^>]+>$", M):
    print("Warning: 'deb package maintainer' seems to be in the wrong format")
  return M


def build_dil(CmdClass, *args, **kwargs):
  cmd = CmdClass(*args, **kwargs)
  print(cmd)
  return cmd.call()

def update_VERSION(path, V):
  """ Updates the version info in the compiler's source code. """
  code = path.read()
  for args in (("MAJOR", V.MAJ), ("MINOR", int(V.MIN)),
               ("SUFFIX", '"%s"' % V.SFX)):
    code = re.sub("(VERSION_%s =).+?;" % args[0], r"\g<1> %s;" % args[1], code)
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

def build_binaries(TARGETS, COMPILER, V_MAJOR, FILES, DEST):
  from functools import partial as func_partial
  CmdClass = COMPILER.CmdClass

  def fix_dirsep(path, target):
    if not is_win32 and target.iswin: # Wine needs Windows-style paths.
      path = path.replace(Path.sep, r"\\")
    return path

  if not is_win32 and any(t.iswin for t in TARGETS) and \
     not locate_command("wine"):
    print("Warning: cannot build Windows binaries: 'wine' is not in PATH.")
    TARGETS = [t for t in TARGETS if not t.iswin]

  # Create a curried build function with common parameters.
  build_binary  = func_partial(build_dil, CmdClass, FILES, exe=COMPILER,
    versions=["D"+V_MAJOR])

  BINS = [] # Successfully compiled binaries.

  for target in TARGETS:
    print("== Building {name} {bits}bit binary ==".format(**target))
    dbgargs = rlsargs = {"m%d" % target.bits : True}
    if target.iswin:
      dbgargs = rlsargs = dict(rlsargs, wine=not is_win32)
    if target.islin:
      dbgargs = dict(rlsargs, lnk_args=["-ltango-dmd", "-lphobos2", "-ldl"])
    # Destination dir for the binary.
    B = (DEST/target.dir/"bin%d"%target.bits).mkdir()
    DBGEXE, RLSEXE = (B/target[exe] % V_MAJOR for exe in ("dbgexe", "rlsexe"))
    dbgargs.update(debug_info=True)
    build_binary(fix_dirsep(DBGEXE, target), **dbgargs)
    # NB: the -inline switch makes the binaries significantly larger on Linux.
    # Enable inlining when DMDBUG #7967 is fixed.
    rlsargs.update(release=True, optimize=True, inline=False)
    build_binary(fix_dirsep(RLSEXE, target), **rlsargs)
    DBGEXE.target = RLSEXE.target = target
    BINS += [exe for exe in (DBGEXE, RLSEXE) if exe.exists]

  return BINS


def main():
  from functools import partial as func_partial
  from optparse import OptionParser, SUPPRESS_HELP

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
  parser.add_option("--debm", dest="deb_mntnr", metavar="MTR", default=None,
    help=SUPPRESS_HELP) # Sets the maintainer info of the package.
  parser.add_option("--debnum", dest="deb_num", metavar="NUM", default=1,
    help=SUPPRESS_HELP) # Sets the package number.

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
  m = re.match(r"^((\d)\.(\d{3})(?:-(\w+))?)$", args[0])
  if not m:
    parser.error("invalid VERSION; format: /\d.\d\d\d(-\w+)?/ E.g.: 1.123")
  # The version of DIL to be built.
  class Version(unicode):
    def __new__(cls, parts):
      v = unicode.__new__(cls, parts[0])
      v.MAJ, v.MIN, SFX = parts[1:]
      v.SFX = SFX or ''
      return v
  VERSION = Version(m.groups())

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

  print("== Copying files ==")
  copy_files(DEST)

  # Find the source code files.
  FILES = find_dil_source_files(DEST.SRC)

  # Update the version info.
  update_VERSION(DEST.SRC/"dil"/"Version.d", VERSION)
  write_VERSION(VERSION, DEST)

  if options.docs:
    build_dil_if_inexistant(DIL.EXE)

    print("== Generating documentation ==")
    DOC_FILES = DEST.DATA//("macros_dil.ddoc", "dilconf.d") + FILES
    versions = ["DDoc"]
    generate_docs(DIL.EXE, DEST.DOC, MODLIST, DOC_FILES,
                  versions, options=['-v', '-i', '-hl', '--kandil'])

  if options.pdf:
    write_PDF(DEST, DEST.DOC, VERSION, TMP)
  #if options.chm:
    #write_CHM(DEST, DEST.DOC, VERSION, TMP)

  TARGETS = (tlinux32, tlinux64, twindows32)

  if not options.no_binaries:
    BINS = build_binaries(TARGETS, COMPILER, VERSION.MAJ, FILES, DEST)
    for bin in BINS:
      (DIL.DATA/"dilconf.d").copy(bin.folder)

  # Removed unneeded directories.
  options.docs or DEST.DOC.rmtree()
  TMP.rmtree()

  # Build archives.
  assert DEST[-1] != Path.sep
  create_archives(options, DEST.name, DEST.name, DEST.folder)
  if options.deb and not options.no_binaries:
    MTR = get_MAINTAINER(options.deb_mntnr)
    NUM = int(options.deb_num)
    # Make an archive for each architecture.
    SRC = Path(DEST)
    SRC.DATA = DEST.DATA
    SRC.DOC  = DEST.DOC
    LINUX_BINS = [bin for bin in BINS if bin.target.islin]
    for arch in ("i386", "amd64"):
      # Gather the binaries that belong to arch.
      SRC.BINS  = [bin for bin in LINUX_BINS if bin.target.arch == arch]
      make_deb_package(SRC, DEST.folder, VERSION, arch, DEST, MTR, NUM)

  print("Done!")

if __name__ == '__main__':
  main()
