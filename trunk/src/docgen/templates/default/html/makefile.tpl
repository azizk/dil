#!/bin/sh

for i in *.dot; do
  F=`echo $i|sed 's/dot/{0}/'`
  dot $i -T{0} -o$F
done

