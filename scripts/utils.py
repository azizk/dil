# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: zlib/libpng
# Some classes and functions not readily available in standard Python.
from __future__ import unicode_literals, print_function
import sys, subprocess
from path import Path

class dicta(dict):
  """ Sets and gets values using attributes. """
  __getattr__ = dict.__getitem__
  __setattr__ = dict.__setitem__
  __delattr__ = dict.__delitem__

class dictad(dicta):
  """ Returns None for inexistent keys. """
  __getattr__ = dict.get

class listd(list): # d = default
  """ Returns None for inexistent indices. """
  def get(self, i, d=None):
    """ Returns list[i] if the index exists, else d. """
    return list.__getitem__(self, i) if (-i-1 if i<0 else i) < len(self) else d
  __getitem__ = get


def call_proc(*args, **kwargs):
  """ Calls a process and returns its return-code. """
  if len(args) == 1 and isinstance(args[0], list): # E.g.: call_proc([...])
    args = args[0] # Replace if the sole argument is a list.
  return subprocess.call(args, **kwargs)

def call_read(*args, **kwargs):
  """ Calls a process and returns the contents of stdout in Unicode. """
  if len(args) == 1 and isinstance(args[0], list): # E.g.: call_read([...])
    args = args[0] # Replace if the sole argument is a list.
  kwargs.update(stdout=subprocess.PIPE)
  return subprocess.Popen(args, **kwargs).communicate()[0].decode('u8')


def tounicode(o, encoding='u8'):
  return (o if isinstance(o, unicode)
          else str(o).decode(encoding))

def tounicodes(objects, encoding='u8'):
  """ Converts the elements of an array to Unicode strings
      using the optional 'encoding' kwarg as the encoding (default=UTF-8.) """
  return map(tounicode, objects)

# Add a copy of args in Unicode to sys.
sys.uargv = tounicodes(sys.argv)


def chunks(seq, n):
  """ Returns chunks of a sequence of size n. """
  return [seq[i:i+n] for i in xrange(0, len(seq), n)]

def firstof(typ, *args):
  """ Returns the first argument that is of type 'typ'. """
  for arg in args:
    if type(arg) == typ:
      return arg


def cpu_bitness():
  """ Determines the address space size, based on the interpreter's bitness. """
  return len(bin(sys.maxint)[2:]) + 1
# What bit size is the CPU?
cpu_bits = cpu_bitness()

# Are we on a Windows system?
is_win32 = sys.platform == "win32"


class StopWatch:
  """ Simple stopwatch. """
  import time
  timer = time.clock if is_win32 else time.time
  def __init__(self):
    self.time = self.timer()
  def start(self):
    self.time = self.timer()
  @property
  def elapsed(self):
    return self.timer() - self.time
  def stop(self):
    self.time = self.elapsed
    return self.time

def locate_command(command):
  """ Locates a command using the PATH environment variable. """
  import os
  if 'PATH' in os.environ:
    if is_win32 and Path(command).ext.lower() != ".exe":
      command += ".exe" # Append extension if we're on Windows.
    PATH = os.environ['PATH'].split(Path.pathsep)
    for path in PATH:
      path = Path(path, command)
      if path.exists:
        return path
  return None

