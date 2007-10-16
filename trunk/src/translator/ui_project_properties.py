# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'project_properties.ui'
#
# Created: Tue Oct 16 21:58:58 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_ProjectProperties(object):
    def setupUi(self, ProjectProperties):
        ProjectProperties.setObjectName("ProjectProperties")
        ProjectProperties.resize(QtCore.QSize(QtCore.QRect(0,0,400,148).size()).expandedTo(ProjectProperties.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(ProjectProperties)
        self.vboxlayout.setObjectName("vboxlayout")

        self.gridlayout = QtGui.QGridLayout()
        self.gridlayout.setObjectName("gridlayout")

        self.label_2 = QtGui.QLabel(ProjectProperties)
        self.label_2.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label_2.setObjectName("label_2")
        self.gridlayout.addWidget(self.label_2,0,0,1,1)

        self.projectNameField = QtGui.QLineEdit(ProjectProperties)
        self.projectNameField.setObjectName("projectNameField")
        self.gridlayout.addWidget(self.projectNameField,0,1,1,1)

        self.label = QtGui.QLabel(ProjectProperties)
        self.label.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label.setObjectName("label")
        self.gridlayout.addWidget(self.label,1,0,1,1)

        self.buildCommandField = QtGui.QLineEdit(ProjectProperties)
        self.buildCommandField.setObjectName("buildCommandField")
        self.gridlayout.addWidget(self.buildCommandField,1,1,1,1)
        self.vboxlayout.addLayout(self.gridlayout)

        spacerItem = QtGui.QSpacerItem(20,40,QtGui.QSizePolicy.Minimum,QtGui.QSizePolicy.Expanding)
        self.vboxlayout.addItem(spacerItem)

        self.buttonBox = QtGui.QDialogButtonBox(ProjectProperties)
        self.buttonBox.setOrientation(QtCore.Qt.Horizontal)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.NoButton|QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName("buttonBox")
        self.vboxlayout.addWidget(self.buttonBox)
        self.label_2.setBuddy(self.projectNameField)
        self.label.setBuddy(self.buildCommandField)

        self.retranslateUi(ProjectProperties)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("accepted()"),ProjectProperties.accept)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("rejected()"),ProjectProperties.reject)
        QtCore.QMetaObject.connectSlotsByName(ProjectProperties)

    def retranslateUi(self, ProjectProperties):
        ProjectProperties.setWindowTitle(QtGui.QApplication.translate("ProjectProperties", "Project Properties", None, QtGui.QApplication.UnicodeUTF8))
        self.label_2.setText(QtGui.QApplication.translate("ProjectProperties", "Project name:", None, QtGui.QApplication.UnicodeUTF8))
        self.label.setText(QtGui.QApplication.translate("ProjectProperties", "Build command:", None, QtGui.QApplication.UnicodeUTF8))

