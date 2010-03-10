/*
    $Id: vcd_xml_dump.h,v 1.4 2005/05/07 19:53:21 rocky Exp $

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

#ifndef __VCD_XML_DUMP_H__
#define __VCD_XML_DUMP_H__

#include "vcdxml.h"

int vcd_xml_dump (vcdxml_t *obj, const char xml_fname[]);

/*!
   Print command line used as a XML comment. Start is either 0 or 
   1. The program might be invoked either from a binary or a libtool
   wrapper script to invoke the module.
*/
char *vcd_xml_dump_cl_comment (int argc, const char *argv[], int start);

#endif /* __VCD_XML_DUMP_H__ */
