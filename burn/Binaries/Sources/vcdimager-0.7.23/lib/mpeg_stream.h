/*
    $Id: mpeg_stream.h,v 1.4 2005/06/07 23:29:23 rocky Exp $

    Copyright (C) 2000, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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

#ifndef __VCD_MPEG_STREAM__
#define __VCD_MPEG_STREAM__

#include <libvcd/types.h>

/* Private includes */
#include "stream.h"
#include "data_structures.h"
#include "mpeg.h"

#define MPEG_PACKET_SIZE 2324

typedef struct _VcdMpegSource VcdMpegSource_t;

/* used in APS list */

struct aps_data
{
  uint32_t packet_no;
  double timestamp;
};

/* enums */

typedef enum {
  MPEG_AUDIO_NOSTREAM = 0,
  MPEG_AUDIO_1STREAM = 1,
  MPEG_AUDIO_2STREAM = 2,
  MPEG_AUDIO_EXT_STREAM = 3
} mpeg_audio_t;

typedef enum {
  MPEG_VIDEO_NOSTREAM = 0,
  MPEG_VIDEO_NTSC_STILL = 1,
  MPEG_VIDEO_NTSC_STILL2 = 2,
  MPEG_VIDEO_NTSC_MOTION = 3,

  MPEG_VIDEO_PAL_STILL = 5,
  MPEG_VIDEO_PAL_STILL2 = 6,
  MPEG_VIDEO_PAL_MOTION = 7
} mpeg_video_t;

/* mpeg stream info */

struct vcd_mpeg_stream_info;

/* mpeg packet info */

struct vcd_mpeg_packet_info;

/* access functions */

VcdMpegSource_t *
vcd_mpeg_source_new (VcdDataSource_t *mpeg_file);

/* scan the mpeg file... needed to be called only once */
typedef struct {
  long current_pack;
  long current_pos;
  long length;
} vcd_mpeg_prog_info_t;

typedef int (*vcd_mpeg_prog_cb_t) (const vcd_mpeg_prog_info_t *progress_info,
                                   void *user_data);

void
vcd_mpeg_source_scan (VcdMpegSource_t *obj, bool strict_aps, 
                      bool fix_scan_info, vcd_mpeg_prog_cb_t callback, 
                      void *user_data);

/* gets the packet at given position */
int
vcd_mpeg_source_get_packet (VcdMpegSource_t *obj, unsigned long packet_no,
			    void *packet_buf, 
                            struct vcd_mpeg_packet_info *flags,
                            bool fix_scan_info);

void
vcd_mpeg_source_close (VcdMpegSource_t *obj);

const struct vcd_mpeg_stream_info *
vcd_mpeg_source_get_info (VcdMpegSource_t *obj);

long
vcd_mpeg_source_stat (VcdMpegSource_t *obj);

void
vcd_mpeg_source_destroy (VcdMpegSource_t *obj, bool destroy_file_obj);

#endif /* __VCD_MPEG_STREAM__ */

/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
