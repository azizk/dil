#!/bin/sh

for i in *.dot; do
  F=`echo $i|sed 's/dot/ps/'`
  dot $i -Tps2 -o$F
  ps2pdf $F
done

pdflatex document.tex
pdflatex document.tex
