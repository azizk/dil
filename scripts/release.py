#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, re
from path import Path
from common import *
from sys import platform
from build import dmd_cmd

# TODO: relocate to module common?
def find_source_files(source, found):
  """ Finds the source files of dil. """
  for root, dirs, files in source.walk():
    found += [root/file for file in map(Path, files) # Iter. over Path objects.
                          if file.ext.lower() in ('.d','.di')]

def copy_files(DIL):
  """ Copies required files to the destination folder. """
  for FILE, DIR in (
      (DIL.DATA/"dilconf.d", DIL.BIN),
      (DIL.DATA/"html.css", DIL.HTMLSRC),
      (DIL.KANDIL/"style.css", DIL.CSS),
      (DIL.KANDIL/"navigation.js", DIL.JS),
      (DIL.KANDIL/"loading.gif", DIL.IMG)):
    FILE.copy(DIR)

def writeMakefile():
  """ Writes a Makefile for building dil to the disk. """
  # TODO: implement.
  pass

def build_dil(*args, **kwargs):
  (cmd, args) = dmd_cmd(*args, **kwargs)
  print cmd % dict(args, files="(files...)")
  os.system(cmd % args)

def update_version(path, major, minor):
  """ Updates the version info in the compiler's source code. """
  code = open(path).read()
  code = re.sub(r"(VERSION_MAJOR\s*=\s*)[\w\d]+;", r"\g<1>%s;"%major, code)
  code = re.sub(r"(VERSION_MINOR\s*=\s*)\d+;", r"\g<1>%s;"%minor, code)
  open(path, "w").write(code)

def main():
  from functools import partial as func_partial
  from optparse import OptionParser

  usage = "Usage: scripts/release.py VERSION [Options]"
  parser = OptionParser(usage=usage)
  add_option = func_partial(parser.add_option, action="store_true",
                            default=False)
  add_option("-s", "--dsymbols", dest="debug_symbols",
    help="generate debug symbols for debug builds")
  add_option("-d", "--docs", dest="docs", help="generate documentation")
  add_option("--7z", dest="_7z", help="create a 7z archive")
  add_option("--gz", dest="tar_gz", help="create a tar.gz archive")
  add_option("--bz2", dest="tar_bz2", help="create a tar.bz2 archive")
  add_option("--zip", dest="zip", help="create a zip archive")
  add_option("--git", dest="git",
    help="use git to check out a clean copy (default is hg)")
  parser.add_option("--src", dest="src", metavar="SRC", default=None,
    help="use SRC folder instead of checking out code using hg or git")
  parser.add_option("--dmd-exe", dest="dmd_exe", metavar="EXE_PATH",
    default="dmd", help="specify EXE_PATH if dmd is not in your PATH")
  parser.add_option("--builddir", dest="builddir", metavar="DIR", default=None,
    help="where to build the release and archives (default is build/)")
  parser.add_option("--winpath", dest="winpath", metavar="P", default=None,
    help="permanently append P to PATH in the Windows (or wine's) registry. "
         "Exits the script.")

  (options, args) = parser.parse_args()

  if options.winpath != None:
    from env_path import append2PATH
    append2PATH(options.winpath, Path(""))
    return

  if len(args) < 1:
    return parser.print_help()
  if len(args) > 1:
    print "Warning! Arguments ignored: " + " ".join(args[1:])

  # Validate the version argument.
  m = re.match(r"((\d)\.(\d\d\d)(-\w+)?)", args[0])
  if not m:
    parser.error("invalid VERSION; format: /\d.\d\d\d(-\w+)?/ E.g.: 1.123")
  matched = m.groups()

  if not Path(options.dmd_exe).exists and not locate_command(options.dmd_exe):
    print "The executable '%s' couldn't be located or does not exist." % \
          options.dmd_exe
    return

  notNone = max
  # Path of the executable of dil.
  DIL_EXE   = Path("bin")/"dil"
  # Name or path to the executable of dmd.
  DMD_EXE   = options.dmd_exe
  DMD_EXE_W = DMD_EXE # Executable to use for Windows builds.
  # The version of dil to be built.
  VERSION, V_MAJOR = matched[:2]
  V_MINOR, V_SUFFIX = map(notNone, matched[2:], ('0', '')) # Default values.

  # Build folder.
  BUILD_DIR = Path(notNone("build", options.builddir))
  # Destination of distributable files.
  DEST      = BUILD_DIR/("dil."+VERSION)
  # The destination of the binaries.
  DEST.BIN  = DEST/"bin"
  BIN       = DEST.BIN # Shortcut to the bin/ folder.
  # The source code folder of dil.
  DEST.SRC  = DEST/"src"
  # Documentation folder of dil.
  DEST.DOC  = DEST/"doc"
  # The JavaScript, CSS and image folders.
  DEST.JS, DEST.CSS, DEST.IMG = DEST.DOC//("js", "css", "img")
  # Destination of syntax highlighted source files.
  DEST.HTMLSRC = DEST.DOC/"htmlsrc"
  # Dil's data/ directory.
  DEST.DATA   = DEST/'data'
  # Dil's fancy documentation format.
  DEST.KANDIL = DEST/"kandil"

  # Temporary directory, deleted in the end.
  TMP       = DEST/"tmp"
  # The list of module files (with info) that have been processed.
  MODLIST   = TMP/"modules.txt"
  # The files to generate documentation for.
  FILES     = []

  # Create the build directory.
  BUILD_DIR.makedirs()
  # Check out a new working copy.
  DEST.rmtree() # First remove the tree.
  if options.src != None:
    Path(options.src).copytree(DEST)
  elif options.git:
    if locate_command('git'):
      os.system("git clone ./ %(DEST)s && cd %(DEST)s && git checkout"%locals())
      (DEST/".git").rmtree() # Remove the .git folder.
    else:
      raise Exception("git is not in your PATH")
  elif locate_command('hg'):
    os.system("hg archive -r tip -t files " + DEST)
  else:
    raise Exception("hg is not in your PATH; specify SRC or use git")
  # Create other directories not available in a clean checkout.
  map(Path.mkdir, (DEST.BIN, DEST.DOC, DEST.HTMLSRC,
                   DEST.CSS, DEST.IMG, DEST.JS, TMP))

  # Find the source code files.
  find_source_files(DEST.SRC, FILES)
  # Filter out files in "src/tests/".
  FILES = [f for f in FILES if not f.startswith(DEST.SRC/"tests")]

  # Make a backup of the original.
  VERSION_D = DEST.SRC/"dil"/"Version.d"
  VERSION_D.copy(TMP/"Version.d")
  # Update the version info.
  update_version(VERSION_D, V_MAJOR, V_MINOR)
  # Restore the original at the end of the build process.

  if options.docs:
    if not DIL_EXE.exists and not locate_command('dil'):
      # TODO: build dil.
      pass
    DOC_FILES = [DEST.KANDIL/"kandil.ddoc", DEST.DATA/"dilconf.d"] + FILES
    versions = ["DDoc"]
    print "***** Generating documentation *****"
    generate_docs(DIL_EXE, DEST.DOC, MODLIST, DOC_FILES, versions, options='-v')

    modlist = read_modules_list(MODLIST)
    generate_modules_js(modlist, DEST.JS/"modules.js")

    print "***** Generating syntax highlighted HTML files *****"
    for args in generate_shl_files2(DIL_EXE, DEST.HTMLSRC, modlist):
      print "hl %s > %s" % args;
    download_jquery(DEST.JS/"jquery.js")

  if platform is 'win32':
    build_linux_binaries = False
    build_windows_binaries = True
  else:
    build_linux_binaries = True
    build_windows_binaries = locate_command("wine") != None
    class BINPath(Path):
      def __div__(self, name):
        """ Converts a Unix path to a Windows path. """
        name = Path.__div__(self, name)
        return name if name.ext != '.exe' else name.replace("/", r"\\")
    BIN = BINPath(BIN)
    DMD_EXE_W = "wine dmd.exe" # Use wine on Linux to build Windows binaries.
    if not build_windows_binaries:
      print "Error: can't build windows binaries: "\
            "wine is not installed or not in PATH."

  # Create partial functions with common parameters.
  # Note: the -inline switch makes the binaries significantly larger on Linux.
  build_dil_rls = func_partial(build_dil, FILES, dmd_exe=DMD_EXE,
                               release=True, optimize=True, inline=True)
  build_dil_dbg = func_partial(build_dil, FILES, dmd_exe=DMD_EXE,
                               debug_info=options.debug_symbols)
  if build_linux_binaries:
    print "***** Building Linux binaries *****"
    # Linux Debug Binaries
    build_dil_dbg(BIN/"dil_d")
    build_dil_dbg(BIN/"dil2_d", versions=["D2"])
    # Linux Release Binaries
    build_dil_rls(BIN/"dil")
    build_dil_rls(BIN/"dil2", versions=["D2"])

  if build_windows_binaries:
    print "***** Building Windows binaries *****"
    build_dil_dbg.keywords['dmd_exe'] = DMD_EXE_W
    build_dil_rls.keywords['dmd_exe'] = DMD_EXE_W
    # Windows Debug Binaries
    build_dil_dbg(BIN/"dil_d.exe")
    build_dil_dbg(BIN/"dil2_d.exe", versions=["D2"])
    # Windows Release Binaries
    build_dil_rls(BIN/"dil.exe")
    build_dil_rls(BIN/"dil2.exe", versions=["D2"])

  print "***** Copying files *****"
  copy_files(DEST)

  # Restore the original. NOTE: is this a good idea?
  (TMP/"Version.d").move(VERSION_D)

  # Build archives
  assert DEST[-1] != Path.sep
  opt = options
  for exec_cmd, cmd in zip((opt.tar_gz, opt.tar_bz2, opt.zip, opt._7z),
    ("tar --owner root --group root -czf %(name)s.tar.gz %(src)s",
     "tar --owner root --group root --bzip2 -cf %(name)s.tar.bz2 %(src)s",
     "zip -q -9 -r %(name)s.zip %(src)s",
     "7zr a %(name)s.7z %(src)s")):
    if not exec_cmd: continue
    if locate_command(cmd):
      print "Error: the utility '%s' is not in your PATH." % cmd
      continue
    cmd = cmd % dict(locals(), name=DEST, src=DEST)
    print cmd
    os.system(cmd)

  if not options.docs:
    DEST.DOC.rmtree()
  TMP.rmtree()

if __name__ == '__main__':
  main()
