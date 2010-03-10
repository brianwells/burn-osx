#!/bin/sh
#
# $Id: cygwin-dist.sh,v 1.10 2002/01/04 02:50:05 hvr Exp $
# cygwin-dist.sh script, by hvr
#

if [ ! -f /bin/cygwin1.dll ]
 then
   echo "this script must be run from a cygwin environment"
   exit 1
 fi

if [ ! -f /bin/cygz.dll ]
 then
   echo "where is cygz.dll, missing?"
   exit 2
 fi

if [ ! -f /usr/bin/cygxml2-2.dll ]
 then
   echo "no cygxml2-2.dll ?!?"
   exit 2
 fi

if [ -z "$1" ]
 then
   echo "no version given"
   exit 1
 fi

if [ ! -f configure.in ]
 then
   echo "wrong dir"
   exit 1
 fi

EXECUTABLES="frontends/cli/vcdimager.exe frontends/cli/vcddebug.exe frontends/cli/cdxa2mpeg.exe frontends/xml/vcdxgen.exe frontends/xml/vcdxbuild.exe frontends/xml/vcdxrip.exe frontends/xml/vcdxminfo.exe"

for E in $EXECUTABLES
do if [ ! -f "$E" ]
 then
   echo "executable not found"
   exit 2
 fi
done

VERSION="$1"
TMPDIR="cygwin-$VERSION-tmp"
DISTZIP="vcdimager-$VERSION.win32.zip"

rm -rf $TMPDIR
mkdir $TMPDIR

for DOCFILE in BUGS TODO README NEWS ChangeLog THANKS AUTHORS COPYING FAQ
 do
   cp $DOCFILE $TMPDIR/$DOCFILE.txt
 done

(cd docs/; makeinfo --no-headers -o ../$TMPDIR/manual.txt vcdimager.texi)

unix2dos $TMPDIR/*.txt

if [ -f vcdimager.pdf ]; then
  cp -v vcdimager.pdf $TMPDIR/manual.pdf
fi

cp -v $EXECUTABLES frontends/xml/videocd.dtd /bin/cygwin1.dll /bin/cygz.dll /usr/bin/cygxml2-2.dll $TMPDIR/
strip -v $TMPDIR/*.exe

rm -fv "$DISTZIP"
zip -9v "$DISTZIP" -j $TMPDIR/*

rm -rf $TMPDIR

exit 0
