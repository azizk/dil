# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, shutil

class Path(unicode):
  """ Models a path in an object oriented way. """
  sep = os.sep
  pathsep = os.pathsep

  def __new__(cls, *paths):
    return unicode.__new__(cls, os.path.join(*paths) if len(paths) else '')

  def __div__(self, path):
    """ Concatenates strings or Paths. """
    return Path(self, path)

  def __rdiv__(self, path):
    return Path(path, self)

  def __idiv__(self, path):
    self = os.path.join(self, path)
    return Path(self)

  def __floordiv__(self, paths):
    """ Concatenates a list of paths. """
    return [self/path for path in paths]

  def __add__(self, path):
    return Path(unicode(self) + path)

  def __radd__(self, path):
    return Path(path + unicode(self))

  @property
  def name(self):
    return os.path.basename(self)

  @property
  def namebase(self):
    return os.path.splitext(self.name)[0]

  @property
  def ext(self):
    return os.path.splitext(self)[1]

  @property
  def abspath(self):
    return Path(os.path.abspath(self))

  @property
  def realpath(self):
    return Path(os.path.realpath(self))

  @property
  def normpath(self):
    return Path(os.path.normpath(self))

  @property
  def folder(self):
    return Path(os.path.dirname(self))

  @property
  def exists(self):
    return os.path.exists(self)

  @property
  def atime(self):
    return os.path.getatime(self)

  @property
  def mtime(self):
    return os.path.getmtime(self)

  @property
  def ctime(self):
    return os.path.getctime(self)

  def walk(self, **kwargs):
    if "followlinks" in kwargs:
      from sys import version_info as vi
      if vi[0]*10+vi[1] < 26: # Only Python 2.6 or newer supports followlinks.
        del kwargs["followlinks"]
    return os.walk(self, **kwargs)

  def mkdir(self, mode=0777):
    if not self.exists:
      os.mkdir(self, mode)

  def makedirs(self, mode=0777):
    """ Also creates parent directories. """
    if not self.exists:
      os.makedirs(self, mode)

  def remove(self):
    os.remove(self)
  rm = remove

  def rmdir(self):
    return os.rmdir(self)

  def rmtree(self, noerrors=True):
    return shutil.rmtree(self, ignore_errors=noerrors)

  def copy(self, to):
    shutil.copy(self, to)

  def copytree(self, to):
    shutil.copytree(self, to)

  def move(self, to):
    shutil.move(self, to)

  def rename(self, to):
    os.rename(self, to)

  def renames(self, to):
    os.renames(self, to)

  def glob(self, pattern):
    from glob import glob
    return map(Path, glob(unicode(self/pattern)))
