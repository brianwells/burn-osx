# $Id: Makefile.am,v 1.31 2005/04/28 10:19:47 rocky Exp $
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

SUBDIRS = include lib frontends test amiga docs example

# pkg-config(1) related rules
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libvcdinfo.pc 

EXTRA_DIST = BUGS FAQ cygwin-dist.sh HACKING libpopt.m4 \
	ChangeLog_pre0_5 ChangeLog_pre0_7_14 \
	debian/changelog debian/control debian/copyright debian/docs debian/info debian/rules debian/watch $(wildcard debian/*.install)

dist-hook: vcdimager.spec
	cp vcdimager.spec $(distdir)

snapshot:
	$(MAKE) dist distdir=$(PACKAGE)-$(VERSION)-`date +"%Y%m%d"`

bintar-dist:
	here=`pwd`; \
	ipath="$$here/install-tmp/"; \
	rm -rf "$$ipath"; \
	$(MAKE) install-strip prefix="$$ipath/usr/local/"; \
	$(AMTAR) -C "$$ipath" -cvzf $(PACKAGE)-$(VERSION)-$(host_triplet).tar.gz usr

if CYGWIN
cygwin-dist:
	./cygwin-dist.sh $(VERSION)
endif

# cvs2cl
MAINTAINERCLEANFILES = ChangeLog

if MAINTAINER_MODE

.PHONY: ChangeLog
ChangeLog:
	$(CVS2CL) -W 450 --header $(srcdir)/cvs2cl_header --utc -w -I ChangeLog --usermap $(srcdir)/cvs2cl_usermap -P 

ACLOCAL_AMFLAGS=-I .

endif
