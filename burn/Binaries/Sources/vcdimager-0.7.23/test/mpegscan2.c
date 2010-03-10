/*
    $Id: mpegscan2.c,v 1.4 2005/05/08 03:48:55 rocky Exp $

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
#include <cdio/bytesex.h>

/* Private haeaders */
#include "mpeg.h"
#include "mpeg_stream.h"
#include "stream_stdio.h"

static inline
void _dump_msf (const msf_t *__msf)
{
  msf_t _msf = *__msf;

  if (_msf.m != 0xff)
    {
      _msf.s &= 0x7f;
      _msf.f &= 0x7f;
    }
	  
  printf (" %.2x:%.2x.%.2x ", 
	  _msf.m, _msf.s, _msf.f);
}

int 
main (int argc, const char *argv[])
{
  VcdMpegSource_t *src;
  unsigned packets, packet_no;
  VcdMpegStreamCtx ctx;

  if (argc != 2)
    return 1;

  src = vcd_mpeg_source_new (vcd_data_source_new_stdio (argv[1]));

  vcd_mpeg_source_scan (src, true, true,  NULL, NULL);

  packets = vcd_mpeg_source_get_info (src)->packets;

  printf ("packets: %d\n", packets);

  memset (&ctx, 0, sizeof (ctx));

  ctx.stream.scan_data_warnings = VCD_MPEG_SCAN_DATA_WARNS + 1;

  printf ("cur_ofs  (lba) aps prev_ofs  next_ofs  back_ofs  forw_ofs\n");

  for (packet_no = 0; packet_no < packets; packet_no++)
    {
      /* struct vcd_mpeg_packet_flags pkt_flags; */
      char buf[2324];

      vcd_mpeg_source_get_packet (src, packet_no,
				  buf, /* &pkt_flags */ NULL, false);

      vcd_mpeg_parse_packet (&buf, 2324, true, &ctx);

      if (ctx.packet.scan_data_ptr)
	{
	  struct vcd_mpeg_scan_data_t *sd = ctx.packet.scan_data_ptr;
	  msf_t _msf;

	  cdio_lba_to_msf (packet_no, &_msf);

	  printf ("%.2x:%.2x.%.2x (%4d) %d ",
		  _msf.m, _msf.s, _msf.f,
		  packet_no, ctx.packet.aps);

	  _dump_msf (&sd->prev_ofs);
	  _dump_msf (&sd->next_ofs);

	  _dump_msf (&sd->back_ofs);
	  _dump_msf (&sd->forw_ofs);

	  printf ("\n");
	}
    }

  {
    const struct vcd_mpeg_stream_info *_info = vcd_mpeg_source_get_info (src);
    printf ("mpeg info\n");
  
    printf (" %d x %d (%f:1) @%f v%d\n", _info->shdr[0].hsize, _info->shdr[0].vsize,
	    _info->shdr[0].aratio, _info->shdr[0].frate, _info->version);
  }

  vcd_mpeg_source_destroy (src, true);

  return 0;
}
