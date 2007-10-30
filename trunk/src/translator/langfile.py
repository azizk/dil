# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import yaml
from errors import LoadingError

def newLangFile(langCode, authors, license):
  return {
    "LangCode":langCode,
    "Authors":authors,
    "License":license,
    "Messages":[]
  }

class LangFile:
  def __init__(self, filePath):
    self.filePath = filePath
    # Load language file and check data integrity.
    doc = yaml.load(open(filePath, "r"))
    self.doc = doc
    self.checkType(doc, dict)
    try:
      self.langCode = str(doc["LangCode"])
      self.authors = list(doc["Authors"])
      self.license = unicode(doc["License"])
      self.messages = list(doc["Messages"])
    except KeyError, e:
      raise LoadingError("Missing member '%s' in '%s'" % (e.message, filePath))

    authors = []
    for author in self.authors:
      author = list(author)
      author_len = len(author)
      if author_len == 0:
        pass
      elif author_len == 1:
        authors += [unicode(author[0]), ""]
      else:
        authors += [unicode(author[0]), unicode(author[1])]
    self.authors = authors

    messages = []
    for msg in self.messages:
      self.checkType(msg, dict, "LangFile: messages must be of type dict.")
      try:
        msg["ID"] = int(msg["ID"])
        msg["Text"] = unicode(msg["Text"])
        msg["Annot"] = unicode(msg["Annot"])
        msg["LastEd"] = unicode(msg["LastEd"])
      except KeyError, e:
        raise LoadingError("LangFile: a message is missing the '%s' key." % str(e))
      messages += [msg]
    self.messages = messages

  def checkType(self, var, type_, msg=""):
    if not isinstance(var, type_):
      raise LoadingError(msg)

  def save(self):
    pass
