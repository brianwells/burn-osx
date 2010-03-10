## Process this file with automake to produce Makefile.in

ACLOCAL_AMFLAGS =-I m4

SUBDIRS = ${MAYBE_SOX} src 
DIST_SUBDIRS=lpc10 libgsm libsox src

if x${HAVE_PKGCONFIG} = xyes ; then;\
pkgconfigdir = @PKGCONFIGDIR@;\
pkgconfig_DATA = sox.pc;\
fi
