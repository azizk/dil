# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os

class Path(unicode):
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
  def walk(self):
    return os.walk(self)
  @property
  def exists(self):
    return os.path.exists(self)
  def mkdir(self):
    return os.mkdir(self)
  def makedirs(self):
    return os.makedirs(self)