
# passing right flags to make distcheck when configuring nested packages
DISTCHECK_CONFIGURE_FLAGS=--enable-all-builds --with-rootdir

SUBDIRS=${MAYBE_GLIBC} libutils  ${MAYBE_FLAC} ${MAYBE_FIXWAV} libats2wav  ${MAYBE_SOX} src
DIST_SUBDIRS=libutils fixwav libFLAC libsoxconvert src CB_project glibc  libats2wav images
ACLOCAL_AMFLAGS=-I m4

# man page will be distributed under prefix/share/man/man1
dist_man_MANS=dvda-author.1
# normally /usr/share/applications/dvda-author
sysconfdir=${SHORTLINKDIR}
# distributed under $sysconfdir
dist_sysconf_DATA=dvda-author.desktop dvda-author.conf
# normally /usr/share/pixmaps/dvda-author
pixdir=${PIXDIR}
# distributed under $pixdir
dist_pix_DATA=dvda-author.png
# distributed under $docdir, normally $prefix/doc/dvda-author
dist_doc_DATA=README dvda-author-${VERSION}.html BUGS
 
# GNU build system regeneration script and others
EXTRA_DIST=autogen dvda-author.desktop.in dvda-author.ico dvda-author.nsi.in dvda-author.bat dvda-author.spec

