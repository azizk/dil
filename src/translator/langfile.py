# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import yaml
from errors import LoadingError

# Avoid that all unicode strings are tagged with "!!python/unicode".
def unicode_representer(dumper, data):
  return dumper.represent_scalar(u'tag:yaml.org,2002:str', data)
yaml.add_representer(unicode, unicode_representer)

def newLangFile(langCode, authors, license):
  return {
    "LangCode":langCode,
    "Authors":authors,
    "License":license,
    "Messages":[]
  }

class LangFile:
  def __init__(self, filePath):
    from os import path
    self.filePath = path.abspath(filePath)
    self.isSource = False
    self.source = None
    # Load language file and check data integrity.
    try:
      self.doc = yaml.load(open(filePath, "r"))
    except yaml.YAMLError, e:
      raise LoadingError(str(e))
    self.verify()

  def verify(self):
    doc = self.doc
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
      self.checkType(author, dict, "LangFile: author must be of type dict.")
      try:
        author["Name"] = unicode(author["Name"])
        author["EMail"] = str(author["EMail"])
        authors += [author]
      except KeyError, e:
        raise LoadingError("Author is missing '%s' in '%s'" % (e.message, filePath))
    self.authors = authors

    self.msgDict = {} # {ID : msg, ...}
    for msg in self.messages:
      self.checkType(msg, dict, "LangFile: messages must be of type dict.")
      try:
        msg["ID"] = int(msg["ID"])
        msg["Text"] = unicode(msg["Text"])
        msg["Annot"] = unicode(msg["Annot"])
        msg["LastEd"] = int(msg["LastEd"])
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
    self.doc["LangCode"] = self.langCode
    self.doc["License"] = self.license
    self.doc["Authors"] = self.authors
    langFile = open(self.filePath, "w")
    yaml.dump(self.doc, stream=langFile, allow_unicode=True)
    langFile.close()

  def setLangCode(self, langCode):
    self.langCode = langCode

  def setLicense(self, license):
    self.license = license

  def setAuthors(self, authors):
    self.authors = authors

  def getFileName(self):
    from os import path
    return path.basename(self.filePath)

  def getFilePath(self):
    return self.filePath
