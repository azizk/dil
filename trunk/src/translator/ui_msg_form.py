# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'msg_form.ui'
#
# Created: Fri Nov  9 15:38:32 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_MsgForm(object):
    def setupUi(self, MsgForm):
        MsgForm.setObjectName("MsgForm")
        MsgForm.resize(QtCore.QSize(QtCore.QRect(0,0,456,512).size()).expandedTo(MsgForm.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(MsgForm)
        self.vboxlayout.setObjectName("vboxlayout")

        self.splitter = QtGui.QSplitter(MsgForm)
        self.splitter.setOrientation(QtCore.Qt.Vertical)
        self.splitter.setObjectName("splitter")

        self.layoutWidget = QtGui.QWidget(self.splitter)
        self.layoutWidget.setObjectName("layoutWidget")

        self.vboxlayout1 = QtGui.QVBoxLayout(self.layoutWidget)
        self.vboxlayout1.setObjectName("vboxlayout1")

        self.label = QtGui.QLabel(self.layoutWidget)
        self.label.setObjectName("label")
        self.vboxlayout1.addWidget(self.label)

        self.treeWidget = QtGui.QTreeWidget(self.layoutWidget)
        self.treeWidget.setObjectName("treeWidget")
        self.vboxlayout1.addWidget(self.treeWidget)

        self.layoutWidget1 = QtGui.QWidget(self.splitter)
        self.layoutWidget1.setObjectName("layoutWidget1")

        self.gridlayout = QtGui.QGridLayout(self.layoutWidget1)
        self.gridlayout.setObjectName("gridlayout")

        self.vboxlayout2 = QtGui.QVBoxLayout()
        self.vboxlayout2.setObjectName("vboxlayout2")

        self.label_2 = QtGui.QLabel(self.layoutWidget1)
        self.label_2.setObjectName("label_2")
        self.vboxlayout2.addWidget(self.label_2)

        self.sourceEdit = QtGui.QTextEdit(self.layoutWidget1)
        self.sourceEdit.setObjectName("sourceEdit")
        self.vboxlayout2.addWidget(self.sourceEdit)
        self.gridlayout.addLayout(self.vboxlayout2,0,0,1,1)

        self.vboxlayout3 = QtGui.QVBoxLayout()
        self.vboxlayout3.setObjectName("vboxlayout3")

        self.label_3 = QtGui.QLabel(self.layoutWidget1)
        self.label_3.setObjectName("label_3")
        self.vboxlayout3.addWidget(self.label_3)

        self.sourceAnnotEdit = QtGui.QTextEdit(self.layoutWidget1)
        self.sourceAnnotEdit.setObjectName("sourceAnnotEdit")
        self.vboxlayout3.addWidget(self.sourceAnnotEdit)
        self.gridlayout.addLayout(self.vboxlayout3,0,1,1,1)

        self.vboxlayout4 = QtGui.QVBoxLayout()
        self.vboxlayout4.setObjectName("vboxlayout4")

        self.label_4 = QtGui.QLabel(self.layoutWidget1)
        self.label_4.setObjectName("label_4")
        self.vboxlayout4.addWidget(self.label_4)

        self.translEdit = QtGui.QTextEdit(self.layoutWidget1)
        self.translEdit.setObjectName("translEdit")
        self.vboxlayout4.addWidget(self.translEdit)
        self.gridlayout.addLayout(self.vboxlayout4,1,0,1,1)

        self.vboxlayout5 = QtGui.QVBoxLayout()
        self.vboxlayout5.setObjectName("vboxlayout5")

        self.label_5 = QtGui.QLabel(self.layoutWidget1)
        self.label_5.setObjectName("label_5")
        self.vboxlayout5.addWidget(self.label_5)

        self.translAnnotEdit = QtGui.QTextEdit(self.layoutWidget1)
        self.translAnnotEdit.setObjectName("translAnnotEdit")
        self.vboxlayout5.addWidget(self.translAnnotEdit)
        self.gridlayout.addLayout(self.vboxlayout5,1,1,1,1)
        self.vboxlayout.addWidget(self.splitter)

        self.retranslateUi(MsgForm)
        QtCore.QMetaObject.connectSlotsByName(MsgForm)

    def retranslateUi(self, MsgForm):
        MsgForm.setWindowTitle(QtGui.QApplication.translate("MsgForm", "Form", None, QtGui.QApplication.UnicodeUTF8))
        self.label.setText(QtGui.QApplication.translate("MsgForm", "Messages:", None, QtGui.QApplication.UnicodeUTF8))
        self.treeWidget.headerItem().setText(0,QtGui.QApplication.translate("MsgForm", "1", None, QtGui.QApplication.UnicodeUTF8))
        self.label_2.setText(QtGui.QApplication.translate("MsgForm", "Source string:", None, QtGui.QApplication.UnicodeUTF8))
        self.label_3.setText(QtGui.QApplication.translate("MsgForm", "Source annotation:", None, QtGui.QApplication.UnicodeUTF8))
        self.label_4.setText(QtGui.QApplication.translate("MsgForm", "Translation:", None, QtGui.QApplication.UnicodeUTF8))
        self.label_5.setText(QtGui.QApplication.translate("MsgForm", "Translator\'s annotation:", None, QtGui.QApplication.UnicodeUTF8))

