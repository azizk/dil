#!/bin/sh

for i in *.dot; do
  F=`echo $i|sed 's/dot/png/'`
  dot $i -Tpng -o$F
done

