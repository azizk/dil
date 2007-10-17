#!/bin/bash

if [[ $1 != [0-9].[0-9][0-9][0-9] ]]; then
  echo Wrong version format. Expected: d.ddd
  exit;
fi

NAME="dil"
BUILD="./build"
DIR="$NAME.$1"
DEST="${BUILD}/$DIR"
FRESH_REPOS="fresh_repos"

# Create build directory.
[ ! -e $BUILD ] && mkdir $BUILD

# Convert Unix newlines to Windows newlines
# function unix2win
# {
#   sed {s/$/\\r/} $*
# }

# We need dil to get a list of all modules to be compiled.
if [ ! -s ./dil ]; then
  dsss build -full -w &> /dev/null
fi
SRC_FILES=`./dil igraph src/main.d --paths`
function winbuild
{
  wine ~/bin/dmd.exe $SRC_FILES -odwinobj -ofdil $*
}

# Recreate destination director.
rm -rf $DEST
mkdir $DEST $DEST/bin $DEST/src

# Linux Debug
dsss build -clean -full -version=D2
cp dil $DEST/bin/dil2_d
dsss build -clean -full
cp dil $DEST/bin/dil_d
# Linux Release
dsss build -clean -full -release -O -inline -version=D2
cp dil $DEST/bin/dil2
dsss build -clean -full -release -O -inline
cp dil $DEST/bin/dil

if [ -s ~/bin/dmd.exe ]; then
  echo "*** Building Windows Binaries ***\n"
  # Windows Debug
  winbuild -version=D2
  cp dil.exe $DEST/bin/dil2_d.exe
  winbuild
  cp dil.exe $DEST/bin/dil_d.exe
  # Windows Release
  winbuild -release -O -inline -version=D2
  cp dil.exe $DEST/bin/dil2.exe
  winbuild -release -O -inline
  cp dil.exe $DEST/bin/dil.exe
fi

# Copy source and other files.
rm -rf $BUILD/$FRESH_REPOS
hg archive -r tip -t files $BUILD/$FRESH_REPOS
cp -r $BUILD/$FRESH_REPOS/trunk/* $DEST

cp $BUILD/$FRESH_REPOS/trunk/src/config.d $DEST/bin/
cp $BUILD/$FRESH_REPOS/trunk/src/lang_*.d $DEST/bin/

# Build archives
cd $BUILD
# tar.gz doesn't compress well
tar --owner root --group root -czf $DIR.tar.gz $DIR
tar --owner root --group root --bzip2 -cf $DIR.tar.bz2 $DIR
zip -q -9 -r $DIR.zip $DIR
