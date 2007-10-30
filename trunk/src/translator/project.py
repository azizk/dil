# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import os
from errors import LoadingError
import langfile
import datetime
import yaml

def newProjectData(projectName):
  return {
    "Name":projectName,
    "LangFiles":[],
    "SourceLangFile":'',
    "MsgIDs":[],
    "CreationDate":str(datetime.datetime.utcnow()),
    "BuildScript":''
  }

class Project:
  # Members:
  # name
  # source
  # langFilePaths
  # langFile
  # msgids
  # creationDate
  def __init__(self, projectPath):
    self.projectPath = projectPath
    # Load project file and check data integrity.
    doc = yaml.load(open(projectPath, "r"))
    self.doc = doc
    self.checkType(doc, dict)
    try:
      self.name = str(doc["Name"])
      self.source = str(doc["SourceLangFile"])
      self.langFilePaths = list(doc["LangFiles"])
      self.msgIDs = list(doc["MsgIDs"])
      self.creationDate = str(doc["CreationDate"])
      self.buildScript = str(doc["BuildScript"])
    except KeyError, e:
      raise LoadingError("Missing member '%s' in '%s'" % (e.message, projectPath))

    for path in self.langFilePaths:
      self.checkType(path, str)

    msgIDs = []
    for msg in self.msgIDs:
      self.checkType(msg, dict)
      try:
         msg["ID"]  = int(msg["ID"])
         msg["Name"] = unicode(msg["Name"])
         msg["Order"] = int(msg["Order"])
      except KeyError, e:
        raise LoadingError("Project: a message is missing the '%s' key." % str(e))
      msgIDs += [msg]
    self.msgIDs = msgIDs

    # Load language files.
    self.langFiles = []
    for filePath in self.langFilePaths:
      if not os.path.exists(filePath):
        # Look in project directory.
        projectDir = os.path.dirname(projectPath)
        filePath2 = os.path.join(projectDir, filePath)
        if not os.path.exists(filePath2):
          raise LoadingError("Project: Language file '%s' doesn't exist"%filePath)
        filePath = filePath2
      self.langFiles += [langfile.LangFile(filePath)]

  def checkType(self, var, type_):
    if not isinstance(var, type_):
      raise LoadingException("%s is not of type %s" % (str(var), str(type_)))

  def save(self):
    pass
