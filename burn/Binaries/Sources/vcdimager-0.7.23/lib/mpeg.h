/*
    $Id: mpeg.h,v 1.3 2004/10/10 20:20:19 rocky Exp $

    Copyright (C) 2000 Herbert Valerio Riedel <hvr@gnu.org>

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

#ifndef __VCD_MPEG_H__
#define __VCD_MPEG_H__

#include <string.h>

/* Public headers */
#include <libvcd/logging.h>
#include <libvcd/types.h>

/* Private headers */
#include "data_structures.h"

typedef enum {
  MPEG_VERS_INVALID = 0,
  MPEG_VERS_MPEG1 = 1,
  MPEG_VERS_MPEG2 = 2
} mpeg_vers_t;

PRAGMA_BEGIN_PACKED
struct vcd_mpeg_scan_data_t {
  uint8_t tag;
  uint8_t len;
  msf_t prev_ofs;
  msf_t next_ofs;
  msf_t back_ofs;
  msf_t forw_ofs;
} GNUC_PACKED;
PRAGMA_END_PACKED

#define struct_vcd_mpeg_scan_data_t_SIZEOF 14

#define VCD_MPEG_SCAN_DATA_WARNS 8

typedef struct {
  struct vcd_mpeg_packet_info {
    bool video[3];
    bool audio[3];
    bool ogt[4];

    bool padding;
    bool pem;
    bool zero;
    bool system_header;

    struct vcd_mpeg_scan_data_t *scan_data_ptr; /* points into actual packet memory! */

    enum aps_t {
      APS_NONE = 0,
      APS_I,    /* iframe */
      APS_GI,   /* gop + iframe */
      APS_SGI,  /* sequence + gop + iframe */
      APS_ASGI  /* aligned sequence + gop + iframe */
    } aps;
    double aps_pts;
    int aps_idx;

    bool has_pts;
    double pts;

    uint64_t scr;
    unsigned muxrate;

    bool gop;
    struct {
      uint8_t h, m, s, f;
    } gop_timecode;
  } packet;

  struct vcd_mpeg_stream_info {
    unsigned packets;

    mpeg_vers_t version;

    bool ogt[4];

    struct vcd_mpeg_stream_vid_info {
      bool seen;
      unsigned hsize;
      unsigned vsize;
      double aratio;
      double frate;
      unsigned bitrate;
      unsigned vbvsize;
      bool constrained_flag;

      CdioList *aps_list; /* filled up by vcd_mpeg_source */
      double last_aps_pts; /* temp, see ->packet */
      
    } shdr[3];

    struct vcd_mpeg_stream_aud_info {
      bool seen;
      unsigned layer;
      unsigned bitrate;
      unsigned sampfreq;
      enum {
        MPEG_STEREO = 1,
        MPEG_JOINT_STEREO,
        MPEG_DUAL_CHANNEL,
        MPEG_SINGLE_CHANNEL
      } mode;
    } ahdr[3];

    unsigned muxrate;

    bool seen_pts;
    double min_pts;
    double max_pts;

    double playing_time;

    unsigned scan_data;
    unsigned scan_data_warnings;
  } stream;
} VcdMpegStreamCtx;

int
vcd_mpeg_parse_packet (const void *buf, unsigned buflen, bool parse_pes,
                       VcdMpegStreamCtx *ctx);

typedef enum {
  MPEG_NORM_OTHER,
  MPEG_NORM_PAL,
  MPEG_NORM_NTSC,
  MPEG_NORM_FILM,
  MPEG_NORM_PAL_S,
  MPEG_NORM_NTSC_S
} mpeg_norm_t;

mpeg_norm_t 
vcd_mpeg_get_norm (const struct vcd_mpeg_stream_vid_info *_info);

enum vcd_mpeg_packet_type {
  PKT_TYPE_INVALID = 0,
  PKT_TYPE_VIDEO,
  PKT_TYPE_AUDIO,
  PKT_TYPE_OGT,
  PKT_TYPE_ZERO,
  PKT_TYPE_EMPTY
};

enum vcd_mpeg_packet_type
vcd_mpeg_packet_get_type (const struct vcd_mpeg_packet_info *_info);

struct vcd_mpeg_stream_vid_type {
  enum {
    VID_TYPE_NONE = 0,
    VID_TYPE_MOTION,
    VID_TYPE_STILL
  } type;
  enum {
    VID_NORM_OTHER = 0,
    VID_NORM_PAL,
    VID_NORM_NTSC
  } norm;
  enum {
    VID_RES_OTHER = 0,
    VID_RES_SIF,
    VID_RES_HALF_D1,
    VID_RES_2_3_D1,
    VID_RES_FULL_D2
  } resolution;
};

#endif /* __VCD_MPEG_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
