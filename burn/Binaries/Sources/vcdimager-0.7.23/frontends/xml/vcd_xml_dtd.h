/*
    $Id: vcd_xml_dtd.h,v 1.2 2003/03/04 14:49:39 hvr Exp $

    Copyright (C) 2001 Herbert Valerio Riedel <hvr@gnu.org>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#ifndef __VCD_XML_DTD_H__
#define __VCD_XML_DTD_H__

#define VIDEOCD_DTD_PUBID "-//GNU//DTD VideoCD//EN"
#define VIDEOCD_DTD_SYSID "http://www.gnu.org/software/vcdimager/videocd.dtd"
#define VIDEOCD_DTD_XMLNS "http://www.gnu.org/software/vcdimager/1.0/"

extern const char videocd_dtd[];

extern int vcd_xml_dtd_loaded;

void vcd_xml_dtd_init (void);

#endif /* __VCD_XML_DTD_H__ */
