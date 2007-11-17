# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'project_properties.ui'
#
# Created: Sat Nov 17 23:14:55 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_ProjectPropertiesDialog(object):
    def setupUi(self, ProjectPropertiesDialog):
        ProjectPropertiesDialog.setObjectName("ProjectPropertiesDialog")
        ProjectPropertiesDialog.resize(QtCore.QSize(QtCore.QRect(0,0,400,152).size()).expandedTo(ProjectPropertiesDialog.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(ProjectPropertiesDialog)
        self.vboxlayout.setObjectName("vboxlayout")

        self.gridlayout = QtGui.QGridLayout()
        self.gridlayout.setObjectName("gridlayout")

        self.label_2 = QtGui.QLabel(ProjectPropertiesDialog)
        self.label_2.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label_2.setObjectName("label_2")
        self.gridlayout.addWidget(self.label_2,0,0,1,1)

        self.projectNameField = QtGui.QLineEdit(ProjectPropertiesDialog)
        self.projectNameField.setObjectName("projectNameField")
        self.gridlayout.addWidget(self.projectNameField,0,1,1,1)

        self.label = QtGui.QLabel(ProjectPropertiesDialog)
        self.label.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label.setObjectName("label")
        self.gridlayout.addWidget(self.label,1,0,1,1)

        self.hboxlayout = QtGui.QHBoxLayout()
        self.hboxlayout.setObjectName("hboxlayout")

        self.buildScriptField = QtGui.QLineEdit(ProjectPropertiesDialog)
        self.buildScriptField.setObjectName("buildScriptField")
        self.hboxlayout.addWidget(self.buildScriptField)

        self.pickFileButton = QtGui.QToolButton(ProjectPropertiesDialog)
        self.pickFileButton.setObjectName("pickFileButton")
        self.hboxlayout.addWidget(self.pickFileButton)
        self.gridlayout.addLayout(self.hboxlayout,1,1,1,1)

        self.creationDateField = QtGui.QLineEdit(ProjectPropertiesDialog)
        self.creationDateField.setObjectName("creationDateField")
        self.gridlayout.addWidget(self.creationDateField,2,1,1,1)

        self.label_3 = QtGui.QLabel(ProjectPropertiesDialog)
        self.label_3.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label_3.setObjectName("label_3")
        self.gridlayout.addWidget(self.label_3,2,0,1,1)
        self.vboxlayout.addLayout(self.gridlayout)

        spacerItem = QtGui.QSpacerItem(20,40,QtGui.QSizePolicy.Minimum,QtGui.QSizePolicy.Expanding)
        self.vboxlayout.addItem(spacerItem)

        self.buttonBox = QtGui.QDialogButtonBox(ProjectPropertiesDialog)
        self.buttonBox.setOrientation(QtCore.Qt.Horizontal)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.NoButton|QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName("buttonBox")
        self.vboxlayout.addWidget(self.buttonBox)
        self.label_2.setBuddy(self.projectNameField)
        self.label.setBuddy(self.buildScriptField)

        self.retranslateUi(ProjectPropertiesDialog)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("accepted()"),ProjectPropertiesDialog.accept)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("rejected()"),ProjectPropertiesDialog.reject)
        QtCore.QMetaObject.connectSlotsByName(ProjectPropertiesDialog)

    def retranslateUi(self, ProjectPropertiesDialog):
        ProjectPropertiesDialog.setWindowTitle(QtGui.QApplication.translate("ProjectPropertiesDialog", "Project Properties", None, QtGui.QApplication.UnicodeUTF8))
        self.label_2.setText(QtGui.QApplication.translate("ProjectPropertiesDialog", "Project name:", None, QtGui.QApplication.UnicodeUTF8))
        self.label.setText(QtGui.QApplication.translate("ProjectPropertiesDialog", "Build script:", None, QtGui.QApplication.UnicodeUTF8))
        self.pickFileButton.setText(QtGui.QApplication.translate("ProjectPropertiesDialog", "...", None, QtGui.QApplication.UnicodeUTF8))
        self.label_3.setText(QtGui.QApplication.translate("ProjectPropertiesDialog", "Creation date:", None, QtGui.QApplication.UnicodeUTF8))

