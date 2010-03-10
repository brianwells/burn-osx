/*
    $Id: vcd_xml_dtd.c,v 1.7 2003/11/10 11:57:48 rocky Exp $

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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <string.h>
#include <stdlib.h>

#include <libxml/parser.h>
#include <libxml/tree.h>

/* Public headers */
#include <libvcd/logging.h>

/* Public headers */
#include "vcd_assert.h"

#include "vcd_xml_dtd.h"
#include "videocd_dtd.inc"

static const char _rcsid[] = "$Id: vcd_xml_dtd.c,v 1.7 2003/11/10 11:57:48 rocky Exp $";

int vcd_xml_dtd_loaded = -1; /* extern */

static xmlExternalEntityLoader _xmlExternalEntityLoaderDefault = 0;

static xmlParserInputPtr 
_xmlExternalEntityLoader (const char *sysid, const char *pubid, 
			  xmlParserCtxtPtr context)
{
  vcd_assert (vcd_xml_dtd_loaded >= 0);

  vcd_debug ("EEL sysid=[%s] pubid=[%s]", 
	     sysid ? sysid : "NULL", pubid ? pubid : "NULL");

  if ((pubid && !strcmp (pubid, VIDEOCD_DTD_PUBID))
      || (sysid && !strcmp (sysid, VIDEOCD_DTD_SYSID)))
    {
      xmlParserInputBufferPtr _input_buf;

      _input_buf = xmlParserInputBufferCreateMem (videocd_dtd, 
						  strlen (videocd_dtd),
						  XML_CHAR_ENCODING_8859_1);
      
      vcd_xml_dtd_loaded++;

      return xmlNewIOInputStream (context, _input_buf, 
				  XML_CHAR_ENCODING_8859_1);
    }
  
  /*   fprintf (stderr, "unsupported doctype (pubid: %s, sysid: %s) encountered\n", */
  /* 	   pubid, sysid); */
  
  /* exit (EXIT_FAILURE); */

  return _xmlExternalEntityLoaderDefault (sysid, pubid, context); 
}

void 
vcd_xml_dtd_init (void)
{
  vcd_assert (vcd_xml_dtd_loaded == -1);
  
  _xmlExternalEntityLoaderDefault = xmlGetExternalEntityLoader (); 
  xmlSetExternalEntityLoader (_xmlExternalEntityLoader);

  vcd_xml_dtd_loaded++;
}
