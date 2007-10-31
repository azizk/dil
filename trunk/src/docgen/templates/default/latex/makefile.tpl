#!/bin/sh

for i in *.dot; do
  F=`echo $i|sed 's/dot/{1}/'`
  dot $i -T{1} -o$F
done

pdflatex {0}
makeindex document
pdflatex {0}
