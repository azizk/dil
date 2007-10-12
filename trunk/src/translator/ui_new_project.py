# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'new_project.ui'
#
# Created: Thu Oct 11 21:16:07 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_NewProjectDialog(object):
    def setupUi(self, NewProjectDialog):
        NewProjectDialog.setObjectName("NewProjectDialog")
        NewProjectDialog.resize(QtCore.QSize(QtCore.QRect(0,0,401,131).size()).expandedTo(NewProjectDialog.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(NewProjectDialog)
        self.vboxlayout.setObjectName("vboxlayout")

        self.gridlayout = QtGui.QGridLayout()
        self.gridlayout.setObjectName("gridlayout")

        self.gridlayout1 = QtGui.QGridLayout()
        self.gridlayout1.setObjectName("gridlayout1")

        self.label = QtGui.QLabel(NewProjectDialog)
        self.label.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label.setObjectName("label")
        self.gridlayout1.addWidget(self.label,0,0,1,1)

        self.projectName = QtGui.QLineEdit(NewProjectDialog)
        self.projectName.setObjectName("projectName")
        self.gridlayout1.addWidget(self.projectName,0,1,1,1)

        self.label_2 = QtGui.QLabel(NewProjectDialog)
        self.label_2.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label_2.setObjectName("label_2")
        self.gridlayout1.addWidget(self.label_2,1,0,1,1)

        self.hboxlayout = QtGui.QHBoxLayout()
        self.hboxlayout.setObjectName("hboxlayout")

        self.projectFilePath = QtGui.QLineEdit(NewProjectDialog)
        self.projectFilePath.setObjectName("projectFilePath")
        self.hboxlayout.addWidget(self.projectFilePath)

        self.pickFileButton = QtGui.QToolButton(NewProjectDialog)
        self.pickFileButton.setObjectName("pickFileButton")
        self.hboxlayout.addWidget(self.pickFileButton)
        self.gridlayout1.addLayout(self.hboxlayout,1,1,1,1)
        self.gridlayout.addLayout(self.gridlayout1,0,0,1,1)

        spacerItem = QtGui.QSpacerItem(20,40,QtGui.QSizePolicy.Minimum,QtGui.QSizePolicy.Expanding)
        self.gridlayout.addItem(spacerItem,1,0,1,1)

        self.buttonBox = QtGui.QDialogButtonBox(NewProjectDialog)
        self.buttonBox.setOrientation(QtCore.Qt.Horizontal)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.NoButton|QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName("buttonBox")
        self.gridlayout.addWidget(self.buttonBox,2,0,1,1)
        self.vboxlayout.addLayout(self.gridlayout)
        self.label.setBuddy(self.projectName)
        self.label_2.setBuddy(self.projectFilePath)

        self.retranslateUi(NewProjectDialog)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("accepted()"),NewProjectDialog.accept)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("rejected()"),NewProjectDialog.reject)
        QtCore.QMetaObject.connectSlotsByName(NewProjectDialog)

    def retranslateUi(self, NewProjectDialog):
        NewProjectDialog.setWindowTitle(QtGui.QApplication.translate("NewProjectDialog", "Create New Project", None, QtGui.QApplication.UnicodeUTF8))
        self.label.setText(QtGui.QApplication.translate("NewProjectDialog", "Project name:", None, QtGui.QApplication.UnicodeUTF8))
        self.label_2.setText(QtGui.QApplication.translate("NewProjectDialog", "Project file:", None, QtGui.QApplication.UnicodeUTF8))
        self.pickFileButton.setText(QtGui.QApplication.translate("NewProjectDialog", "...", None, QtGui.QApplication.UnicodeUTF8))

