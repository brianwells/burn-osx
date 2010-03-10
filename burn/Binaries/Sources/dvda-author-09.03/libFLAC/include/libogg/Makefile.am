## Process this file with automake to produce Makefile.in
AUTOMAKE_OPTIONS=foreign
ACLOCAL_AM_FLAGS=-I m4

SUBDIRS = src include  win32
DIST_SUBDIRS=src include  win32

m4datadir = $(datadir)/aclocal
m4data_DATA = ogg.m4

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = ogg.pc


## for distribution purposes, it is necessary to exceptionally include configure and config.h.in
## configure.ac and aclocal.m4 are added as true extra. This make it possible to package with make dist(check).

EXTRA_DIST = README AUTHORS CHANGES COPYING configure.ac aclocal.m4 configure config.h.in\
	ogg.m4 ogg.pc.in ogg-uninstalled.pc.in \
	macos macosx

dist-hook:
	rm -rf `find $(distdir)/macos -name .svn`
	rm -rf `find $(distdir)/macosx -name .svn`


