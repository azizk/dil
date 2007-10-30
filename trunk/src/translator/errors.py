# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import exceptions

class LoadingError(exceptions.Exception):
  def __init__(self, msg):
    self.msg = msg
    return
  def __str__(self):
    return self.msg
