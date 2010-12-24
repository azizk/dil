# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
#from __future__ import unicode_literals
from __future__ import print_function
import os, re, sys
import subprocess
from path import Path

# Are we on a Windows system?
is_win32 = sys.platform == "win32"

def find_source_files(src_path, filter_pred=lambda x: False):
  """ Searches for source files (*.d and *.di) and returns a list of them.
    Passes dir and file names to filter_pred() to be filtered.
    Dir names have a trailing path separator ('/'). """
  found = []
  for root, dirs, files in Path(src_path).walk(followlinks=True):
    root = Path(root) # Make root a Path object.
    dirs[:] = [d for d in dirs if not filter_pred(root/d/"")] # Filter folders.
    for f in files:
      f = root / f # Join the root and the file name.
      if f.ext.lower() in ('.d','.di') and not filter_pred(f):
        found.append(f) # Found a source file.
  return found

def find_dil_source_files(source):
  """ Filters out files in "src/tests/". """
  filter_func = lambda f: f.folder.name == "tests"
  return find_source_files(source, filter_func)

def script_parent_folder(script_path):
  return Path(script_path).realpath.folder.folder

def change_cwd(script_path):
  """ Changes the current working directory to "script_dir/.." """
  os.chdir(script_parent_folder(script_path))

def kandil_path(where="kandil"):
  P = firstof(Path, where, Path(where))
  P.IMG, P.CSS, P.JS = P//("img", "css", "js")
  P.ddoc    = P/"kandil.ddoc"
  P.style   = P.CSS/"style.css"
  P.jsfiles = P.JS//("navigation.js", "jquery.js", "quicksearch.js",
    "utilities.js", "symbols.js")
  P.navi, P.jquery, P.qsearch, P.utils, P.syms = P.jsfiles
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
      sttngs = call_read([exe_path, "set"])
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
  P.JS, P.CSS, P.IMG = P//("js", "css", "img")
  return P

def get_module_fqn(prefix_path, filepath):
  """ Returns the fully qualified module name (FQN) of a D source file.
    Note: this might not match with the module declaration
          in the source file. """
  # Remove prefix and strip off path separator.
  # E.g.: prefix_path/std/format.d -> std/format.d
  filepath = filepath[len(prefix_path):].lstrip(os.path.sep)
  # Remove the extension.
  # E.g.: std/format.d - > std/format
  filepath = os.path.splitext(filepath)[0]
  # Finally replace the path separators.
  return filepath.replace(os.path.sep, '.') # E.g.: std/format -> std.format

def read_modules_list(path):
  from re import compile
  rx = compile(r"^(?P<path>[^,]+), (?P<fqn>\w+(?:\.\w+)*)$")
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
  return subprocess.call([dil_exe] + args, cwd=cwd)

def generate_pymodules(dil_exe, dest, files, options=[], cwd=None):
  """ Generates Python source files. """
  from subprocess import call
  call([dil_exe, "py", dest] + options + files, cwd=cwd)

def create_archives(opts, src, dest, cwd):
  """ Calls archiving programs to archive the src folder. """
  cwd = cwd or None # Causes exception in call() if empty string.
  for which, cmd in zip(
    ('tar_gz', 'tar_bz2', 'zip', '_7z'),
    ("tar --owner root --group root -czf %(name)s.tar.gz",
     "tar --owner root --group root --bzip2 -cf %(name)s.tar.bz2",
     "zip -q -9 -r %(name)s.zip",
     "7zr a %(name)s.7z")):
    if not getattr(opts, which, False): continue
    cmd = cmd.split(' ') # Split into array as call() requires it.
    if not locate_command(cmd[0]):
      print("Error: the utility '%s' is not in your PATH." % cmd[0])
      continue
    cmd[-1] = cmd[-1] % {'name':dest} # Format the destination parameter.
    cmd += [src] # Append the src parameter.
    print("\n", " ".join(cmd))
    subprocess.call(cmd, cwd=cwd) # Call the program.

def load_pymodules(folder):
  """ Loads all python modules (names matching 'd_*.py') from a folder. """
  # Add the folder to the system import path.
  sys.path = [folder] + sys.path
  files = folder.glob("d_*.py")
  modules = [__import__(f.namebase, level=0) for f in files]
  # Reset the path variable.
  sys.path = sys.path[1:]
  return modules

def locate_command(command):
  """ Locates a command using the PATH environment variable. """
  if 'PATH' in os.environ:
    if is_win32 and Path(command).ext.lower() != ".exe":
      command += ".exe" # Append extension if we're on Windows.
    PATH = os.environ['PATH'].split(Path.pathsep)
    for path in PATH:
      path = Path(path, command)
      if path.exists:
        return path
  return None

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

def call_read(args, **kwargs):
  """ Calls a process and returns the contents of stdout. """
  kwargs = dict({'stdout':subprocess.PIPE}, **kwargs)
  return subprocess.Popen(args, **kwargs).communicate()[0]

class VersionInfo:
  from sys import version_info as vi
  vi = vi
  f = float("%d.%d%d" % vi[:3])
  i = int(f*100)
  def __lt__(self, other): return self.f < other
  def __le__(self, other): return self.f <= other
  def __eq__(self, other): return self.f == other
  def __ne__(self, other): return self.f != other
  def __gt__(self, other): return self.f > other
  def __ge__(self, other): return self.f >= other
PyVersion = VersionInfo()

def tounicode(*objects, **kwargs):
  """ Converts the elements of an array to Unicode strings
      using the optional 'encoding' kwarg as the encoding (default=UTF-8.) """
  result = [].append
  encoding = kwargs.get('encoding', 'u8')
  for o in objects:
    result(o if isinstance(o, unicode) else
      str(o).decode(encoding))
  return result.__self__

# Add a copy of args in Unicode to sys.
sys.uargv = tounicode(*sys.argv)

def chunks(seq, n):
  """ Returns chunks of a sequence of size n. """
  return [seq[i:i+n] for i in xrange(0, len(seq), n)]

def firstof(typ, *args):
  """ Returns the first argument that is of type 'typ'. """
  for arg in args:
    if type(arg) == typ:
      return arg

def getitem(array, index, d=None):
  """ Returns array[index] if the index exists, else d. """
  return array[index] if index < len(array) else d
