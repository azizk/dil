#!/bin/bash

if [[ $1 != [0-9].[0-9][0-9][0-9] ]]; then
  echo Wrong version format. Expected: d.ddd
  exit;
fi

BUILD="./build"
DIR="dil.$1"
DEST="$BUILD/$DIR"
FRESH_REPOS="$BUILD/fresh_repos"

# Create build directory if it doesn't exist.
[ ! -e $BUILD ] && mkdir $BUILD

# Convert Unix newlines to Windows newlines
# function unix2win
# {
#   sed {s/$/\\r/} $*
# }

# We need dil to get a list of all modules to be compiled.
if [ ! -s ./dil ]; then
  dsss build -full &> /dev/null
fi

if [ ! -s ./dil ]; then
  echo "Couldn't build DIL. Can't get list of modules to be built."
  exit;
fi

# Used by doc generation and winbuild function.
SRC_FILES=`./dil igraph src/main.d --paths`

# Recreate destination directory.
rm -rf $DEST
mkdir -p $DEST/{bin,doc/htmlsrc,src}

# Create documentation.
./dil ddoc $DEST/doc/ -v src/macros_dil.ddoc -version=DDoc src/config.d $SRC_FILES
# Generate syntax highlighted HTML files.
HTMLSRC="$DEST/doc/htmlsrc"
for filepath in $SRC_FILES;
do
  htmlfile=`echo $filepath | sed -e 's@^src/@@' -e 's@/@.@g' -e 's@.d$@@'`.html
  echo "FILE: $filepath > $HTMLSRC/$htmlfile";
  ./dil gen --lines --syntax --html $filepath > "$HTMLSRC/$htmlfile";
done

# Linux Debug
echo "***** Building Linux binaries *****"
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
  echo "***** Building Windows binaries *****"
  function winbuild
  { # obj dir is winobj. -op = don't strip paths from obj files.
    wine ~/bin/dmd.exe -odwinobj -op -ofdil $* $SRC_FILES
  }
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
rm -rf $FRESH_REPOS
hg archive -r tip -t files $FRESH_REPOS
cp -r $FRESH_REPOS/trunk/* $DEST

cp $FRESH_REPOS/trunk/src/config.d $DEST/bin/
cp $FRESH_REPOS/trunk/src/lang_*.d $DEST/bin/
cp $FRESH_REPOS/trunk/src/*_map.d $DEST/bin/
cp $FRESH_REPOS/trunk/src/*.css $DEST/bin/
cp $FRESH_REPOS/trunk/src/predefined.ddoc $DEST/bin/
cp $FRESH_REPOS/trunk/src/html.css $HTMLSRC

# Build archives
# tar.gz doesn't compress well
tar --owner root --group root -czf $DEST.tar.gz $DEST
tar --owner root --group root --bzip2 -cf $DEST.tar.bz2 $DEST
zip -q -9 -r $DEST.zip $DEST
