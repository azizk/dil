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

  def __new__(cls, *parts):
    return unicode.__new__(cls, op.join(*parts) if len(parts) else '')

  def __div__(self, path):
    """ Joins this path with another path.
        Path('/home/a') / 'bc.d' == '/home/a/bc.d' """
    return Path(self, path)

  def __rdiv__(self, path):
    """ Joins this path with another path.
        '/home/a' / Path('bc.d') == '/home/a/bc.d' """
    return Path(path, self)

  """ Like __div__ but also assigns to the variable.
      p = Path('/home/a')
      p /= 'bc.d'
      p == '/home/a/bc.d' """
  __idiv__ = __div__

  def __floordiv__(self, paths):
    """ Returns a list of paths prefixed with 'self'.
        Path('/home/a') // ['bc.d', 'ef.g'] == ['/home/a/bc.d', '/home/a/ef.g'] """
    return [Path(self, p) for p in paths]

  def __rfloordiv__(self, paths):
    """ Returns a list of paths postfixed with 'self'.
        ['/var', '/'] // Path('tmp') == ['/var/tmp', '/tmp'] """
    return [Path(p, self) for p in paths]

  __ifloordiv__ = __floordiv__

  def __add__(self, path):
    """ Path('/home/a') + 'bc.d' == '/home/abc.d' """
    return Path(unicode(self) + path)

  def __radd__(self, path):
    """ '/home/a' + Path('bc.d') == '/home/abc.d' """
    return Path(path + unicode(self))

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
    """ Path('/home/a/bc.d').name == 'bc.d' """
    return Path(op.basename(self))

  @property
  def namebase(self):
    """ Path('/home/a/bc.d').namebase == 'bc' """
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
        Path('/home/a').folder == '/home' """
    return Path(op.dirname(self))

  def up(self, n=1):
    """ Returns a new Path,
        which goes n levels back in the directory hierarchy. """
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

  def walk(self, **kwargs):
    """ Returns a generator that walks through a directory tree. """
    if vi[:2] < (2,6): # Only Python 2.6 or newer supports followlinks.
      kwargs.pop("followlinks", None)
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
    """ Removes a directory (only if it's empty.) """
    os.rmdir(self)
    return self

  def rmtree(self, noerrors=True):
    """ Removes a directory tree. Ignores errors by default. """
    shutil.rmtree(self, ignore_errors=noerrors)
    return self

  def copy(self, to):
    """ Copies a file to another path. """
    shutil.copy(self, to)
    return self

  def copytree(self, to):
    """ Copies a directory tree to another path. """
    shutil.copytree(self, to)
    return self

  def move(self, to):
    """ Moves a file or directory to another path.
        Deletes the destination first, if existent. """
    to = Path(to)
    if to.exists:
      if to.isfile: to.remove()
      else: # Check if the source dir/file is in the destination dir.
        to = to/self.name
        if to.exists:
          if to.isfile: to.remove()
          else: to.rmtree()
    shutil.move(self, to)
    return self
  mv = move

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
