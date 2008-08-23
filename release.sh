#!/bin/bash

if [[ $1 != [0-9].[0-9][0-9][0-9] ]]; then
  echo Wrong version format. Expected: d.ddd
  exit;
fi

BUILD="./build"
DIR="dil.$1"
DEST="$BUILD/$DIR"
FRESH_REPOS="$BUILD/fresh_repos"
DIL="bin/dil"

# Create build directory if it doesn't exist.
[ ! -e $BUILD ] && mkdir $BUILD

# Convert Unix newlines to Windows newlines
# function unix2win
# {
#   sed {s/$/\\r/} $*
# }

# We need dil to get a list of all modules to be compiled.
if [ ! -s $DIL ]; then
  echo "No binary of dil found in PATH. Building one..."
  dsss build -full &> /dev/null
fi

if [ ! -s $DIL ]; then
  echo "Couldn't build dil. Need dil to get a list of modules to be built."
  exit;
fi

# Used by doc generation and winbuild function.
SRC_FILES=`$DIL igraph src/main.d --paths`

# Recreate destination directory.
rm -rf $DEST
mkdir -p $DEST/{bin,doc/htmlsrc,src}

# Create documentation.
echo "***** Generating documentation *****"
SRC_FILES2="data/dilconf.d $SRC_FILES" # Include dilconf.d in doc generation.
$DIL ddoc $DEST/doc/ -v data/macros_dil.ddoc -version=DDoc $SRC_FILES2

echo "***** Generating syntax highlighted HTML files *****"
HTMLSRC="$DEST/doc/htmlsrc"
for filepath in $SRC_FILES2;
do
  # Use sed to remove 'src/' or 'data/' folder, convert '/' to '.' and remove the extension.
  htmlfile=`echo $filepath | sed -e 's@^src/\|data/@@' -e 's@/@.@g' -e 's@.d$@@'`.html
  echo "FILE: $filepath > $HTMLSRC/$htmlfile";
  $DIL hl --lines --syntax --html $filepath > "$HTMLSRC/$htmlfile";
done

function linbuild
{ # The first argument is the path of the binary output file.
  dsss build -clean -full ${@:2} && cp $DIL $1
}

# Linux Debug Binaries
echo "***** Building Linux binaries *****"
linbuild $DEST/bin/dil_d
linbuild $DEST/bin/dil2_d -version=D2
# Linux Release Binaries
# N.B.: the -inline switch makes the binaries significantly larger.
linbuild $DEST/bin/dil -release -O -inline
linbuild $DEST/bin/dil2 -release -O -inline -version=D2

if [ -s ~/bin/dmd.exe ]; then
  echo "***** Building Windows binaries *****"
  function winbuild
  { # The first argument is the path of the binary output file.
    # obj dir is winobj. -op = don't strip paths from obj files.
    wine ~/bin/dmd.exe -odwinobj -op -ofdil.exe ${@:2} $SRC_FILES
    cp dil.exe $1
  }
  # Windows Debug Binaries
  winbuild $DEST/bin/dil_d.exe
  winbuild $DEST/bin/dil2_d.exe -version=D2
  # Windows Release Binaries
  winbuild $DEST/bin/dil.exe -release -O -inline
  winbuild $DEST/bin/dil2.exe -release -O -inline -version=D2
fi

# Copy source and other files.
rm -rf $FRESH_REPOS
hg archive -r tip -t files $FRESH_REPOS
cp -r $FRESH_REPOS/* $DEST

mv $DEST/data/dilconf.d $DEST/bin/
cp $DEST/data/html.css $HTMLSRC

# Build archives
# tar.gz doesn't compress well
tar --owner root --group root -czf $DEST.tar.gz $DEST
tar --owner root --group root --bzip2 -cf $DEST.tar.bz2 $DEST
zip -q -9 -r $DEST.zip $DEST
# Best compression provided by lzma algorithm.
# 7zr a $DEST.7z $DEST
