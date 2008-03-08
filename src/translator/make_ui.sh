#!/bin/bash

ui_file=$1
echo $ui_file \> ui_`basename $ui_file .ui`.py
pyuic4 $ui_file > ui_`basename $ui_file .ui`.py
