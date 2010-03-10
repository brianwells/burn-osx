# $Id: Makefile.am,v 1.19 2005/07/10 12:20:03 rocky Exp $
#   $Id: Makefile.am,v 1.19 2005/07/10 12:20:03 rocky Exp $
#
#    Copyright (C) 2004, 2005 Rocky Bernstein <rocky@panix.com>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
####################################################
# Things to make the libvcd and libvcdinfo librares
####################################################

# From libtool documentation amended with guidance from N. Boullis: 
#
#  1. Start with version information of `0:0:0' for each libtool library.
#
#  2. It is probably not a good idea to update the version information 
#     several times between public releases, but rather once per public
#     release. (This seems to be more an aesthetic consideration than
#     a hard technical one.)
#
#  3. If the library source code has changed at all since the last
#     update, then increment REVISION (`C:R:A' becomes `C:R+1:A').
#
#  4. If any interfaces have been added, removed, or changed since the
#     last update, increment CURRENT, and set REVISION to 0.
#
#  5. If any interfaces have been added since the last public release,
#     then increment AGE.
#
#  6. If any interfaces have been removed or changed since the last
#     public release, then set AGE to 0. A changed interface means an
#     incompatibility with previous versions.

libvcdinfo_la_CURRENT := 2
libvcdinfo_la_REVISION := 0
libvcdinfo_la_AGE := 2

noinst_LTLIBRARIES = libvcd.la
lib_LTLIBRARIES = libvcdinfo.la

INCLUDES = $(LIBVCD_CFLAGS) $(LIBCDIO_CFLAGS)

libvcd_la_LIBADD = $(LIBCDIO_LIBS) $(LIBISO9660_LIBS)
libvcd_la_SOURCES = \
	vcd_assert.h \
	bitvec.h \
	data_structures.h \
	dict.h \
	directory.h \
	image_sink.h \
	mpeg.h \
	mpeg_stream.h \
	obj.h \
	pbc.h \
	salloc.h \
	sector_private.h \
	stream.h \
	stream_stdio.h \
	util.h \
	vcd.h \
	vcd.c \
	data_structures.c \
	directory.c \
	files.c \
	image.c \
	image_bincue.c \
	image_cdrdao.c \
	image_nrg.c \
	logging.c \
	mpeg.c \
	mpeg_stream.c \
	pbc.c \
	salloc.c \
	sector.c \
	stream.c \
	stream_stdio.c \
	util.c 

libvcdinfo_la_SOURCES = \
	info.c \
	inf.c \
	info_private.h \
	info_private.c \
	vcd_read.c \
	vcd_read.h 

libvcdinfo_la_LIBADD = $(LIBCDIO_LIBS) $(LIBISO9660_LIBS) $(LIBVCD_LIBS)
libvcdinfo_la_LDFLAGS = -version-info $(libvcdinfo_la_CURRENT):$(libvcdinfo_la_REVISION):$(libvcdinfo_la_AGE)
libvcdinfo_la_DEPENDENCIES = libvcd.la

# Below is some simple versioning where every symbol is versioned with
# something that looks like the SONAME of the library. More complex (and
# better) versioning is possible; it is for example what is used by glibc.
# But good complex versioning is something that requires much more
# work...


# The below is a impliments symbol versioning.  First of all, I
# compute MAJOR as CURENT - AGE; that is what is used within libtool
# (at least on GNU/Linux systems) for the number in the SONAME.  The
# nm command gives the list of symbols known in each of the object
# files that will be part of the shared library. And the sed command
# extracts from this list those symbols that will be shared. (This sed
# command comes from libtool.)

libvcdinfo_la_MAJOR := $(shell expr $(libvcdinfo_la_CURRENT) - $(libvcdinfo_la_AGE))

if BUILD_VERSIONED_LIBS
libvcdinfo_la_DEPENDENCIES += libvcdinfo.la.ver
libvcdinfo_la_LDFLAGS += -Wl,--version-script=libvcdinfo.la.ver

libvcdinfo.la.ver: $(libvcdinfo_la_OBJECTS)
	echo 'VCDINFO_$(libvcdinfo_la_MAJOR) {' > $@
	echo "  global:" >> $@
	objs=`for obj in $(libvcdinfo_la_OBJECTS); do sed -ne "s/^pic_object='\(.*\)'$$/\1/p" $$obj; done`; \
	nm $${objs} | sed -n -e 's/^.*[ 	][ABCDGIRSTW][ABCDGIRSTW]*[ 	][ 	]*\([_A-Za-z][_A-Za-z0-9]*\)$$/    \1;/p' | sort | uniq >> $@
	echo '};' >> $@

MOSTLYCLEANFILES = libvcdinfo.la.ver

endif


# EOF
