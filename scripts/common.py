# -*- coding: utf-8 -*-
# Author: Aziz Köksal
import os

def getModuleFQN(prefix_path, filepath):
  """ Returns the fully qualified module name of a D source file. """
  # Remove prefix and strip off path separator.
  # E.g.: prefix_path/std/format.d -> std/format.d
  filepath = filepath[len(prefix_path):].lstrip(os.path.sep)
  # Remove the extension.
  # E.g.: std/format.d - > std/format
  filepath = os.path.splitext(filepath)[0]
  # Finally replace the path separators.
  return filepath.replace(os.path.sep, '.') # E.g.: std/format -> std.format

def download_jquery(path):
  pass
