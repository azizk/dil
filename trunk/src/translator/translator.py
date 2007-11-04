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
from ui_msg_form import Ui_MsgForm

from project import Project, newProjectData

g_scriptDir = sys.path[0]
g_CWD = os.getcwd()
g_projectExt = ".tproj"
g_catExt = ".cat"
g_settingsFile = os.path.join(g_scriptDir, "settings.yaml")
g_settings = {}

class MainWindow(QtGui.QMainWindow, Ui_MainWindow):
  def __init__(self):
    QtGui.QMainWindow.__init__(self)
    self.setupUi(self)

    self.project = None
    # Modifications
    self.pages = QtGui.QStackedWidget()
    self.setCentralWidget(self.pages)
    self.disableMenuItems()
    self.projectDock = QtGui.QDockWidget("Project", self)
    self.projectTree = ProjectTree(self)
    self.projectDock.setWidget(self.projectTree)
    self.addDockWidget(QtCore.Qt.LeftDockWidgetArea, self.projectDock)
    # Custom connections
    QtCore.QObject.connect(self.action_About, QtCore.SIGNAL("triggered()"), self.showAboutDialog)
    QtCore.QObject.connect(self.action_New_Project, QtCore.SIGNAL("triggered()"), self.createNewProject)
    QtCore.QObject.connect(self.action_Open_Project, QtCore.SIGNAL("triggered()"), self.openProjectAction)
    QtCore.QObject.connect(self.action_Close_Project, QtCore.SIGNAL("triggered()"), self.closeProject)
    QtCore.QObject.connect(self.action_Properties, QtCore.SIGNAL("triggered()"), self.showProjectProperties)
    QtCore.QObject.connect(self.action_Add_Catalogue, QtCore.SIGNAL("triggered()"), self.addCatalogue)
    QtCore.QObject.connect(self.action_Add_New_Catalogue, QtCore.SIGNAL("triggered()"), self.addNewCatalogue)
    QtCore.QObject.connect(self.projectTree, QtCore.SIGNAL("currentItemChanged (QTreeWidgetItem *,QTreeWidgetItem *)"), self.projectTreeItemChanged)

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
    if self.cantCloseProjectIfOpen():
      return
    dialog = NewProjectDialog()
    code = dialog.exec_()
    if code == QtGui.QDialog.Accepted:
      self.openProject(str(dialog.projectFilePath.text()))

  def openProjectAction(self):
    if self.cantCloseProjectIfOpen():
      return
    filePath = QtGui.QFileDialog.getOpenFileName(self, "Select Project File", g_CWD, "Translator Project (*%s)" % g_projectExt);
    filePath = str(filePath)
    if filePath:
      self.openProject(filePath)

  def openProject(self, filePath):
    from errors import LoadingError
    try:
      self.project = Project(filePath)
    except LoadingError, e:
      QtGui.QMessageBox.critical(self, "Error", u"Couldn't load project file:\n\n"+str(e))
      return
    self.enableMenuItems()
    self.projectTree.setProject(self.project)

  def addCatalogue(self):
    filePath = QtGui.QFileDialog.getOpenFileName(self, "Select Project File", g_CWD, "Catalogue (*%s)" % g_catExt);
    filePath = str(filePath)

  def addNewCatalogue(self):
    pass

  def cantCloseProjectIfOpen(self):
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
    self.projectTree.clear()
    return True

  def enableMenuItems(self):
    self.action_Close_Project.setEnabled(True)
    self.menubar.insertMenu(self.menu_Help.menuAction(), self.menu_Project)

  def disableMenuItems(self):
    self.action_Close_Project.setEnabled(False)
    self.menubar.removeAction(self.menu_Project.menuAction())

  def projectTreeItemChanged(self, current, previous):
    if current == None:
      return

    if isinstance(current, LangFileItem):
      index = self.pages.indexOf(current.msgForm)
      if index == -1:
        index = self.pages.addWidget(current.msgForm)
      self.pages.setCurrentIndex(index)

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

class MsgForm(QtGui.QWidget, Ui_MsgForm):
  def __init__(self, langFile):
    QtGui.QWidget.__init__(self)
    self.setupUi(self)

    self.langFile = langFile
    self.treeWidget.setColumnCount(2)
    self.treeWidget.setHeaderLabels(["ID", "Text"])
    for msg in self.langFile.messages:
      item = QtGui.QTreeWidgetItem([str(msg["ID"]), msg["Text"]])
      self.treeWidget.addTopLevelItem(item)

    QtCore.QObject.connect(self.treeWidget, QtCore.SIGNAL("currentItemChanged (QTreeWidgetItem *,QTreeWidgetItem *)"), self.treeItemChanged)

  def treeItemChanged(self, current, previous):
    msg = self.langFile.getMsg(int(current.text(0)))
    self.destEdit.setText(msg["Text"])
    self.destAnnotEdit.setText(msg["Annot"])

class MsgIDItem(QtGui.QTreeWidgetItem):
  def __init__(self, parent, text):
    QtGui.QTreeWidgetItem.__init__(self, parent, [text])

class LangFileItem(QtGui.QTreeWidgetItem):
  def __init__(self, parent, langFile):
    QtGui.QTreeWidgetItem.__init__(self, parent, [langFile.langCode])
    self.langFile = langFile
    self.msgForm = MsgForm(langFile)

class ProjectItem(QtGui.QTreeWidgetItem):
  def __init__(self, text):
    QtGui.QTreeWidgetItem.__init__(self, [text])

class ProjectTree(QtGui.QTreeWidget):
  def __init__(self, parent):
    QtGui.QTreeWidget.__init__(self, parent)
    self.topItem = None
    self.msgIDsItem = None
    self.headerItem().setHidden(True)

  def setProject(self, project):
    self.project = project

    self.topItem = ProjectItem(self.project.name)
    self.addTopLevelItem(self.topItem)

    for langFile in self.project.langFiles:
      langFileItem = LangFileItem(self.topItem, langFile)

    self.msgIDsItem = QtGui.QTreeWidgetItem(self.topItem, ["Message IDs"])
    for msgID in self.project.msgIDs:
      MsgIDItem(self.msgIDsItem, msgID["Name"])

    for x in [self.topItem, self.msgIDsItem]:
      x.setExpanded(True)

  def clear(self):
    self.topItem = None
    self.msgIDsItem = None
    QtGui.QTreeWidget.clear(self)

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

    projectData = newProjectData(projectName)

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
