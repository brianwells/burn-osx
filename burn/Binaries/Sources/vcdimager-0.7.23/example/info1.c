/*
    $Id: info1.c,v 1.2 2005/04/29 03:42:19 rocky Exp $

    Copyright (C) 2005 Rocky Bernstein <rocky@panix.com>

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
/* Simple example of using the libvcdinfo library. */


#include <stdio.h>
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif
#ifdef HAVE_STRING_H
# include <string.h>
#endif
#ifdef HAVE_STDLIB_H
# include <stdlib.h>
#endif

#include <libvcd/info.h>
#include <libvcd/logging.h>
#include <cdio/iso9660.h>

int
main (int argc, const char *argv[])
{
  vcdinfo_obj_t *p_vcdinfo;
  char *psz_source = NULL;
  char *psz = NULL;

  /* Set to give only errors on open, not warnings. */
  vcd_loglevel_default = VCD_LOG_ERROR; 

  if ( vcdinfo_open(&p_vcdinfo, &psz_source, DRIVER_DEVICE,
                    NULL) != VCDINFO_OPEN_VCD) {
    printf("Unable to find a CD-ROM with a (S)VCD in it\n");
    return 1;
  }
  vcd_loglevel_default = VCD_LOG_WARN;

  /* Print out some of the VCD info. */
  printf ("VCD type: `%.16s'\n",    vcdinfo_get_format_version_str(p_vcdinfo));
  printf ("Album id: `%.16s'\n",    vcdinfo_get_album_id(p_vcdinfo));
  printf ("Volume id: `%s'\n",      vcdinfo_get_volume_id(p_vcdinfo));
  printf ("Volume Set id: `%s'\n",  vcdinfo_get_volumeset_id(p_vcdinfo));
  printf ("Volume %d of %d\n",      vcdinfo_get_volume_num(p_vcdinfo),
	                            vcdinfo_get_volume_count(p_vcdinfo));

  psz = vcdinfo_get_preparer_id(p_vcdinfo);
  printf ("Preparer id: `%s'\n",    psz);
  free(psz);
  
  psz = vcdinfo_get_publisher_id(p_vcdinfo);
  printf ("Publisher id: `%s'\n",  psz);
  free(psz);

  psz = vcdinfo_get_system_id(p_vcdinfo);
  printf ("System id: `%s'\n",      psz);
  free(psz);

  psz = vcdinfo_get_application_id(p_vcdinfo);
  printf ("Application id: `%s'\n", psz);
  free(psz);
  
  { 
    const iso9660_pvd_t *p_pvd = vcdinfo_get_pvd(p_vcdinfo);

    if (iso9660_get_pvd_type(p_pvd) != ISO_VD_PRIMARY)
      printf ("Unexpected descriptor type\n");
    
    if (strncmp (iso9660_get_pvd_id(p_pvd), ISO_STANDARD_ID, 
		 strlen (ISO_STANDARD_ID)))
      printf ("Unexpected ID encountered (expected `" ISO_STANDARD_ID "'");
  
    printf("PVD ID: `%.5s'\n",  iso9660_get_pvd_id(p_pvd));
    printf("PVD version: %d\n", iso9660_get_pvd_version(p_pvd));
  }

  free(psz_source);
  vcdinfo_close(p_vcdinfo);
  return 0;
}
