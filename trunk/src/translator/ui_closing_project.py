# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'closing_project.ui'
#
# Created: Sun Nov 11 23:01:28 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_ClosingProjectDialog(object):
    def setupUi(self, ClosingProjectDialog):
        ClosingProjectDialog.setObjectName("ClosingProjectDialog")
        ClosingProjectDialog.resize(QtCore.QSize(QtCore.QRect(0,0,400,300).size()).expandedTo(ClosingProjectDialog.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(ClosingProjectDialog)
        self.vboxlayout.setObjectName("vboxlayout")

        self.label = QtGui.QLabel(ClosingProjectDialog)
        self.label.setObjectName("label")
        self.vboxlayout.addWidget(self.label)

        self.treeWidget = QtGui.QTreeWidget(ClosingProjectDialog)
        self.treeWidget.setObjectName("treeWidget")
        self.vboxlayout.addWidget(self.treeWidget)

        spacerItem = QtGui.QSpacerItem(382,33,QtGui.QSizePolicy.Minimum,QtGui.QSizePolicy.Expanding)
        self.vboxlayout.addItem(spacerItem)

        self.hboxlayout = QtGui.QHBoxLayout()
        self.hboxlayout.setObjectName("hboxlayout")

        spacerItem1 = QtGui.QSpacerItem(40,20,QtGui.QSizePolicy.Expanding,QtGui.QSizePolicy.Minimum)
        self.hboxlayout.addItem(spacerItem1)

        self.button_Save_Selected = QtGui.QPushButton(ClosingProjectDialog)
        self.button_Save_Selected.setObjectName("button_Save_Selected")
        self.hboxlayout.addWidget(self.button_Save_Selected)

        self.button_Discard_All = QtGui.QPushButton(ClosingProjectDialog)
        self.button_Discard_All.setObjectName("button_Discard_All")
        self.hboxlayout.addWidget(self.button_Discard_All)

        self.button_Cancel = QtGui.QPushButton(ClosingProjectDialog)
        self.button_Cancel.setDefault(True)
        self.button_Cancel.setObjectName("button_Cancel")
        self.hboxlayout.addWidget(self.button_Cancel)
        self.vboxlayout.addLayout(self.hboxlayout)

        self.retranslateUi(ClosingProjectDialog)
        QtCore.QObject.connect(self.button_Save_Selected,QtCore.SIGNAL("clicked()"),ClosingProjectDialog.accept)
        QtCore.QObject.connect(self.button_Cancel,QtCore.SIGNAL("clicked()"),ClosingProjectDialog.reject)
        QtCore.QMetaObject.connectSlotsByName(ClosingProjectDialog)

    def retranslateUi(self, ClosingProjectDialog):
        ClosingProjectDialog.setWindowTitle(QtGui.QApplication.translate("ClosingProjectDialog", "Closing Project", None, QtGui.QApplication.UnicodeUTF8))
        self.label.setText(QtGui.QApplication.translate("ClosingProjectDialog", "The following documents have been modified:", None, QtGui.QApplication.UnicodeUTF8))
        self.treeWidget.headerItem().setText(0,QtGui.QApplication.translate("ClosingProjectDialog", "Title", None, QtGui.QApplication.UnicodeUTF8))
        self.treeWidget.headerItem().setText(1,QtGui.QApplication.translate("ClosingProjectDialog", "Full Path", None, QtGui.QApplication.UnicodeUTF8))
        self.button_Save_Selected.setText(QtGui.QApplication.translate("ClosingProjectDialog", "&Save Selected", None, QtGui.QApplication.UnicodeUTF8))
        self.button_Discard_All.setText(QtGui.QApplication.translate("ClosingProjectDialog", "&Discard All Changes", None, QtGui.QApplication.UnicodeUTF8))
        self.button_Cancel.setText(QtGui.QApplication.translate("ClosingProjectDialog", "&Cancel", None, QtGui.QApplication.UnicodeUTF8))

