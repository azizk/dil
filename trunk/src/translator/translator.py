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
from ui_project_properties import Ui_ProjectProperties

from project import Project

g_scriptDir = sys.path[0]
g_CWD = os.getcwd()
g_projectExt = ".tproj"
g_settingsFile = os.path.join(g_scriptDir, "settings.yaml")
g_settings = {}

class MainWindow(QtGui.QMainWindow, Ui_MainWindow):
  def __init__(self):
    QtGui.QMainWindow.__init__(self)
    self.setupUi(self)

    self.project = None
    # Modifications
    self.disableMenuItems()
    # Custom connections
    QtCore.QObject.connect(self.action_About, QtCore.SIGNAL("triggered()"), self.showAboutDialog)
    QtCore.QObject.connect(self.action_New_Project, QtCore.SIGNAL("triggered()"), self.createNewProject)
    QtCore.QObject.connect(self.action_Open_Project, QtCore.SIGNAL("triggered()"), self.openProjectAction)
    QtCore.QObject.connect(self.action_Close_Project, QtCore.SIGNAL("triggered()"), self.closeProject)
    QtCore.QObject.connect(self.action_Properties, QtCore.SIGNAL("triggered()"), self.showProjectProperties)

    self.readSettings()

  def showAboutDialog(self):
    about = QtGui.QDialog()
    Ui_AboutDialog().setupUi(about)
    about.exec_()

  def showProjectProperties(self):
    dialog = QtGui.QDialog()
    Ui_ProjectProperties().setupUi(dialog)
    dialog.exec_()

  def createNewProject(self):
    NewProjectDialog().exec_()

  def openProjectAction(self):
    if self.closeProjectIfOpen():
      return
    filePath = QtGui.QFileDialog.getOpenFileName(self, "Select Project File", g_CWD, "Translator Project (*%s)" % g_projectExt);
    if filePath:
      self.openProject(str(filePath))

  def openProject(self, filePath):
    from errors import LoadingError
    try:
      self.project = Project(filePath)
    except LoadingError, e:
      QtGui.QMessageBox.critical(self, "Error", u"Couldn't load project file:\n\n"+str(e))
      return
    self.enableMenuItems()
    self.projectTree = ProjectTree(self)
    self.projectTree.setProject(self.project)
    self.vboxlayout.addWidget(self.projectTree)

  def closeProjectIfOpen(self):
    if self.project == None:
      return False
    return self.closeProject()

  def closeProject(self):
    if self.project == None:
      return True

    button = QtGui.QMessageBox.question(self, "Closing", "Close the current project?", QtGui.QMessageBox.Ok | QtGui.QMessageBox.Cancel, QtGui.QMessageBox.Cancel)
    if button == QtGui.QMessageBox.Cancel:
      return False

    del self.project
    self.project = None
    self.disableMenuItems()
    self.vboxlayout.removeWidget(self.projectTree)
    self.projectTree.close()
    return True

  def enableMenuItems(self):
    self.action_Close_Project.setEnabled(True)
    self.menubar.insertMenu(self.menu_Help.menuAction(), self.menu_Project)

  def disableMenuItems(self):
    self.action_Close_Project.setEnabled(False)
    self.menubar.removeAction(self.menu_Project.menuAction())

  def closeEvent(self, event):
    if self.closeProject() == False:
      event.ignore()
      return
    # Exitting
    self.writeSettings()

  def moveToCenterOfDesktop(self):
    rect = QtGui.QApplication.desktop().geometry()
    self.move(rect.center() - self.rect().center())

  def readSettings(self):
    # Set default size
    self.resize(QtCore.QSize(500, 400))
    doc = {}
    try:
      doc = yaml.load(open(g_settingsFile, "r"))
    except:
      self.moveToCenterOfDesktop()
      return

    g_settings = doc
    if not isinstance(doc, dict):
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

class MsgIDItem(QtGui.QTreeWidgetItem):
  def __init__(self, parent, text):
    QtGui.QTreeWidgetItem.__init__(self, parent, [text])

class LangFileItem(QtGui.QTreeWidgetItem):
  def __init__(self, parent, text):
    QtGui.QTreeWidgetItem.__init__(self, parent, [text])

class ProjectTree(QtGui.QTreeWidget):
  def __init__(self, parent):
    QtGui.QTreeWidget.__init__(self, parent)
    self.topItem = None
    self.msgIDsItem = None

  def setProject(self, project):
   self.project = project

   self.topItem = QtGui.QTreeWidgetItem([self.project.name])
   self.addTopLevelItem(self.topItem)

   self.msgIDsItem = QtGui.QTreeWidgetItem(self.topItem, ["Message IDs"])
   for msgID in self.project.msgIDs:
     MsgIDItem(self.msgIDsItem, msgID["Name"])

   for langFile in self.project.langFiles:
     langFileItem = LangFileItem(self.topItem, langFile.langCode)

   for x in [self.topItem, self.msgIDsItem]:
     x.setExpanded(True)

class NewProjectDialog(QtGui.QDialog, Ui_NewProjectDialog):
  def __init__(self):
    QtGui.QDialog.__init__(self)
    self.setupUi(self)

    QtCore.QObject.connect(self.pickFileButton, QtCore.SIGNAL("clicked()"), self.pickFilePath)

  def pickFilePath(self):
    filePath = QtGui.QFileDialog.getSaveFileName(self, "New Project File", g_CWD, "Translator Project (*%s)" % g_projectExt);
    if not filePath:
      return
    filePath = str(filePath) # Convert QString
    if os.path.splitext(filePath)[1] != g_projectExt:
      filePath += g_projectExt
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

    projectData = Project.newProjectData(projectName)

    if os.path.splitext(filePath)[1] != g_projectExt:
      filePath += g_projectExt

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
