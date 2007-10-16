# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'translator.ui'
#
# Created: Sun Oct 14 13:11:43 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        MainWindow.setObjectName("MainWindow")
        MainWindow.resize(QtCore.QSize(QtCore.QRect(0,0,608,464).size()).expandedTo(MainWindow.minimumSizeHint()))

        self.centralwidget = QtGui.QWidget(MainWindow)
        self.centralwidget.setObjectName("centralwidget")

        self.vboxlayout = QtGui.QVBoxLayout(self.centralwidget)
        self.vboxlayout.setObjectName("vboxlayout")
        MainWindow.setCentralWidget(self.centralwidget)

        self.menubar = QtGui.QMenuBar(MainWindow)
        self.menubar.setGeometry(QtCore.QRect(0,0,608,29))
        self.menubar.setObjectName("menubar")

        self.menu_File = QtGui.QMenu(self.menubar)
        self.menu_File.setObjectName("menu_File")

        self.menu_Help = QtGui.QMenu(self.menubar)
        self.menu_Help.setObjectName("menu_Help")

        self.menu_Project = QtGui.QMenu(self.menubar)
        self.menu_Project.setObjectName("menu_Project")
        MainWindow.setMenuBar(self.menubar)

        self.statusbar = QtGui.QStatusBar(MainWindow)
        self.statusbar.setObjectName("statusbar")
        MainWindow.setStatusBar(self.statusbar)

        self.action_Quit = QtGui.QAction(MainWindow)
        self.action_Quit.setObjectName("action_Quit")

        self.action_About = QtGui.QAction(MainWindow)
        self.action_About.setObjectName("action_About")

        self.action_New_Project = QtGui.QAction(MainWindow)
        self.action_New_Project.setObjectName("action_New_Project")

        self.action_Add_Catalogue = QtGui.QAction(MainWindow)
        self.action_Add_Catalogue.setObjectName("action_Add_Catalogue")

        self.action_Properties = QtGui.QAction(MainWindow)
        self.action_Properties.setObjectName("action_Properties")

        self.action_Build_Project = QtGui.QAction(MainWindow)
        self.action_Build_Project.setObjectName("action_Build_Project")

        self.action_Open_Project = QtGui.QAction(MainWindow)
        self.action_Open_Project.setObjectName("action_Open_Project")

        self.action_Close_Project = QtGui.QAction(MainWindow)
        self.action_Close_Project.setObjectName("action_Close_Project")
        self.menu_File.addAction(self.action_Open_Project)
        self.menu_File.addAction(self.action_New_Project)
        self.menu_File.addAction(self.action_Close_Project)
        self.menu_File.addSeparator()
        self.menu_File.addAction(self.action_Quit)
        self.menu_Help.addAction(self.action_About)
        self.menu_Project.addAction(self.action_Add_Catalogue)
        self.menu_Project.addAction(self.action_Build_Project)
        self.menu_Project.addSeparator()
        self.menu_Project.addAction(self.action_Properties)
        self.menubar.addAction(self.menu_File.menuAction())
        self.menubar.addAction(self.menu_Project.menuAction())
        self.menubar.addAction(self.menu_Help.menuAction())

        self.retranslateUi(MainWindow)
        QtCore.QObject.connect(self.action_Quit,QtCore.SIGNAL("triggered()"),MainWindow.close)
        QtCore.QMetaObject.connectSlotsByName(MainWindow)

    def retranslateUi(self, MainWindow):
        MainWindow.setWindowTitle(QtGui.QApplication.translate("MainWindow", "Translator", None, QtGui.QApplication.UnicodeUTF8))
        self.menu_File.setTitle(QtGui.QApplication.translate("MainWindow", "&File", None, QtGui.QApplication.UnicodeUTF8))
        self.menu_Help.setTitle(QtGui.QApplication.translate("MainWindow", "&Help", None, QtGui.QApplication.UnicodeUTF8))
        self.menu_Project.setTitle(QtGui.QApplication.translate("MainWindow", "&Project", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Quit.setText(QtGui.QApplication.translate("MainWindow", "&Quit", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Quit.setShortcut(QtGui.QApplication.translate("MainWindow", "Ctrl+Q", None, QtGui.QApplication.UnicodeUTF8))
        self.action_About.setText(QtGui.QApplication.translate("MainWindow", "&About", None, QtGui.QApplication.UnicodeUTF8))
        self.action_New_Project.setText(QtGui.QApplication.translate("MainWindow", "&New Project...", None, QtGui.QApplication.UnicodeUTF8))
        self.action_New_Project.setShortcut(QtGui.QApplication.translate("MainWindow", "Ctrl+N", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Add_Catalogue.setText(QtGui.QApplication.translate("MainWindow", "&Add catalogue", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Properties.setText(QtGui.QApplication.translate("MainWindow", "&Properties", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Build_Project.setText(QtGui.QApplication.translate("MainWindow", "&Build Project", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Open_Project.setText(QtGui.QApplication.translate("MainWindow", "&Open Project...", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Open_Project.setShortcut(QtGui.QApplication.translate("MainWindow", "Ctrl+O", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Close_Project.setText(QtGui.QApplication.translate("MainWindow", "&Close Project", None, QtGui.QApplication.UnicodeUTF8))
        self.action_Close_Project.setShortcut(QtGui.QApplication.translate("MainWindow", "Ctrl+W", None, QtGui.QApplication.UnicodeUTF8))

