#!/bin/bash

for svg_file in `ls kandil/img/*.svg`;
do
  file_name=`basename $svg_file .svg`
  file=kandil/img/$file_name.png
  # Use Inkscape to export a 16x16 sized PNG.
  inkscape $svg_file --export-png=$file -w16 -h16
  # Use Image Magick to change the resolution of the image.
  # Inkscape can't set the resolution and size at the same time :(
  convert -units PixelsPerInch -density 96 $file $file
done
