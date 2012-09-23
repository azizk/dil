DIL
===
Copyright (c) 2007-2012 by Aziz Köksal <aziz.koeksal@gmail.com>
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

How To Compile DIL
==================
In order to compile DIL you must have:

 * [DMD 2.059](http://dlang.org/changelog.html#new2_059)
 * [Tango D2](https://github.com/SiegeLord/Tango-D2)
 * [Python 2.7.3](http://www.python.org/getit/releases/2.7.3/)
   (older versions might work, too.)

If you can't compile DIL because you have newer versions of these programs,
please, report the problem to me (see Bugs section.)

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

    $ scripts/build.py -- -unittest


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

 * contacting me at <aziz.koeksal@gmail.com>
 * [filing a bug report on github](https://github.com/azizk/dil/issues)
