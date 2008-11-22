# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os, shutil

class Path(unicode):
  """ Models a path in an object oriented way. """
  sep = os.path.sep

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

  @property
  def ext(self):
    return os.path.splitext(self)[1]

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

  def walk(self):
    return os.walk(self)

  def mkdir(self, mode=0777):
    return os.mkdir(self, mode)

  def makedirs(self, mode=0777):
    return os.makedirs(self, mode)

  def remove(self):
    return os.remove(self)
  rm = remove

  def rmdir(self):
    return os.rmdir(self)

  def rmtree(self, noerrors=True):
    return shutil.rmtree(self, ignore_errors=noerrors)
