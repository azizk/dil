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
    self.isSource = False
    self.source = None
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

    self.msgDict = {} # {ID : msg, ...}
    for msg in self.messages:
      self.checkType(msg, dict, "LangFile: messages must be of type dict.")
      try:
        msg["ID"] = int(msg["ID"])
        msg["Text"] = unicode(msg["Text"])
        msg["Annot"] = unicode(msg["Annot"])
        msg["LastEd"] = unicode(msg["LastEd"])
      except KeyError, e:
        raise LoadingError("LangFile: a message is missing the '%s' key." % str(e))
      self.msgDict[msg["ID"]] = msg

  def checkType(self, var, type_, msg=""):
    if not isinstance(var, type_):
      raise LoadingError(msg)

  def setSource(self, sourceLangFile):
    self.source = sourceLangFile

  def getMsg(self, ID):
    for msg in self.messages:
      if msg["ID"] == ID:
        return msg
    return None

  def createMissingMessages(self, IDs):
    for ID in IDs:
      if not self.msgDict.has_key(ID):
        msg = self.createEmptyMsg(ID)
        self.msgDict[ID] = msg
        self.messages += [msg]

  def createEmptyMsg(self, ID):
    return {"ID":ID,"Text":"","Annot":"","LastEd":""}

  def save(self):
    pass
