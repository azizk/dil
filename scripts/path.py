# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals
import os, shutil
from re import compile as re_compile
from sys import version_info as vi
from glob import glob
from codecs import open
__all__ = ["Path", "Paths"]

op = os.path

def isiterable(x):
  """ Returns True for iterable objects, strings not included. """
  return hasattr(x, '__iter__')

class Path(unicode):
  """ Models a path in an object oriented way. """
  sep = os.sep # File system path separator: '/' or '\'.
  pathsep = os.pathsep # Separator in the PATH environment variable.

  def __new__(cls, *parts):
    if len(parts) == 1 and isiterable(parts[0]):
      parts = parts[0]
    return unicode.__new__(cls, op.join(*parts) if len(parts) else '')

  def __div__(self, path_s):
    """ Joins this path with another path.
        Path('/home/a') / 'bc.d' == '/home/a/bc.d'
        or:
        Returns a list of paths prefixed with 'self'.
        Path('/home/a') / ['bc.d', 'ef.g'] == \
          ['/home/a/bc.d', '/home/a/ef.g'] """
    if isiterable(path_s):
      return Paths(Path(self, p) for p in path_s)
    else:
      return Path(self, path_s)

  def __rdiv__(self, path_s):
    """ Joins this path with another path.
        '/home/a' / Path('bc.d') == '/home/a/bc.d'
        or:
        Returns a list of paths postfixed with 'self'.
        ['/var', '/'] / Path('tmp') == ['/var/tmp', '/tmp'] """
    if isiterable(path_s):
      return Paths(Path(p, self) for p in path_s)
    else:
      return Path(path_s, self)

  """ Like __div__ but also assigns (a new instance) to the variable.
      p = Path('/home/a')
      p /= 'bc.d'
      p == '/home/a/bc.d' """
  __idiv__ = __div__

  def __add__(self, path):
    """ Path('/home/a') + 'bc.d' == '/home/abc.d'
        or:
        Path('/home/a') + ['b', 'c'] == \
          ['/home/ab', '/home/ac'] """
    if isiterable(path):
      return Paths(self + p for p in path)
    else:
      return Path(unicode.__add__(self, path))

  def __radd__(self, path):
    """ '/home/a' + Path('bc.d') == '/home/abc.d'
        or:
        ['/home/a', '/home/b'] + Path('c') == \
          ['/home/ac', '/home/bc'] """
    if isiterable(path):
      return Paths(p + self for p in path)
    else:
      return Path(unicode.__add__(unicode(path), self))

  __iadd__ = __add__

  def __mod__(self, args):
    """ Path('/bin%d') % 32 == '/bin32' """
    return Path(unicode.__mod__(self, args))

  def format(self, *args, **kwargs):
    """ Path('/{x}/lib').format(x='usr') == '/usr/lib' """
    return Path(unicode.format(self, *args, **kwargs))

  def __repr__(self):
    return "Path(%s)" % unicode.__repr__(self)

  @property
  def uni(self):
    """ Returns itself as a Unicode string. """
    return unicode(self)

  @property
  def name(self):
    """ Path('/home/a/bc.d').name == 'bc.d'
        Path('/home/a/.').name == '.'
        Path('/home/a/').name == ''
        Path('/home/a').name == 'a' """
    return Path(op.basename(self))

  @property
  def namebase(self):
    """ Path('/home/a/bc.d').namebase == 'bc'
        Path('/home/a/bc.').namebase == 'bc'
        Path('/home/a/bc').namebase == 'bc'
        Path('/home/a/.d').namebase == '.d'
        Path('/home/a/.').namebase == '.'
        Path('/home/a/').namebase == ''
         """
    return self.name.noext

  @property
  def noext(self):
    """ Path('/home/a/bc.d').noext == '/home/a/bc' """
    return Path(op.splitext(self)[0])

  @property
  def ext(self):
    """ Path('/home/a/bc.d').ext == '.d' """
    return Path(op.splitext(self)[1])

  @property
  def abspath(self):
    """ Path('./a/bc.d').abspath == '/home/a/bc.d'  """
    return Path(op.abspath(self))

  @property
  def realpath(self):
    """ Resolves symbolic links. """
    return Path(op.realpath(self))

  @property
  def normpath(self):
    """ Path('/home/x/.././a//bc.d').normpath == '/home/a/bc.d' """
    return Path(op.normpath(self))

  @property
  def folder(self):
    """ Returns the folder of this path.
        Path('/home/a/bc.d').folder == '/home/a'
        Path('/home/a/').folder == '/home/a'
        Path('/home/a').folder == '/home'
        Path('/').folder == '/' """
    return Path(op.dirname(self))

  def up(self, n=1):
    """ Returns a new Path going n levels back in the directory hierarchy. """
    while n:
      n -= 1
      self = self.folder
    return self

  @property
  def exists(self):
    """ Returns True if the path exists, but False for broken symlinks."""
    return op.exists(self)

  @property
  def lexists(self):
    """ Returns True if the path exists. Also True for broken symlinks. """
    return op.lexists(self)

  @property
  def atime(self):
    """ Returns last accessed timestamp. """
    return op.getatime(self)

  @property
  def mtime(self):
    """ Returns last modified timestamp. """
    return op.getmtime(self)

  @property
  def ctime(self):
    """ Returns last changed timestamp. """
    return op.getctime(self)

  @property
  def size(self):
    """ Returns the byte size of a file. """
    return op.getsize(self)

  @property
  def isabs(self):
    """ Returns True if the path is absolute. """
    return op.isabs(self)

  @property
  def isfile(self):
    """ Returns True if the path is a file. """
    return op.isfile(self)

  @property
  def isdir(self):
    """ Returns True if the path is a directory. """
    return op.isdir(self)

  @property
  def islink(self):
    """ Returns True if the path is a symlink. """
    return op.islink(self)

  @property
  def ismount(self):
    """ Returns True if the path is a mount point. """
    return op.ismount(self)

  @classmethod
  def supports_unicode(cls):
    """ Returns True if the system can handle Unicode file names. """
    return op.supports_unicode_filenames()

  @classmethod
  def cwd(cls):
    """ Return the current working directory. """
    return Path(os.getcwd())

  def chdir(self):
    """ Changes the current working directory to 'self'. """
    os.chdir(self)
    return self

  def mkdir(self, mode=0777):
    """ Creates a directory (and its parents), if it doesn't already exist. """
    if not self.exists:
      os.makedirs(self, mode)
    return self
  mk = mkdir

  def remove(self):
    """ Removes a file, symlink or directory tree. """
    if self.lexists:
      if self.isfile:
        os.remove(self)
      else:
        shutil.rmtree(self, ignore_errors=True)
    return self
  rm = remove

  def copy(self, to):
    """ Copies a file or a directory tree to another path. """
    if self.isfile:
      shutil.copy(self, to)
    else:
      shutil.copytree(self, to)
    return self
  cp = copy

  def move(self, to):
    """ Moves a file or directory to another path.
        Deletes the destination first, if existent. """
    to = Path(to)
    if to.lexists:
      if to.islink:
        if not to.exists:
          to.remove() # Broken symlink.
        else:
          return self.move(to.realpath)
      elif to.isfile:
        to.remove()
      else: # Delete file or dir with the same name in the destination folder.
        to = (to/self.normpath.name).remove()
    shutil.move(self, to)
    return self
  mv = move

  def rename(self, to):
    """ Renames a file or directory. May throw an OSError. """
    os.rename(self, to)
    return self

  def renames(self, to):
    """ Recursively renames a file or directory. """
    os.renames(self, to)
    return self

  def walk(self, **kwargs):
    """ Returns a generator that walks through a directory tree. """
    if vi[:2] < (2,6): # Only Python 2.6 or newer supports followlinks.
      kwargs.pop("followlinks", None)
    return os.walk(self, **kwargs)

  def glob(self, pattern):
    """ Matches the file name pattern, taking 'self' as the folder.
        Returns a Paths object containing the matches. """
    return Paths(glob(unicode(self/pattern)))

  def rxglob(self, byname=None, bypath=None, prunedir=None):
    """ Walks through a dir tree using regular expressions.
        Also accepts callback functions.
        Returns a Paths object containing the matches. """
    def check(rx):
      return rx if callable(rx) else rx.search if hasattr(rx, "search") else \
        re_compile(rx).search if rx else lambda x: False
    byname, bypath, prunedir = map(check, (byname, bypath, prunedir))
    found = Paths()
    for root, dirs, files in self.walk(followlinks=True):
      dirs[:] = [dir for dir in dirs if not prunedir(Path(root, dir))]
      for filename in files:
        fullpath = Path(root, filename)
        if byname(Path(filename)) or bypath(fullpath):
          found.append(fullpath)
    return found

  def open(self, mode='rb', encoding='utf-8'):
    """ Opens a file with an encoding (default=UTF-8.) """
    return open(self, mode=mode, encoding=encoding)

  def write(self, content, mode='w', encoding='utf-8'):
    """ Writes content to a file. """
    f = self.open(mode, encoding)
    f.write(content)
    f.close()
    return self

  def read(self, mode='rb', encoding='utf-8'):
    """ Reads the contents of a file. """
    f = self.open(mode, encoding)
    content = f.read()
    f.close()
    return content




class Paths(list):
  """ A list of Path objects with convenience functions. """
  def __init__(self, *paths):
    if len(paths) == 1 and isiterable(paths[0]):
      paths = paths[0]
    list.__init__(self, (p if isinstance(p, Path) else Path(p) for p in paths))

  def __div__(self, path_s):
    """ Paths('/a', 'b') / 'c.d' == Paths('/a/c.d', '/b/c.d')
        or:
        Paths('a/b', 'c/d') / ['w.x', 'y.z'] == \
        Paths('a/b/w.x', 'a/b/y.z', 'c/d/w.x', 'c/d/y.z') """
    if isiterable(path_s):
      return Paths(Path(p1, p2) for p1 in self for p2 in path_s)
    else:
      return Paths(Path(p, path_s) for p in self)

  def __rdiv__(self, path_s):
    """ '/home' / Paths('a', 'b') == Paths('/home/a', '/home/b')
        or:
        ['w.x', 'y.z'] / Paths('a/b', 'c/d') == \
        Paths('w.x/a/b', 'w.x/c/d', 'y.z/a/b', 'y.z/c/d')"""
    if isiterable(path_s):
      return Paths(Path(p1, p2) for p1 in path_s for p2 in self)
    else:
      return Paths(Path(path_s, p) for p in self)

  def __idiv__(self, path_s):
    self[:] = self.__div__(path_s)
    return self

  def __add__(self, path_s):
    if isiterable(path_s):
      return Paths(list.__add__(self, path_s))
    else:
      return Paths(p + unicode(path_s) for p in self)

  def __radd__(self, path_s):
    if isiterable(path_s):
      return Paths(list.__add__(self, path_s))
    else:
      return Paths(unicode(path_s) + p for p in self)

  def __iadd__(self, path_s):
    self[:] = self.__add__(path_s)
    return self

  def __mod__(self, args):
    return Paths(p.__mod__(args) for p in self)

  def format(self, *args, **kwargs):
    return Paths(p.format(*args, **kwargs) for p in self)

  def __repr__(self):
    return "Paths(%s)" % list.__repr__(self)[1:-1]

  def common(self):
    return Path(op.commonprefix(self))

  @property
  def names(self):
    return Paths(p.name for p in self)

  @property
  def bases(self):
    return Paths(p.namebase for p in self)

  @property
  def noexts(self):
    return Paths(p.noext for p in self)

  @property
  def exts(self):
    return Paths(p.ext for p in self)

  @property
  def abspaths(self):
    return Paths(p.abspath for p in self)

  @property
  def realpaths(self):
    return Paths(p.realpath for p in self)

  @property
  def normpaths(self):
    return Paths(p.normpath for p in self)

  @property
  def folders(self):
    return Paths(p.folder for p in self)

  def up(self, n=1):
    for p in self:
      p.up(n)
    return self

  @property
  def exist(self):
    return [p.exists for p in self]
  @property
  def lexist(self):
    return [p.lexists for p in self]
  @property
  def atimes(self):
    return [p.atime for p in self]
  @property
  def mtimes(self):
    return [p.mtime for p in self]
  @property
  def ctimes(self):
    return [p.ctime for p in self]
  @property
  def sizes(self):
    return [p.size for p in self]
  @property
  def isabs(self):
    return [p.isabs for p in self]
  @property
  def isfile(self):
    return [p.isfile for p in self]
  @property
  def isdir(self):
    return [p.isdir for p in self]
  @property
  def islink(self):
    return [p.islink for p in self]
  @property
  def ismount(self):
    return [p.ismount for p in self]

  def mkdir(self, mode=0777):
    for p in self: p.mkdir(mode)
    return self
  mk = mkdirs = mkdir

  def remove(self):
    for p in self: p.rm()
    return self
  rm = remove

  def copy(self, to):
    if isiterable(to):
      map(Path.cp, self, to)
    else:
      for p in self:
        p.cp(to)
    return self
  cp = copy

  def move(self, to):
    if isiterable(to):
      map(Path.mv, self, to)
    else:
      for p in self:
        p.mv(to)
    return self
  mv = move

  def rename(self, to):
    map(Path.rename, self, to)
    return self

  def renames(self, to):
    map(Path.renames, self, to)
    return self

  def walk(self, **kwargs):
    from itertools import chain
    return chain(*(p.walk(**kwargs) for p in self))

  def glob(self, pattern):
    return Paths(q for p in self for q in glob(unicode(p/pattern)))

  def rxglob(self, *args, **kwargs):
    return Paths(q for p in self for q in p.rxglob(*args, **kwargs))

  def open(self, **kwargs):
    return [p.open(**kwargs) for p in self]

  def write(self, content, **kwargs):
    for p in self:
      p.write(content, **kwargs)
    return self

  def read(self, **kwargs):
    return [p.read(**kwargs) for p in self]
