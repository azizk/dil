#!/bin/bash

for svg_file in `ls kandil/img/*.svg`;
do
  file_name=`basename $svg_file .svg`
  # Use inkscape to export a 48x48 sized PNG.
  inkscape $svg_file --export-png=kandil/img/$file_name.png -w48 -h48
done
