#! /bin/python
# -*- coding: utf-8 -*-
# Author: Aziz Köksal
# License: GPL2
import sys
from PyQt4 import QtCore, QtGui

from ui_translator import Ui_MainWindow


if __name__ == "__main__":
    app = QtGui.QApplication(sys.argv)
    main = QtGui.QMainWindow()
    Ui_MainWindow().setupUi(main)
    main.show()
    sys.exit(app.exec_())
