#!/bin/bash

for ui_file in *.ui; do
  echo $ui_file \> ui_`basename $ui_file .ui`.py
  pyuic4 $ui_file > ui_`basename $ui_file .ui`.py
done