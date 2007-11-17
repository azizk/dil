# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'langfile_properties.ui'
#
# Created: Sat Nov 17 23:14:57 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_LangFilePropertiesDialog(object):
    def setupUi(self, LangFilePropertiesDialog):
        LangFilePropertiesDialog.setObjectName("LangFilePropertiesDialog")
        LangFilePropertiesDialog.resize(QtCore.QSize(QtCore.QRect(0,0,400,228).size()).expandedTo(LangFilePropertiesDialog.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(LangFilePropertiesDialog)
        self.vboxlayout.setObjectName("vboxlayout")

        self.gridlayout = QtGui.QGridLayout()
        self.gridlayout.setObjectName("gridlayout")

        self.label_2 = QtGui.QLabel(LangFilePropertiesDialog)
        self.label_2.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label_2.setObjectName("label_2")
        self.gridlayout.addWidget(self.label_2,1,0,1,1)

        self.langCodeField = QtGui.QLineEdit(LangFilePropertiesDialog)
        self.langCodeField.setObjectName("langCodeField")
        self.gridlayout.addWidget(self.langCodeField,1,1,1,1)

        self.label = QtGui.QLabel(LangFilePropertiesDialog)
        self.label.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTrailing|QtCore.Qt.AlignVCenter)
        self.label.setObjectName("label")
        self.gridlayout.addWidget(self.label,2,0,1,1)

        self.creationDateField = QtGui.QLineEdit(LangFilePropertiesDialog)
        self.creationDateField.setObjectName("creationDateField")
        self.gridlayout.addWidget(self.creationDateField,2,1,1,1)

        self.authorsField = QtGui.QTextEdit(LangFilePropertiesDialog)
        self.authorsField.setObjectName("authorsField")
        self.gridlayout.addWidget(self.authorsField,0,1,1,1)

        self.label_3 = QtGui.QLabel(LangFilePropertiesDialog)
        self.label_3.setAlignment(QtCore.Qt.AlignRight|QtCore.Qt.AlignTop|QtCore.Qt.AlignTrailing)
        self.label_3.setObjectName("label_3")
        self.gridlayout.addWidget(self.label_3,0,0,1,1)
        self.vboxlayout.addLayout(self.gridlayout)

        spacerItem = QtGui.QSpacerItem(20,10,QtGui.QSizePolicy.Minimum,QtGui.QSizePolicy.Fixed)
        self.vboxlayout.addItem(spacerItem)

        self.buttonBox = QtGui.QDialogButtonBox(LangFilePropertiesDialog)
        self.buttonBox.setOrientation(QtCore.Qt.Horizontal)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Cancel|QtGui.QDialogButtonBox.NoButton|QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName("buttonBox")
        self.vboxlayout.addWidget(self.buttonBox)
        self.label_2.setBuddy(self.langCodeField)
        self.label.setBuddy(self.creationDateField)

        self.retranslateUi(LangFilePropertiesDialog)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("accepted()"),LangFilePropertiesDialog.accept)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("rejected()"),LangFilePropertiesDialog.reject)
        QtCore.QMetaObject.connectSlotsByName(LangFilePropertiesDialog)

    def retranslateUi(self, LangFilePropertiesDialog):
        LangFilePropertiesDialog.setWindowTitle(QtGui.QApplication.translate("LangFilePropertiesDialog", "Language File Properties", None, QtGui.QApplication.UnicodeUTF8))
        self.label_2.setText(QtGui.QApplication.translate("LangFilePropertiesDialog", "Language code:", None, QtGui.QApplication.UnicodeUTF8))
        self.label.setText(QtGui.QApplication.translate("LangFilePropertiesDialog", "Creation date:", None, QtGui.QApplication.UnicodeUTF8))
        self.label_3.setText(QtGui.QApplication.translate("LangFilePropertiesDialog", "Author(s):", None, QtGui.QApplication.UnicodeUTF8))

