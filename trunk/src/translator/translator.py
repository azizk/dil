#! /bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import sys
from PyQt4 import QtCore, QtGui

from ui_translator import Ui_MainWindow
from ui_about import Ui_AboutDialog

class MainWindow(QtGui.QMainWindow, Ui_MainWindow):
  def __init__(self):
    QtGui.QMainWindow.__init__(self)
    self.setupUi(self)

    # Modifications

    # Custom connections
    QtCore.QObject.connect(self.actionAbout, QtCore.SIGNAL("triggered()"), self.aboutDialog)

  def aboutDialog(self):
    about = QtGui.QDialog()
    Ui_AboutDialog().setupUi(about)
    about.exec_()


if __name__ == "__main__":
  app = QtGui.QApplication(sys.argv)
  main = MainWindow()
  main.show()
  sys.exit(app.exec_())
