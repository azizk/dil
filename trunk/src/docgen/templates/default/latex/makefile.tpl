#!/bin/sh

for i in *.dot; do
  F=`echo $i|sed 's/dot/{2}/'`
  dot $i -T{2} -o$F
done

pdflatex {1}
makeindex document
pdflatex {1}
