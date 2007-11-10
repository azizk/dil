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

Qt = QtCore.Qt
Qt.connect = QtCore.QObject.connect
Qt.disconnect = QtCore.QObject.disconnect
Qt.SIGNAL = QtCore.SIGNAL
Qt.SLOT = QtCore.SLOT

def QTabWidgetCloseAll(self):
 for i in range(0, self.count()):
   widget = self.widget(0)
   self.removeTab(0)
   widget.close()
QtGui.QTabWidget.closeAll = QTabWidgetCloseAll

class MainWindow(QtGui.QMainWindow, Ui_MainWindow):
  def __init__(self):
    QtGui.QMainWindow.__init__(self)
    self.setupUi(self)

    self.project = None
    # Modifications
    self.pages = QtGui.QTabWidget()
    self.setCentralWidget(self.pages)
    self.disableMenuItems()
    self.projectDock = QtGui.QDockWidget("Project", self)
    self.projectTree = ProjectTree(self.projectDock)
    self.projectDock.setWidget(self.projectTree)
    self.addDockWidget(QtCore.Qt.LeftDockWidgetArea, self.projectDock)
    # Custom connections
    Qt.connect(self.action_About, Qt.SIGNAL("triggered()"), self.showAboutDialog)
    Qt.connect(self.action_New_Project, Qt.SIGNAL("triggered()"), self.createNewProject)
    Qt.connect(self.action_Open_Project, Qt.SIGNAL("triggered()"), self.openProjectAction)
    Qt.connect(self.action_Close_Project, Qt.SIGNAL("triggered()"), self.closeProject)
    Qt.connect(self.action_Save, Qt.SIGNAL("triggered()"), self.saveForm)
    Qt.connect(self.action_Save_All, Qt.SIGNAL("triggered()"), self.saveAllForms)
    Qt.connect(self.action_Close, Qt.SIGNAL("triggered()"), self.closeForm)
    Qt.connect(self.action_Close_All, Qt.SIGNAL("triggered()"), self.closeAllForms)
    Qt.connect(self.action_Properties, Qt.SIGNAL("triggered()"), self.showProjectProperties)
    Qt.connect(self.action_Add_Catalogue, Qt.SIGNAL("triggered()"), self.addCatalogue)
    Qt.connect(self.action_Add_New_Catalogue, QtCore.SIGNAL("triggered()"), self.addNewCatalogue)
    Qt.connect(self.projectTree, Qt.SIGNAL("itemDoubleClicked(QTreeWidgetItem*,int)"), self.projectTreeItemDblClicked)
    Qt.connect(self.projectTree, Qt.SIGNAL("onKeyEnter"), self.projectTreeItemActivated)
    Qt.connect(self.projectTree, Qt.SIGNAL("onKeyDelete"), self.projectTreeItemDeleted)

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
    MB = QtGui.QMessageBox
    button = MB.question(self, "Closing", "Close the current project?", MB.Ok | MB.Cancel, MB.Cancel)
    if button == MB.Cancel:
      return False

    del self.project
    self.project = None
    self.disableMenuItems()
    self.projectTree.clear()
    self.pages.closeAll()
    return True

  def enableMenuItems(self):
    #self.action_Close_Project.setEnabled(True)
    for action in [ self.action_Save,
                    self.action_Save_All,
                    self.action_Close,
                    self.action_Close_All ]:
      action.setEnabled(True)
    self.menubar.insertMenu(self.menu_Help.menuAction(), self.menu_Project)

  def disableMenuItems(self):
    #self.action_Close_Project.setEnabled(False)
    for action in [ self.action_Save,
                    self.action_Save_All,
                    self.action_Close,
                    self.action_Close_All ]:
      action.setEnabled(False)
    self.menubar.removeAction(self.menu_Project.menuAction())

  def projectTreeItemDblClicked(self, item, int):
    self.projectTreeItemActivated(item)

  def projectTreeItemActivated(self, item):
    if item == None:
      return

    if isinstance(item, LangFileItem):
      msgForm = None
      if not item.isDocOpen():
        msgForm = item.openDoc()
        msgForm.setModifiedCallback(self.formModified)
      index = self.pages.indexOf(msgForm)
      if index == -1:
        index = self.pages.addTab(msgForm, msgForm.getDocumentTitle())
      self.pages.setCurrentIndex(index)
      msgForm.updateData()

  def projectTreeItemDeleted(self, item):
    pass

  def formModified(self, form):
    # Append an asterisk to the tab label
    index = self.pages.indexOf(form)
    text = form.getDocumentTitle() + "*"
    self.pages.setTabText(index, text)

  def saveForm(self):
    self.saveDocument(self.pages.currentWidget())

  def saveAllForms(self):
    for i in range(0, self.pages.count()):
      self.saveDocument(self.pages.widget(i))

  def saveDocument(self, form):
    if form.isModified:
      index = self.pages.indexOf(form)
      text = form.getDocumentTitle()
      self.pages.setTabText(index, text)
      form.save()

  def closeForm(self):
    if self.pages.currentWidget():
      self.closeDocument(self.pages.currentWidget())

  def closeAllForms(self):
    for i in range(0, self.pages.count()):
      self.closeDocument(self.pages.widget(i))

  def closeDocument(self, form):
    if form.isModified:
      MB = QtGui.QMessageBox
      button = MB.question(self, "Closing Document", "The document '%s' has been modified.\nDo you want to save the changes?" % form.getDocumentFullPath(), MB.Save | MB.Discard | MB.Cancel, MB.Cancel)
      if button == MB.Cancel:
        return False
      if button == MB.Save:
        self.saveDocument(form)
    index = self.pages.indexOf(form)
    self.pages.removeTab(index)
    form.close()
    return True

  def closeEvent(self, event):
    if self.closeProject() == False:
      event.ignore()
      return
    self.writeSettings()
    # Closing application

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


class MessageItem(QtGui.QTreeWidgetItem):
  def __init__(self, msg):
    QtGui.QTreeWidgetItem.__init__(self, [str(msg["ID"]), msg["Text"]])
    self.msg = msg

  def getID(self):
    return self.msg["ID"]

  def setMsgText(self, text):
    self.msg["Text"] = text

  def setMsgAnnot(self, text):
    self.msg["Annot"] = text


class Document(QtGui.QWidget):
  def __init__(self):
    QtGui.QWidget.__init__(self)
    self.isModified = False
    self.modifiedCallback = None
    self.documentTitle = ""
    self.documentFullPath = ""

  def modified(self):
    if not self.isModified:
      self.isModified = True
      self.modifiedCallback(self)

  def setModifiedCallback(self, func):
    self.modifiedCallback = func

  def save(self):
    self.isModified = False

  def close(self):
    self.emit(Qt.SIGNAL("closed()"))
    QtGui.QWidget.close(self)

  def getDocumentTitle(self):
    return self.documentTitle

  def getDocumentFullPath(self):
    return self.documentFullPath

class MsgForm(Document, Ui_MsgForm):
  def __init__(self, langFile):
    Document.__init__(self)
    self.documentTitle = langFile.getFileName()
    self.documentFullPath = langFile.getFilePath()
    self.setupUi(self)
    self.vboxlayout.setMargin(0)

    self.langFile = langFile
    self.currentItem = None
    self.colID = 0
    self.colText = 1
    self.treeWidget.setColumnCount(2)
    self.treeWidget.setHeaderLabels(["ID", "Text"])
    for msg in self.langFile.messages:
      self.treeWidget.addTopLevelItem(MessageItem(msg))

    Qt.connect(self.treeWidget, Qt.SIGNAL("currentItemChanged (QTreeWidgetItem *,QTreeWidgetItem *)"), self.treeItemChanged)
    Qt.connect(self.translEdit, Qt.SIGNAL("textChanged()"), self.translEditTextChanged)
    Qt.connect(self.translAnnotEdit, Qt.SIGNAL("textChanged()"), self.translAnnotEditTextChanged)

    #self.translEdit.focusOutEvent = self.translEditFocusOut

  def treeItemChanged(self, current, previous):
    if current == None:
      self.setTranslMsg("")
      self.setSourceMsg("")
      return
    ID = current.getID()
    # Set the text controls.
    # The slots receiving text changed signals do nothing if self.currentItem is None.
    self.currentItem = None
    self.setTranslMsg(self.langFile.getMsg(ID))
    self.setSourceMsg(self.langFile.source.getMsg(ID))
    self.currentItem = current

  def setTranslMsg(self, msg):
    self.translEdit.setText(msg["Text"])
    self.translAnnotEdit.setText(msg["Annot"])

  def setSourceMsg(self, msg):
    self.sourceEdit.setText(msg["Text"])
    self.sourceAnnotEdit.setText(msg["Annot"])

  #def translEditFocusOut(self, event):
    #if self.currentItem:
      #print self.currentItem.text(self.colText)
      #if self.translEdit.document().isModified():
        #self.translEdit.document().setModified(False)
        #print "translEdit was modified"
    #QtGui.QTextEdit.focusOutEvent(self.translEdit, event)

  def translEditTextChanged(self):
    if self.currentItem:
      text = unicode(self.translEdit.toPlainText())
      self.currentItem.setText(self.colText, text)
      self.currentItem.setMsgText(text)
      self.modified()

  def translAnnotEditTextChanged(self):
    if self.currentItem:
      text = unicode(self.translAnnotEdit.toPlainText())
      self.currentItem.setMsgAnnot(text)
      self.modified()

  def updateData(self):
    if self.currentItem == None:
      return
    ID = self.currentItem.getID()
    msg = self.langFile.source.getMsg(ID)
    text = self.sourceEdit.toPlainText()
    if text != msg["Text"]:
      self.sourceEdit.setText(msg["Text"])
    text = self.sourceAnnotEdit.toPlainText()
    if text != msg["Annot"]:
      self.sourceAnnotEdit.setText(msg["Annot"])

  def save(self):
    Document.save(self)
    self.langFile.save()


class MsgFormSource(MsgForm):
  def __init__(self, langFile):
    MsgForm.__init__(self, langFile)

    for x in [self.translEdit,
              self.translAnnotEdit,
              self.label_4,
              self.label_5]:
      x.close()

    Qt.connect(self.sourceEdit, Qt.SIGNAL("textChanged()"), self.sourceEditTextChanged)
    Qt.connect(self.sourceAnnotEdit, Qt.SIGNAL("textChanged()"), self.sourceAnnotEditTextChanged)

  def treeItemChanged(self, current, previous):
    if current == None:
      self.setSourceMsg("")
      return
    ID = current.getID()
    self.currentItem = None
    self.setSourceMsg(self.langFile.getMsg(ID))
    self.currentItem = current

  def sourceEditTextChanged(self):
    if self.currentItem:
      text = unicode(self.sourceEdit.toPlainText())
      self.currentItem.setText(self.colText, text)
      self.currentItem.setMsgText(text)
      self.modified()

  def sourceAnnotEditTextChanged(self):
    if self.currentItem:
      text = unicode(self.sourceAnnotEdit.toPlainText())
      #self.currentItem.setText(self.colAnnot, text)
      self.currentItem.setMsgAnnot(text)
      self.modified()


class MsgIDItem(QtGui.QTreeWidgetItem):
  def __init__(self, parent, text):
    QtGui.QTreeWidgetItem.__init__(self, parent, [text])

class LangFileItem(QtGui.QTreeWidgetItem):
  def __init__(self, parent, langFile):
    QtGui.QTreeWidgetItem.__init__(self, parent, [langFile.langCode])
    self.langFile = langFile
    self.msgForm = None

  def isDocOpen(self):
    return self.msgForm != None

  def openDoc(self):
    if self.msgForm == None:
      if self.langFile.isSource:
        self.msgForm = MsgFormSource(self.langFile)
      else:
        self.msgForm = MsgForm(self.langFile)
      Qt.connect(self.msgForm, Qt.SIGNAL("closed()"), self.docClosed)
    return self.msgForm

  def docClosed(self):
    print "docClosed()"
    self.msgForm = None

class ProjectItem(QtGui.QTreeWidgetItem):
  def __init__(self, text):
    QtGui.QTreeWidgetItem.__init__(self, [text])

class ProjectTree(QtGui.QTreeWidget):
  def __init__(self, parent):
    QtGui.QTreeWidget.__init__(self, parent)
    self.topItem = None
    self.msgIDsItem = None
    self.headerItem().setHidden(True)

  def keyReleaseEvent(self, event):
    Qt = QtCore.Qt
    key = event.key()
    if key in [Qt.Key_Enter, Qt.Key_Return]:
      self.emit(Qt.SIGNAL("onKeyEnter"), self.currentItem())
    elif key == Qt.Key_Delete:
      self.emit(Qt.SIGNAL("onKeyDelete"), self.currentItem())

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

  def contextMenuEvent(self, event):
    item = self.itemAt(event.pos())
    func_map = {
      None : lambda item: None,
      QtGui.QTreeWidgetItem : lambda item: None,
      ProjectItem : self.showMenuProjectItem,
      LangFileItem : self.showMenuLangFileItem,
      MsgIDItem : self.showMenuMsgIDItem
    }
    func_map[type(item)](item)

  def showMenuProjectItem(self, item):
    print "ProjectItem"

  def showMenuLangFileItem(self, item):
    print "LangFileItem"

  def showMenuMsgIDItem(self, item):
    print "MsgIDItem"

  def clear(self):
    self.topItem = None
    self.msgIDsItem = None
    QtGui.QTreeWidget.clear(self)

class NewProjectDialog(QtGui.QDialog, Ui_NewProjectDialog):
  def __init__(self):
    QtGui.QDialog.__init__(self)
    self.setupUi(self)

    Qt.connect(self.pickFileButton, Qt.SIGNAL("clicked()"), self.pickFilePath)

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
