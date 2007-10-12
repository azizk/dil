# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import exceptions

class LangFile:
  class LoadingError(exceptions.Exception):
    def __init__(self, msg):
      self.msg = msg
      return
    def __str__(self):
      return self.msg

  def __init__(self, filePath):
    # Load language file and check data integrity.
    doc = yaml.load(open(filePath, "r"))
    self.doc = doc
    self.checkType(doc, dict)
    try:
      self.langCode = doc["LangCode"]
      self.authors = doc["Authors"]
      self.license = doc["License"]
      self.messages = doc["Messages"]
    except KeyError, e:
      raise LoadingError("Missing member '%s' in '%s'" % (e.message, filePath))

    self.checkType(self.langCode, dict)
    self.checkType(self.authors, list)
    for author in self.authors:
      self.checkType(author, list)
      if len(author) != 2:
        raise LoadingError("")
      self.checkType(author[0], str)
      self.checkType(author[1], str)
    self.checkType(self.license, str)
    self.checkType(self.messages, list)
    for msg in self.messages:
      self.checkType(msg, dict)
      if not msg.has_key("ID") or \
         not msg.has_key("Text") or \
         not msg.has_key("Annotation") or \
         not msg.has_key("LastEdited"):
        raise LoadingError("")

  def checkType(var, type_, msg=""):
    if not isinstance(var, type_):
      raise LoadingError(msg)

  def newLangFile(langCode, authors, license):
    return {
      "LangCode":langCode,
      "Authors":authors,
      "License":license,
      "Messages":[]
    }