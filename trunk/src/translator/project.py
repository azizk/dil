# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import langfile
import datetime
import exceptions

class Project:
  class LoadingError(exceptions.Exception):
    def __init__(self, msg):
      self.msg = msg
      return
    def __str__(self):
      return self.msg
  # Members:
  # name
  # source
  # langFilePaths
  # langFile
  # msgids
  # creationDate
  def __init__(self, projectPath):
    # Load project file and check data integrity.
    doc = yaml.load(open(projectPath, "r"))
    self.doc = doc
    self.checkType(doc, dict)
    try:
      self.name = doc["Name"]
      self.source = doc["SourceLangFile"]
      self.langFilePaths = doc["LangFiles"]
      self.msgids = doc["MsgIDs"]
      self.creationDate = doc["CreationDate"]
    except KeyError, e:
      raise LoadingError("Missing member '%s' in '%s'" % (e.message, filePath))

    self.checkType(self.name, str)
    self.checkType(self.source, str)
    self.checkType(self.langFilePaths, list)
    for path in self.langFilesPaths:
      self.checkType(path, str)
    self.checkType(self.msgIDs, list)
    for msg in self.msgIDs:
      if not isinstance(msg, dict) or \
         not msg.has_key("ID")     or \
         not msg.has_key("Name")   or \
         not msg.has_key("Order"):
        raise LoadingError("")
    self.checkType(self.creationDate, str)

    # Load language files.
    self.langFiles = []
    for filePath in self.langFilePaths:
      self.langFiles += LangFile(filePath)

  def checkType(var, type_):
    if not isinstance(var, type_):
      raise LoadingException("%s is not of type %s" % (str(var), str(type_)))

  def newProjectData(projectName):
    return {
      "Name":projectName,
      "LangFiles":[],
      "SourceLangFile":'',
      "MsgIDs":[],
      "CreationDate":str(datetime.datetime.utcnow())
    }
