/*
    $Id: obj.h,v 1.8 2005/06/09 00:53:23 rocky Exp $

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

#ifndef __VCD_OBJ_H__
#define __VCD_OBJ_H__

#include <cdio/iso9660.h>
#include <libvcd/files.h>

/* Private headers */
#include "data_structures.h"
#include "directory.h"
#include "image_sink.h"
#include "mpeg_stream.h"
#include "salloc.h"
#include "vcd.h"

typedef struct {
  double time;
  struct aps_data aps;
  char *id;
} entry_t;

typedef struct {
  double time;
  char *id;
} pause_t;

typedef struct {
  VcdMpegSource_t *source;
  char *id;
  const struct vcd_mpeg_stream_info *info;

  CdioList_t *pause_list; /* pause_t */

  char *default_entry_id;
  CdioList_t *entry_list; /* entry_t */

  /* pbc ref check */
  bool referenced;

  /* computed on sector allocation */
  unsigned relative_start_extent; /* relative to iso data end */
} mpeg_sequence_t;

/* work in progress -- fixme rename all occurences */
#define mpeg_track_t mpeg_sequence_t
#define mpeg_track_list mpeg_sequence_list 

typedef struct {
  VcdMpegSource_t *source;
  char *id;
  const struct vcd_mpeg_stream_info *info;

  CdioList_t *pause_list; /* pause_t */

  /* pbc ref check */
  bool referenced;

  /* computed through info */
  unsigned segment_count;

  /* computed on sector allocation */
  unsigned start_extent;
} mpeg_segment_t;


typedef struct {
  char *iso_pathname;
  VcdDataSource_t *file;
  bool raw_flag;
  
  uint32_t size;
  uint32_t start_extent;
  uint32_t sectors;
} custom_file_t;

struct _VcdObj {
  vcd_type_t type;

  /* VCD 3.0 chinese SVCD compat flags */
  bool svcd_vcd3_mpegav;
  bool svcd_vcd3_entrysvd;
  bool svcd_vcd3_tracksvd;
  bool svcd_vcd3_spiconsv;

  bool update_scan_offsets;
  bool relaxed_aps;

  unsigned leadout_pregap;
  unsigned track_pregap;
  unsigned track_front_margin;
  unsigned track_rear_margin;

  /* output */
  VcdImageSink_t *image_sink;

  /* ... */
  unsigned iso_size;
  char *iso_volume_label;
  char *iso_publisher_id;
  char *iso_application_id;
  char *iso_preparer_id;

  char *info_album_id;
  unsigned info_volume_count;
  unsigned info_volume_number;
  unsigned info_restriction;
  bool info_use_seq2;
  bool info_use_lid2;

  /* input */
  unsigned mpeg_segment_start_extent;
  CdioList_t *mpeg_segment_list; /* mpeg_segment_t */

  CdioList_t *mpeg_sequence_list; /* mpeg_sequence_t */

  unsigned relative_end_extent; /* last mpeg sequence track end extent */

  /* PBC */
  CdioList_t *pbc_list; /* pbc_t */
  unsigned psd_size;
  unsigned psdx_size;

  /* custom files */
  unsigned ext_file_start_extent; 
  unsigned custom_file_start_extent; 
  CdioList_t *custom_file_list; /* custom_file_t */
  CdioList_t *custom_dir_list; /* char */

  /* dictionary */
  CdioList_t *buffer_dict_list;

  /* aggregates */
  VcdSalloc *iso_bitmap;

  VcdDirectory_t *dir;

  /* state info */
  bool in_output;

  unsigned sectors_written;
  unsigned in_track;

  long last_cb_call;

  progress_callback_t progress_callback;
  void *callback_user_data;
};

/* private functions */

mpeg_sequence_t *
_vcd_obj_get_sequence_by_id (VcdObj_t *obj, const char sequence_id[]);

mpeg_sequence_t *
_vcd_obj_get_sequence_by_entry_id (VcdObj_t *obj, const char entry_id[]);

mpeg_segment_t *
_vcd_obj_get_segment_by_id (VcdObj_t *obj, const char segment_id[]);

enum vcd_capability_t {
  _CAP_VALID,
  _CAP_MPEG1,
  _CAP_MPEG2,
  _CAP_PBC,
  _CAP_PBC_X,
  _CAP_TRACK_MARGINS,
  _CAP_4C_SVCD,
  _CAP_PAL_BITS
};

bool
_vcd_obj_has_cap_p (const VcdObj_t *obj, enum vcd_capability_t capability);

#endif /* __VCD_OBJ_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
