#!/bin/bash

for ui_file in *.ui; do
  ./make_ui.sh $ui_file
done