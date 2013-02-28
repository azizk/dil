DIL
===
Copyright (c) 2007-2013 by Aziz Köksal <aziz.koeksal@gmail.com>
This program is free software, licensed under the GPL3.
Please, read the license file "COPYING" for further information.

Description
===========
This software is a command line utility, a compiler written in D v2
for the D programming language supporting versions 1.0 and 2.0.

Status
======
  * Lexing: `[░░░99%░░░░]`
  * Parsing: `[░░░99%░░░░]`
  * Doc gen: `[░░░80%░░░ ]`
  * Semantics: `[░░  20%   ]`
  * Code gen: `[    0%    ]`

Installation
============
Download and install from:

  * *.deb files for Debian-based Linux distributions.
  * Compressed archives.<br/>
    After extracting an archive, you can simply run DIL.
    No extra configuration needed (except, you might want to add the binary dir
    to your PATH variable.)

Not available yet:

  * Windows installer.

Contributing
============
If you are interested in contributing code to this project,
you have to be in agreement with two conditions:

  1. You must adhere to the [coding guidelines](wiki/codingrules.wiki).
  2. Code that you submit is considered to be under a liberal/compatible
     license. For now, this license is "Public Domain" until I think of a
     more suitable and agreeable one very soon.
     This allows me to possibly change the license of the whole project
     in the future without having to ask every single person for permission.
     Reasonable exceptions can be made.

How To Compile DIL
==================
In order to compile DIL you must have:

  * [DMD 2.061](http://dlang.org/changelog.html#new2_061)
  * [Tango D2](https://github.com/SiegeLord/Tango-D2/)
  * [Python 2.7.3](http://www.python.org/getit/releases/2.7.3/)
    (older versions might work, too.)

Newer versions of these tools may not compile DIL. The newest version of DMD
or Tango is not always used, because of regressions or unavoidable bugs.

Compile With Python
-----------------------
Note: The binary is placed in the bin/ folder.

Change to the root directory of DIL. E.g.:

    $ cd git/dil/

Print help.

    $ scripts/build.py -h

Compile a release binary.

    $ scripts/build.py

Compile a debug binary.

    $ scripts/build.py --debug

Pass additional parameters to the compiler like this:

    $ scripts/build.py -- -L-L/path/to/Tango/lib -L-ltango-dmd


On Windows you probably have to call python explicitly.

    > python scripts\build.py

Run like this:

  * On Linux:

        $ bin/dil

  * On Windows:

        > bin\dil.exe

Executing DIL without parameters will print the main help message.

The language of the compiler messages can be set in the configuration file.
Many messages are still untranslated. This task has low priority at the moment.

Bugs And Patches
================
Users can report problems with this software or submit patches by:

  * [filing a bug report on github](https://github.com/azizk/dil/issues),
  * contacting me at <aziz.koeksal@gmail.com>,
  * messaging me at [#dil](irc://freenode.net:8001/dil).
