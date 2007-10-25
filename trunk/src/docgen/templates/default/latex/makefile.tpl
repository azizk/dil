#!/bin/sh

for i in *.dot; do
  F=`echo $i|sed 's/dot/pdf/'`
  dot $i -Tpdf -o$F
done

pdflatex document.tex
makeindex document
pdflatex document.tex
