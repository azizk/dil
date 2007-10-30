# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'about.ui'
#
# Created: Sun Oct 21 17:33:29 2007
#      by: PyQt4 UI code generator 4.1
#
# WARNING! All changes made in this file will be lost!

import sys
from PyQt4 import QtCore, QtGui

class Ui_AboutDialog(object):
    def setupUi(self, AboutDialog):
        AboutDialog.setObjectName("AboutDialog")
        AboutDialog.setWindowModality(QtCore.Qt.WindowModal)
        AboutDialog.resize(QtCore.QSize(QtCore.QRect(0,0,414,157).size()).expandedTo(AboutDialog.minimumSizeHint()))

        self.vboxlayout = QtGui.QVBoxLayout(AboutDialog)
        self.vboxlayout.setObjectName("vboxlayout")

        self.label1 = QtGui.QLabel(AboutDialog)
        self.label1.setTextFormat(QtCore.Qt.RichText)
        self.label1.setAlignment(QtCore.Qt.AlignLeading|QtCore.Qt.AlignLeft|QtCore.Qt.AlignTop)
        self.label1.setWordWrap(True)
        self.label1.setObjectName("label1")
        self.vboxlayout.addWidget(self.label1)

        self.buttonBox = QtGui.QDialogButtonBox(AboutDialog)
        self.buttonBox.setStandardButtons(QtGui.QDialogButtonBox.Ok)
        self.buttonBox.setObjectName("buttonBox")
        self.vboxlayout.addWidget(self.buttonBox)

        self.retranslateUi(AboutDialog)
        QtCore.QObject.connect(self.buttonBox,QtCore.SIGNAL("accepted()"),AboutDialog.close)
        QtCore.QMetaObject.connectSlotsByName(AboutDialog)

    def retranslateUi(self, AboutDialog):
        AboutDialog.setWindowTitle(QtGui.QApplication.translate("AboutDialog", "About", None, QtGui.QApplication.UnicodeUTF8))
        self.label1.setText(QtGui.QApplication.translate("AboutDialog", "<html><head><meta name=\"qrichtext\" content=\"1\" /><style type=\"text/css\">\n"
        "p, li { white-space: pre-wrap; }\n"
        "</style></head><body style=\" font-family:\'Sans Serif\'; font-size:9pt; font-weight:400; font-style:normal;\">\n"
        "<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\">A tool for managing message catalogues in different languages.</p>\n"
        "<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\">These catalogues can be used to make an application multilingual.</p>\n"
        "<p style=\"-qt-paragraph-type:empty; margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\"></p>\n"
        "<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\">Copyright © 2007 by Aziz Köksal &lt;aziz.koeksal@gmail.com&gt;</p>\n"
        "<p style=\" margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px;\">Licensed under the GPL2.</p></body></html>", None, QtGui.QApplication.UnicodeUTF8))

