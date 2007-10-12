#! /usr/bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import sys, os
import yaml
from PyQt4 import QtCore, QtGui
# User interface modules
from ui_translator import Ui_MainWindow
from ui_about import Ui_AboutDialog
from ui_new_project import Ui_NewProjectDialog

g_scriptDir = sys.path[0]
g_CWD = os.getcwd()
g_settingsFile = os.path.join(g_scriptDir, "settings.yaml")
g_settings = {}

class MainWindow(QtGui.QMainWindow, Ui_MainWindow):
  def __init__(self):
    QtGui.QMainWindow.__init__(self)
    self.setupUi(self)

    # Modifications

    # Custom connections
    QtCore.QObject.connect(self.action_About, QtCore.SIGNAL("triggered()"), self.showAboutDialog)
    QtCore.QObject.connect(self.action_New_Project, QtCore.SIGNAL("triggered()"), self.createNewProject)

    self.readSettings()

  def showAboutDialog(self):
    about = QtGui.QDialog()
    Ui_AboutDialog().setupUi(about)
    about.exec_()

  def createNewProject(self):
    NewProjectDialog().exec_()

  def closeEvent(self, event):
    self.writeSettings()

  def moveToCenterOfDesktop(self):
    rect = QtGui.QApplication.desktop().geometry()
    self.move(rect.center() - self.rect().center())

  def readSettings(self):
    # Set default size
    self.resize(QtCore.QSize(500, 400))

    try:
      doc = yaml.load(open(g_settingsFile, "r"))
    except:
      self.moveToCenterOfDesktop()
      return

    if isinstance(doc, type({})):
      g_settings = doc
    else:
      g_settings = {}

    try:
      coord = doc["Window"]
      size = QtCore.QSize(coord["Size"][0], coord["Size"][1])
      point = QtCore.QPoint(coord["Pos"][0], coord["Pos"][1])
      self.resize(size)
      self.move(point)
    except:
      self.moveToCenterOfDesktop()

  def writeSettings(self):
    # Save window coordinates
    g_settings["Window"] = {
      "Pos" : [self.pos().x(), self.pos().y()],
      "Size" : [self.size().width(), self.size().height()]
    }
    yaml.dump(g_settings, open(g_settingsFile, "w")) #default_flow_style=False


class NewProjectDialog(QtGui.QDialog, Ui_NewProjectDialog):
  def __init__(self):
    QtGui.QDialog.__init__(self)
    self.setupUi(self)

    QtCore.QObject.connect(self.pickFileButton, QtCore.SIGNAL("clicked()"), self.pickFilePath)

  def pickFilePath(self):
    filePath = QtGui.QFileDialog.getSaveFileName(self, "Select Project File", g_CWD, "Translator Project (*.tproj)");
    filePath = str(filePath) # Convert QString
    if os.path.splitext(filePath)[1] != ".tproj":
      filePath += ".tproj"
    self.projectFilePath.setText(filePath)

  def accept(self):
    projectName = str(self.projectName.text())
    filePath = str(self.projectFilePath.text())

    if projectName == "":
      QtGui.QMessageBox.warning(self, "Warning", "Please, enter a name for the project.")
      return
    if filePath == "":
      QtGui.QMessageBox.warning(self, "Warning", "Please, choose or enter a path for the project file.")
      return

    projectData = {
      "Name":projectName,
      "LangFiles":[],
      "SourceLangFile":'',
      "MsgIDs":[]
    }

    if os.path.splitext(filePath)[1] != ".tproj":
      filePath += ".tproj"

    try:
      yaml.dump(projectData, open(filePath, "w"), default_flow_style=False)
    except Exception, e:
      QtGui.QMessageBox.critical(self, "Error", str(e))
      return

    # Accept and close dialog.
    QtGui.QDialog.accept(self)

if __name__ == "__main__":
  app = QtGui.QApplication(sys.argv)
  main = MainWindow()
  main.show()
  sys.exit(app.exec_())
