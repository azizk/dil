#!/bin/bash
FILES=`echo -n data/{html.css,html_map.d,lang_de.d,lang_en.d,lang_fi.d,lang_tr.d,macros_dil.ddoc,predefined.ddoc,predefined_xml.ddoc,xml.css,xml_map.d}`
cp data/config.d bin/
cp $FILES bin/data/