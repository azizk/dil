# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
from __future__ import unicode_literals
import os, shutil
from re import compile as re_compile
from sys import version_info as vi
from glob import glob
from codecs import open
__all__ = ["Path"]

op = os.path

class Path(unicode):
  """ Models a path in an object oriented way. """
  sep = os.sep # File system path separator: '/' or '\'.
  pathsep = os.pathsep # Separator in the PATH environment variable.

  def __new__(cls, *paths):
    return unicode.__new__(cls, op.join(*paths) if len(paths) else '')

  def __div__(self, path):
    """ Joins this path with another path. """
    """ path_obj / 'bc.d' """
    """ path_obj / path_obj2 """
    return Path(self, path)

  def __rdiv__(self, path):
    """ Joins this path with another path. """
    """ "/home/a" / path_obj """
    return Path(path, self)

  def __idiv__(self, path):
    """ Like __div__ but also assigns to the variable. """
    """ path_obj /= 'bc.d' """
    return Path(self, path)

  def __floordiv__(self, paths):
    """ Returns a list of paths prefixed with 'self'. """
    """ '/home/a' // [bc.d, ef.g] -> [/home/a/bc.d, /home/a/ef.g] """
    return [Path(self, path) for path in paths]

  def __add__(self, path):
    """ Path('/home/a') + 'bc.d' -> '/home/abc.d' """
    return Path(unicode(self) + path)

  def __radd__(self, path):
    """ '/home/a' + Path('bc.d') -> '/home/abc.d' """
    return Path(path + unicode(self))

  def __repr__(self):
    return "Path(%s)" % unicode.__repr__(self)

  @property
  def uni(self):
    """ Returns itself as a Unicode string. """
    return unicode(self)

  @property
  def name(self):
    """ '/home/a/bc.d' -> 'bc.d' """
    return Path(op.basename(self))

  @property
  def namebase(self):
    """ '/home/a/bc.d' -> 'bc' """
    return self.name.noext

  @property
  def noext(self):
    """ '/home/a/bc.d' -> '/home/a/bc' """
    return Path(op.splitext(self)[0])

  @property
  def ext(self):
    """ '/home/a/bc.d' -> '.d' """
    return Path(op.splitext(self)[1])

  @property
  def abspath(self):
    """ './a/bc.d' -> '/home/a/bc.d'  """
    return Path(op.abspath(self))

  @property
  def realpath(self):
    """ Resolves symbolic links. """
    return Path(op.realpath(self))

  @property
  def normpath(self):
    """ '/home/x/.././a//bc.d' -> '/home/a/bc.d' """
    return Path(op.normpath(self))

  @property
  def folder(self):
    """ Returns the folder of this path. """
    """ '/home/a/bc.d' -> '/home/a' """
    """ '/home/a/' -> '/home/a' """
    """ '/home/a' -> '/home' """
    return Path(op.dirname(self))

  def up(self, n=1):
    """ Returns a new Path, """
    """ which goes n levels back in the directory hierarchy. """
    while n:
      n -= 1
      self = self.folder
    return self

  @property
  def exists(self):
    """ Returns True if the path exists. """
    return op.exists(self)

  @property
  def atime(self):
    """ Returns last accessed time. """
    return op.getatime(self)

  @property
  def mtime(self):
    """ Returns last modified time. """
    return op.getmtime(self)

  @property
  def ctime(self):
    """ Returns last changed time. """
    return op.getctime(self)

  @property
  def size(self):
    """ Returns the byte size of a file. """
    return op.getsize(self)

  @classmethod
  def supports_unicode(cls):
    """ Returns True if the system can handle Unicode file names. """
    return op.supports_unicode_filenames()

  @classmethod
  def cwd(cls):
    return Path(os.getcwd())

  def chdir(self):
    os.chdir(self)
    return self

  def walk(self, **kwargs):
    """ Returns a generator that walks through a directory tree. """
    if "followlinks" in kwargs:
      if vi[0]*10+vi[1] < 26: # Only Python 2.6 or newer supports followlinks.
        del kwargs["followlinks"]
    return os.walk(self, **kwargs)

  def mkdir(self, mode=0777):
    """ Creates a directory (and its parents), if it doesn't exist already. """
    if not self.exists:
      os.makedirs(self, mode)
    return self

  def remove(self):
    """ Removes a file. """
    os.remove(self)
    return self
  rm = remove # Alias.

  def rmdir(self):
    """ Removes a directory. """
    return os.rmdir(self)

  def rmtree(self, noerrors=True):
    """ Removes a directory tree. Ignores errors by default. """
    return shutil.rmtree(self, ignore_errors=noerrors)

  def copy(self, to):
    shutil.copy(self, to)
    return self

  def copytree(self, to):
    """ Copies a directory tree to another path. """
    shutil.copytree(self, to)
    return self

  def move(self, to):
    """ Moves a file or directory to another path. """
    shutil.move(self, to)
    return self

  def rename(self, to):
    """ Renames a file or directory. May throw an OSError. """
    os.rename(self, to)
    return self

  def renames(self, other):
    """ Renames another file or directory. """
    os.renames(self, other)
    return self

  def glob(self, pattern):
    """ Returns a list of paths matching the glob pattern. """
    return map(Path, glob(unicode(self/pattern)))

  def rxglob(self, byname=None, bypath=None, prunedir=None):
    """ Walks through a dir tree using regular expressions.
        Also accepts callback functions. """
    def check(rx):
      return rx if callable(rx) else rx.search if hasattr(rx, "search") else \
        re_compile(rx).search if rx else lambda x: False
    byname, bypath, prunedir = map(check, (byname, bypath, prunedir))
    found = []
    for root, dirs, files in self.walk(followlinks=True):
      dirs[:] = [dir for dir in dirs if not prunedir(Path(root, dir))]
      for filename in files:
        fullpath = Path(root, filename)
        if byname(filename) or bypath(fullpath):
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
