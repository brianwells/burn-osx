/*
    $Id: mpeg_stream.c,v 1.8 2005/06/07 23:29:23 rocky Exp $

    Copyright (C) 2000, 2004, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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
#include <stdio.h>
#include <stdlib.h>

#include <cdio/cdio.h>
#include <cdio/bytesex.h>
#include <cdio/util.h>

#include <libvcd/logging.h>

/* Private headers */
#include "vcd_assert.h"
#include "mpeg_stream.h"
#include "data_structures.h"
#include "mpeg.h"
#include "util.h"

static const char _rcsid[] = "$Id: mpeg_stream.c,v 1.8 2005/06/07 23:29:23 rocky Exp $";

struct _VcdMpegSource
{
  VcdDataSource_t *data_source;

  bool scanned;
  
  /* _get_packet cache */
  unsigned _read_pkt_pos;
  unsigned _read_pkt_no;

  struct vcd_mpeg_stream_info info;
};

/*
 * access functions
 */

VcdMpegSource_t *
vcd_mpeg_source_new (VcdDataSource_t *mpeg_file)
{
  VcdMpegSource_t *new_obj;
  
  vcd_assert (mpeg_file != NULL);

  new_obj = calloc(1, sizeof (VcdMpegSource_t));

  new_obj->data_source = mpeg_file;
  new_obj->scanned = false;

  return new_obj;
}

void
vcd_mpeg_source_destroy (VcdMpegSource_t *obj, bool destroy_file_obj)
{
  int i;
  vcd_assert (obj != NULL);

  if (destroy_file_obj)
    vcd_data_source_destroy (obj->data_source);

  for (i = 0; i < 3; i++)
    if (obj->info.shdr[i].aps_list)
      _cdio_list_free (obj->info.shdr[i].aps_list, true);

  free (obj);
}

const struct vcd_mpeg_stream_info *
vcd_mpeg_source_get_info (VcdMpegSource_t *obj)
{
  vcd_assert (obj != NULL);

  vcd_assert (obj->scanned);

  return &(obj->info);
}

long
vcd_mpeg_source_stat (VcdMpegSource_t *obj)
{
  vcd_assert (obj != NULL);
  vcd_assert (!obj->scanned);
  
  return obj->info.packets * 2324;
}

void
vcd_mpeg_source_scan (VcdMpegSource_t *obj, bool strict_aps, bool fix_scan_info,
                      vcd_mpeg_prog_cb_t callback, void *user_data)
{
  unsigned length = 0;
  unsigned pos = 0;
  unsigned pno = 0;
  unsigned padbytes = 0;
  unsigned padpackets = 0;
  VcdMpegStreamCtx state;
  CdioListNode_t *n;
  vcd_mpeg_prog_info_t _progress = { 0, };

  vcd_assert (obj != NULL);

  if (obj->scanned)
    {
      vcd_debug ("already scanned... not rescanning");
      return;
    }

  vcd_assert (!obj->scanned);

  memset (&state, 0, sizeof (state));
  
  if (fix_scan_info)
    state.stream.scan_data_warnings = VCD_MPEG_SCAN_DATA_WARNS + 1;

  vcd_data_source_seek (obj->data_source, 0);
  length = vcd_data_source_stat (obj->data_source);

  if (callback)
    {
      _progress.length = length;
      callback (&_progress, user_data);
    }


  while (pos < length)
    {
      char buf[2324] = { 0, };
      int read_len = MIN (sizeof (buf), (length - pos));
      int pkt_len;

      read_len = vcd_data_source_read (obj->data_source, buf, read_len, 1);

      pkt_len = vcd_mpeg_parse_packet (buf, read_len, true, &state);

      if (!pkt_len)
        {
          if (!pno)
            vcd_error ("input mpeg stream has been deemed invalid -- aborting");

          vcd_warn ("bad packet at packet #%d (stream byte offset %d)"
                    " -- remaining %d bytes of stream will be ignored",
                    pno, pos, length - pos);

          pos = length; /* don't fall into assert... */
          break;
        }

      if (callback && (pos - _progress.current_pos) > (length / 100))
        {
          _progress.current_pos = pos;
          _progress.current_pack = pno;
          callback (&_progress, user_data);
        }

      switch (state.packet.aps)
        {
        case APS_NONE:
          break;

        case APS_I:
        case APS_GI:
          if (strict_aps)
            break; /* allow only if now strict aps */

        case APS_SGI:
        case APS_ASGI:
          {
            struct aps_data *_data = calloc(1, sizeof (struct aps_data));
            
            _data->packet_no = pno;
            _data->timestamp = state.packet.aps_pts;

            if (!state.stream.shdr[state.packet.aps_idx].aps_list)
              state.stream.shdr[state.packet.aps_idx].aps_list = 
                _cdio_list_new ();
            
            _cdio_list_append (state.stream.shdr[state.packet.aps_idx].aps_list, _data);
          }
          break;

        default:
          vcd_assert_not_reached ();
          break;
        }

      pos += pkt_len;
      pno++;

      if (pkt_len != read_len)
        {
          padbytes += (2324 - pkt_len);

          if (!padpackets)
            vcd_warn ("mpeg stream will be padded on the fly -- hope that's ok for you!");

          padpackets++;

          vcd_data_source_seek (obj->data_source, pos);
        }
    }

  vcd_data_source_close (obj->data_source);

  if (callback)
    {
      _progress.current_pos = pos;
      _progress.current_pack = pno;
      callback (&_progress, user_data);
    }

  vcd_assert (pos == length);

  obj->info = state.stream;
  obj->scanned = true;

  obj->info.playing_time = obj->info.max_pts - obj->info.min_pts;

  if (obj->info.min_pts)
    vcd_debug ("pts start offset %f (max pts = %f)", 
               obj->info.min_pts, obj->info.max_pts);

  vcd_debug ("playing time %f", obj->info.playing_time);

  if (!state.stream.scan_data && state.stream.version == MPEG_VERS_MPEG2)
    vcd_warn ("mpeg stream contained no scan information (user) data");

  {
    int i;

    for (i = 0; i < 3; i++)
      if (obj->info.shdr[i].aps_list)
        _CDIO_LIST_FOREACH (n, obj->info.shdr[i].aps_list)
        {
          struct aps_data *_data = _cdio_list_node_data (n);
          
          _data->timestamp -= obj->info.min_pts; 
        }
  }

  if (padpackets)
    vcd_warn ("autopadding requires to insert additional %d zero bytes"
              " into MPEG stream (due to %d unaligned packets of %d total)",
              padbytes, padpackets, state.stream.packets);

  obj->info.version = state.stream.version;
}

static double
_approx_pts (CdioList *aps_list, uint32_t packet_no)
{
  double retval = 0;
  CdioListNode_t *node;

  struct aps_data *_laps = NULL;

  double last_pts_ratio = 0;

  _CDIO_LIST_FOREACH (node, aps_list)
    {
      struct aps_data *_aps = _cdio_list_node_data (node);

      if (_laps)
        {
          long p = _aps->packet_no;
          double t = _aps->timestamp;

          p -= _laps->packet_no;
          t -= _laps->timestamp;

          last_pts_ratio = t / p;
        }

      if (_aps->packet_no >= packet_no)
        break;
      
      _laps = _aps;
    }

  retval = packet_no;
  retval -= _laps->packet_no;
  retval *= last_pts_ratio;
  retval += _laps->timestamp;

  return retval;
}

static void 
_set_scan_msf (msf_t *_msf, long lsn)
{
  if (lsn == -1)
    {
      _msf->m = _msf->s = _msf->f = 0xff;
      return;
    }

  cdio_lba_to_msf (lsn, _msf);
  _msf->s |= 0x80;
  _msf->f |= 0x80;
}

static void 
_fix_scan_info (struct vcd_mpeg_scan_data_t *scan_data_ptr,
                unsigned packet_no, double pts, CdioList *aps_list)
{
  CdioListNode_t *node;
  long _next = -1, _prev = -1, _forw = -1, _back = -1;

  _CDIO_LIST_FOREACH (node, aps_list)
    {
      struct aps_data *_aps = _cdio_list_node_data (node);

      if (_aps->packet_no == packet_no)
        continue;
      else if (_aps->packet_no < packet_no)
        {
          _prev = _aps->packet_no;
          
          if (pts - _aps->timestamp < 10 && _back == -1)
            _back = _aps->packet_no;
        }
      else if (_aps->packet_no > packet_no)
        {
          if (_next == -1)
            _next = _aps->packet_no;

          if (_aps->timestamp - pts < 10)
            _forw = _aps->packet_no;
        }
    }

  if (_back == -1)
    _back = packet_no;

  if (_forw == -1)
    _forw = packet_no;

  _set_scan_msf (&scan_data_ptr->prev_ofs, _prev);
  _set_scan_msf (&scan_data_ptr->next_ofs, _next);
  _set_scan_msf (&scan_data_ptr->back_ofs, _back);
  _set_scan_msf (&scan_data_ptr->forw_ofs, _forw);
}

int
vcd_mpeg_source_get_packet (VcdMpegSource_t *obj, unsigned long packet_no,
			    void *packet_buf, 
                            struct vcd_mpeg_packet_info *flags,
                            bool fix_scan_info)
{
  unsigned length;
  unsigned pos;
  unsigned pno;
  VcdMpegStreamCtx state;

  vcd_assert (obj != NULL);
  vcd_assert (obj->scanned);
  vcd_assert (packet_buf != NULL);

  if (packet_no >= obj->info.packets)
    {
      vcd_error ("invalid argument");
      return -1;
    }

  if (packet_no < obj->_read_pkt_no)
    {
      vcd_warn ("rewinding mpeg stream...");
      obj->_read_pkt_no = 0;
      obj->_read_pkt_pos = 0;
    }

  memset (&state, 0, sizeof (state));
  state.stream.seen_pts = true;
  state.stream.min_pts = obj->info.min_pts;
  state.stream.scan_data_warnings = VCD_MPEG_SCAN_DATA_WARNS + 1;

  pos = obj->_read_pkt_pos;
  pno = obj->_read_pkt_no;
  length = vcd_data_source_stat (obj->data_source);

  vcd_data_source_seek (obj->data_source, pos);

  while (pos < length)
    {
      char buf[2324] = { 0, };
      int read_len = MIN (sizeof (buf), (length - pos));
      int pkt_len;
      
      vcd_data_source_read (obj->data_source, buf, read_len, 1);

      pkt_len = vcd_mpeg_parse_packet (buf, read_len,
                                       fix_scan_info, &state);

      vcd_assert (pkt_len > 0);

      if (pno == packet_no)
	{
          /* optimized for sequential access, 
             thus save pointer to next mpeg pack */
	  obj->_read_pkt_pos = pos + pkt_len;
	  obj->_read_pkt_no = pno + 1;

          if (fix_scan_info
              && state.packet.scan_data_ptr
              && obj->info.version == MPEG_VERS_MPEG2)
            {
              int vid_idx = 0;
              double _pts;

              if (state.packet.video[2])
                vid_idx = 2;
              else if (state.packet.video[1])
                vid_idx = 1;
              else 
                vid_idx = 0;

              if (state.packet.has_pts)
                _pts = state.packet.pts - obj->info.min_pts;
              else
                _pts = _approx_pts (obj->info.shdr[vid_idx].aps_list, 
                                    packet_no);

              _fix_scan_info (state.packet.scan_data_ptr, packet_no, 
                              _pts, obj->info.shdr[vid_idx].aps_list);
            }

	  memset (packet_buf, 0, 2324);
	  memcpy (packet_buf, buf, pkt_len);

          if (flags)
            {
              *flags = state.packet;
              flags->pts -= obj->info.min_pts;
            }

	  return 0; /* breaking out */
	}

      pos += pkt_len;
      pno++;

      if (pkt_len != read_len)
	vcd_data_source_seek (obj->data_source, pos);
    }

  vcd_assert (pos == length);

  vcd_error ("shouldn't be reached...");

  return -1;
}

void
vcd_mpeg_source_close (VcdMpegSource_t *p_vcdmpegsource)
{
  vcd_assert (p_vcdmpegsource != NULL);

  vcd_data_source_close (p_vcdmpegsource->data_source);
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
