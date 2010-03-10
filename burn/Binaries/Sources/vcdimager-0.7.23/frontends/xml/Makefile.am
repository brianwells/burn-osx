# $Id: Makefile.am,v 1.32 2004/08/15 12:16:49 rocky Exp $
#
# Copyright (C) 2003 Herbert Valerio Riedel <hvr@gnu.org>
# Copyright (C) 2003 Rocky Bernstein <rocky@panix.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

bin_PROGRAMS = vcdxbuild vcdxgen vcdxrip vcdxminfo

man_MANS = vcdxbuild.1 vcdxgen.1 vcdxrip.1 vcdxminfo.1

$(man_MANS): %.1: @MAINTAINER_MODE_TRUE@ %
	-$(HELP2MAN) --output=$@ ./$<

MAINTAINERCLEANFILES = $(man_MANS)

INCLUDES = -I$(top_srcdir) $(LIBPOPT_CFLAGS) $(LIBVCD_CFLAGS) $(XML_CFLAGS) $(LIBCDIO_CFLAGS) $(LIBISO9660_CFLAGS) $(XML_CPPFLAGS)

BUILT_SOURCES = videocd_dtd.inc
MOSTLYCLEANFILES = videocd_dtd.inc

EXTRA_DIST = videocd.dtd $(man_MANS)

Makefile: $(BUILT_SOURCES)

vcdxbuild_LDADD = $(XML_LIBS) $(LIBVCD_LIBS) $(LIBPOPT_LIBS) $(LIBCDIO_LIBS) $(LIBISO9660_LIBS)

vcdxbuild_SOURCES = \
	vcdxml.h \
	vcd_xml_build.c \
	vcd_xml_common.c \
	vcd_xml_common.h \
	vcd_xml_dtd.c \
	vcd_xml_dtd.h \
	vcd_xml_master.c \
	vcd_xml_master.h \
	vcd_xml_parse.c \
	vcd_xml_parse.h 

vcdxrip_LDADD = $(XML_LIBS) $(LIBISO9660_LIBS) $(LIBVCDINFO_LIBS) $(LIBVCD_LIBS) $(LIBPOPT_LIBS) $(LIBCDIO_LIBS)
vcdxrip_SOURCES = \
	vcd_xml_rip.c \
	vcd_xml_common.c \
	vcd_xml_common.h \
	vcd_xml_dump.h \
	vcd_xml_dump.c \
	vcd_xml_dtd.h 

vcdxgen_LDADD = $(XML_LIBS) $(LIBPOPT_LIBS) $(LIBVCD_LIBS) $(LIBCDIO_LIBS) $(LIBISO9660_LIBS)
vcdxgen_SOURCES = \
	vcd_xml_gen.c \
	vcd_xml_common.c \
	vcd_xml_common.h \
	vcd_xml_dump.h \
	vcd_xml_dump.c \
	vcd_xml_dtd.h 

vcdxminfo_LDADD = $(XML_LIBS) $(LIBPOPT_LIBS) $(LIBVCD_LIBS) $(LIBCDIO_LIBS) $(LIBISO9660_LIBS)
vcdxminfo_SOURCES = \
	vcd_xml_common.c \
	vcd_xml_common.h \
	vcd_xml_minfo.c

#vcd_xml_dtd.c: videocd_dtd.inc

videocd_dtd.inc: $(srcdir)/videocd.dtd
	(sed 's/\"/\\"/g' | $(AWK) 'BEGIN { print "const char videocd_dtd[] = \\" } { print " \"" $$0 "\\n\" \\" } END { print ";" }') < $(srcdir)/videocd.dtd > videocd_dtd.inc

