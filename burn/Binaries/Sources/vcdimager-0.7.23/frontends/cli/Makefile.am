# $Id: Makefile.am,v 1.19 2004/02/12 01:57:23 rocky Exp $
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
bin_PROGRAMS = vcdimager cdxa2mpeg vcd-info

INCLUDES = -I$(top_srcdir) $(LIBPOPT_CFLAGS) $(LIBVCD_CFLAGS) $(LIBCDIO_CFLAGS) $(LIBISO9660_CFLAGS)

vcdimager_SOURCES = vcdimager.c
vcdimager_LDADD =  $(LIBISO9660_LIBS) $(LIBVCD_LIBS) $(LIBPOPT_LIBS) $(LIBCDIO_LIBS)

cdxa2mpeg_SOURCES = cdxa2mpeg.c
cdxa2mpeg_LDADD =  $(LIBISO9660_LIBS) $(LIBVCD_LIBS) $(LIBPOPT_LIBS)

vcd_info_SOURCES = vcd-info.c
vcd_info_LDADD = $(LIBISO9660_LIBS) $(LIBVCDINFO_LIBS) $(LIBVCD_LIBS) $(LIBPOPT_LIBS) $(LIBCDIO_LIBS) $(LIBISO9660_LIBS)

man_MANS = vcdimager.1 cdxa2mpeg.1 vcd-info.1

$(man_MANS): %.1: @MAINTAINER_MODE_TRUE@ %
	-$(HELP2MAN) --output=$@ ./$<

MAINTAINERCLEANFILES = $(man_MANS)

EXTRA_DIST = $(man_MANS)
