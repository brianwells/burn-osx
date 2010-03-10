/*
    $Id: mpegscan.c,v 1.6 2005/05/08 09:04:03 rocky Exp $

    Copyright (C) 2001, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include <cdio/cdio.h>

/* Public headers */
#include <libvcd/types.h>

/* Private headers */
#include "mpeg_stream.h"
#include "stream_stdio.h"

int 
main (int argc, const char *argv[])
{
  VcdMpegSource_t *p_src;
  CdioListNode_t *p_n;
  double t = 0;

  if (argc != 2)
    return 1;

  p_src = vcd_mpeg_source_new (vcd_data_source_new_stdio (argv[1]));

  vcd_mpeg_source_scan (p_src, true, false, NULL, NULL);

  printf ("packets: %d\n", vcd_mpeg_source_get_info (p_src)->packets);

  _CDIO_LIST_FOREACH (p_n, vcd_mpeg_source_get_info (p_src)->shdr[0].aps_list)
    {
      struct aps_data *p_data = _cdio_list_node_data (p_n);
      
      printf ("aps: %u %f\n", (unsigned int) p_data->packet_no, 
	      p_data->timestamp);
    }

  {
    CdioListNode_t *aps_node = 
      _cdio_list_begin (vcd_mpeg_source_get_info (p_src)->shdr[0].aps_list);
    struct aps_data *p_data;
    double aps_time;
    int aps_packet;

    p_data = _cdio_list_node_data (aps_node);
    aps_time = p_data->timestamp;
    aps_packet = p_data->packet_no;


    for (t = 0; t <= vcd_mpeg_source_get_info (p_src)->playing_time; t += 0.5)
      {
        for(p_n = _cdio_list_node_next (aps_node); p_n; 
	    p_n = _cdio_list_node_next (p_n))
          {
            p_data = _cdio_list_node_data (p_n);

            if (fabs (p_data->timestamp - t) < fabs (aps_time - t))
              {
                aps_node = p_n;
                aps_time = p_data->timestamp;
                aps_packet = p_data->packet_no;
              }
            else 
              break;
          }

        printf ("%f %f %d\n", t, aps_time, aps_packet);
      }

  }

  {
    const struct vcd_mpeg_stream_info *p_info = 
      vcd_mpeg_source_get_info (p_src);
    printf ("mpeg info\n");
  
    printf (" %d x %d (%f:1) @%f v%d\n", p_info->shdr[0].hsize, 
	    p_info->shdr[0].vsize, p_info->shdr[0].aratio, 
	    p_info->shdr[0].frate, p_info->version);
  }

  vcd_mpeg_source_destroy (p_src, true);


  return 0;
}
