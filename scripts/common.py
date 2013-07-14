# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals, print_function
import re, sys
from utils import *

def find_source_files(src_path, prunefile=None, prunedir=None):
  """ Searches for source files (*.d and *.di)
      and returns a list of matching files. """
  nofilter = lambda x: False
  prunefile, prunedir = (prunefile or nofilter), (prunedir or nofilter)
  srcrx = re.compile(r'\.di?$', re.I)
  def byname(f):
    return srcrx.search(f) and not prunefile(f)
  return Path(src_path).rxglob(byname, prunedir=prunedir)

def find_dil_source_files(source):
  """ Filters out files in "src/tests/". """
  return find_source_files(source, prunedir=r'src[/\\]tests$')

def script_parent_folder(script_path):
  return Path(script_path).realpath.folder.folder

def change_cwd(script_path):
  """ Changes the current working directory to "script_dir/.." """
  script_parent_folder(script_path).chdir()

def kandil_path(where="kandil"):
  P = firstof(Path, where, Path(where))
  P.IMG, P.CSS, P.JS = P/("img", "css", "js")
  P.ddoc    = P/"kandil.ddoc"
  P.style   = P.CSS/"style.css"
  P.jsfiles = P.JS/("navigation.js", "jquery.js", "quicksearch.js",
    "utilities.js", "symbols.js", "treeview.js")
  P.navi, P.jquery, P.qsearch, P.utils, P.syms, P.tview = P.jsfiles
  P.images = P.IMG.glob("*.png") + P.IMG.glob("*.gif")
  return P

def dil_path(where="", dilconf=True):
  P = firstof(Path, where, Path(where))
  P.BIN = P/"bin" # The destination of the binaries.
  P.EXE = P.BIN/"dil" # The compiled binary.
  P.SRC = P/"src" # The source code folder.
  P.DOC = P/"doc" # Documentation folder.
  # Default to these values:
  P.DATA = P/"data" # The data folder with various files.
  P.KANDIL = P/"kandil" # Kandil's folder.
  # Paths might differ because of the settings in dilconf.
  if dilconf:
    exe_path = P.EXE if P.EXE.exists else locate_command("dil")
    if exe_path:
      P.BIN = exe_path.folder # Update binary folder.
      P.EXE = exe_path # Update exe path.
      # Get the settings from dil.
      sttngs = call_read(exe_path, "set")
      sttngs = dict(re.findall("^(\w+)=(.+)", sttngs[:-1], re.MULTILINE))
      # Set the actual paths.
      P.DATA = Path(sttngs['DATADIR']).normpath
      P.KANDIL = Path(sttngs['KANDILDIR']).normpath
      if not P.KANDIL.exists:
        P.KANDIL = P.DATA/"kandil" # Assume kandil/ is in data/.
  P.KANDIL = kandil_path(P.KANDIL) # Extend the path object.
  return P

def doc_path(where):
  P = firstof(Path, where, Path(where))
  P.HTMLSRC = P/"htmlsrc" # Destination of syntax highlighted source files.
  P.SYMBOLS = P/"symbols" # JSON files.
  P.JS, P.CSS, P.IMG = P/("js", "css", "img")
  return P

def get_module_fqn(prefix_path, filepath):
  """ Returns the fully qualified module name (FQN) of a D source file.
    Note: this might not match with the module declaration
          in the source file. """
  # Remove prefix and strip off path separator.
  # E.g.: prefix_path/std/format.d -> std/format.d
  filepath = filepath[len(prefix_path):].lstrip(Path.sep)
  # Remove the extension.
  # E.g.: std/format.d - > std/format
  filepath = Path(filepath).noext
  # Finally replace the path separators.
  return filepath.replace(Path.sep, '.') # E.g.: std/format -> std.format

def read_modules_list(path):
  rx = re.compile(r"^(?P<path>[^,]+), (?P<fqn>\w+(?:\.\w+)*)$")
  return [match.groupdict() for match in map(rx.match, open(path)) if match]

def generate_modules_js(modlist, dest_path, max_line_len=80):
  """ Generates a JavaScript file with a list of fully qual. module names.
      Note: This function is also in "src/cmd/DDoc.d". """
  if not len(modlist):
    raise Exception("modlist must not be empty")
  from symbols import Module, PackageTree
  # Create a new PackageTree.
  package_tree = PackageTree()
  # Open the file and begin writing to it.
  f = open(dest_path, "w")
  f.write('var g_moduleList = [\n ') # Write a flat list of FQNs.
  line_len = 0
  for mod in modlist:
    mod = mod['fqn']
    line = ' "%s",' % mod
    line_len += len(line)
    if line_len >= max_line_len: # See if we have to start a new line.
      line_len = len(line)+1 # +1 for the space in "\n ".
      line = "\n " + line
    f.write(line)

    # Construct the package tree with modules as leafs.
    package_tree.addModule(Module(mod))
  f.write('\n];\n\n') # Closing ].

  def writePackage(package, indent='  '):
    """ Writes the sub-packages and sub-modules of a package to the disk. """
    for p in package.packages:
      f.write("%sP('%s',[\n" % (indent, p.fqn))
      writePackage(p, indent+'  ')
      f.write(indent+"]),\n")
    for m in package.modules:
      f.write("%sM('%s'),\n" % (indent, m.fqn))

  # Sort the tree.
  package_tree.sortTree()
  # Write the packages and modules as JavaScript objects.
  f.write("var g_packageTree = new PackageTree(P('', [\n");
  writePackage(package_tree.root)
  f.write('])\n);\n')

  from time import time
  timestamp = "\nvar g_creationTime = %d;\n" % int(time())
  f.write(timestamp)

  f.close()

def generate_docs(dil_exe, dest, modlist, files,
                  versions=[], options=[], cwd=None):
  """ Generates documenation files. """
  versions = ["-version="+v for v in versions]
  args = ["ddoc", dest, "-m="+modlist] + options + versions + files
  return call_proc(dil_exe, *args, cwd=cwd)

def generate_pymodules(dil_exe, dest, files, options=[], cwd=None):
  """ Generates Python source files. """
  return call_proc(dil_exe, "py", dest, *options + files, cwd=cwd)

def create_archives(opts, src, dest, cwd):
  """ Calls archiving programs to archive the src folder. """
  cwd = cwd or None # Causes exception in call() if empty string.
  for which, cmd in zip(
    ('tar_gz', 'tar_bz2', 'tar_xz', 'zip', '_7z'),
    ("tar --owner root --group root -acf %(name)s.tar.gz",
     "tar --owner root --group root -acf %(name)s.tar.bz2",
     "tar --owner root --group root -acf %(name)s.tar.xz",
     "zip -q -9 -r %(name)s.zip",
     "7za a %(name)s.7z")):
    if not getattr(opts, which, False): continue
    cmd = cmd.split(' ') # Split into array as call() requires it.
    if not locate_command(cmd[0]):
      print("Error: the utility '%s' is not in your PATH." % cmd[0])
      continue
    cmd[-1] = cmd[-1] % {'name':dest} # Format the destination parameter.
    cmd += [src] # Append the src parameter.
    print("\n", " ".join(cmd))
    call_proc(cmd, cwd=cwd) # Call the program.

def make_archive(src, dest):
  """ Calls a compression program depending on the file extension. """
  src, dest = Path(src), Path(dest.abspath)
  tar = "tar --owner root --group root -acf"
  cmds = {"xz": tar, "bz2": tar, "gz": tar,
    "7z": "7za a", "zip": "zip -q -9 -r"}
  cmd = cmds[dest.ext].split(" ") + [dest, src.name]
  call_proc(cmd, cwd=src.folder)

def load_pymodules(folder):
  """ Loads all python modules (names matching 'd_*.py') from a folder. """
  # Add the folder to the system import path.
  sys.path = [folder] + sys.path
  files = folder.glob("d_*.py")
  modules = [__import__(f.namebase, level=0) for f in files]
  # Reset the path variable.
  sys.path = sys.path[1:]
  return modules

def build_dil_if_inexistant(dil_exe):
  if is_win32: dil_exe += ".exe"
  if not dil_exe.exists and not locate_command('dil'):
    inp = raw_input("Executable %s doesn't exist. Build it? (Y/n) " % dil_exe)
    if inp.lower() in ("", "y", "yes"):
      from build import build_dil
      # TODO: Ask user about compiling with -version=D2?
      build_dil_release()
    else:
      raise Exception("can't proceed without dil executable")
