/*
    $Id: vcd.h,v 1.5 2005/06/09 00:53:23 rocky Exp $

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

/* libvcd main header */

#ifndef __VCD_H__
#define __VCD_H__

/* Private headers */
#include "image_sink.h"
#include "mpeg_stream.h"
#include "stream.h"

#include <libvcd/types.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

  /** allocates and initializes a new VideoCD object */
  VcdObj_t *
  vcd_obj_new (vcd_type_t vcd_type);
  
  /** VideoCD parameters */
  typedef enum {
    VCD_PARM_INVALID = 0,
    VCD_PARM_VOLUME_ID,           /**< char *          max length 32  */
    VCD_PARM_PUBLISHER_ID,        /**< char *          max length 128 */
    VCD_PARM_PREPARER_ID,         /**< char *          max length 128 */
    VCD_PARM_ALBUM_ID,            /**< char *          max length 16  */
    VCD_PARM_VOLUME_COUNT,        /**< unsigned        [1..65535]     */
    VCD_PARM_VOLUME_NUMBER,       /**< unsigned        [0..65535]     */
    VCD_PARM_RESTRICTION,         /**< unsigned        [0..3]         */
    VCD_PARM_NEXT_VOL_LID2,       /**< bool */
    VCD_PARM_NEXT_VOL_SEQ2,       /**< bool */
    VCD_PARM_APPLICATION_ID,      /**< char *          max length 128 */
    VCD_PARM_SEC_TYPE,            /**< unsigned        [2336, 2352]   */
    VCD_PARM_SVCD_VCD3_MPEGAV,    /**< bool */
    VCD_PARM_SVCD_VCD3_ENTRYSVD,  /**< bool */
    VCD_PARM_SVCD_VCD3_TRACKSVD,  /**< bool */
    VCD_PARM_UPDATE_SCAN_OFFSETS, /**< bool */
    VCD_PARM_RELAXED_APS,         /**< bool */
    VCD_PARM_LEADOUT_PAUSE,       /**< bool */
    VCD_PARM_LEADOUT_PREGAP,      /**< unsigned        [0..300] */
    VCD_PARM_TRACK_PREGAP,        /**< unsigned        [1..300] */
    VCD_PARM_TRACK_FRONT_MARGIN,  /**< unsigned        [0..150] */
    VCD_PARM_TRACK_REAR_MARGIN    /**< unsigned        [0..150] */
  } vcd_parm_t;
  
  /** sets VideoCD parameter */
  int 
  vcd_obj_set_param_uint (VcdObj_t *p_vcdobj, vcd_parm_t param, unsigned arg);

  int 
  vcd_obj_set_param_str (VcdObj_t *p_vcdobj, vcd_parm_t param, 
                         const char *p_arg);
  
  int 
  vcd_obj_set_param_bool (VcdObj_t *p_vcdobj, vcd_parm_t param, bool arg);
  
  /** add custom files; if raw_flag set, the data source has to
      include a mode2 subheader, and thus needs to be a multiple of 2336
      byte blocksize */
  int
  vcd_obj_add_file (VcdObj_t *p_vcdobj, const char iso_pathname[],
                    VcdDataSource_t *p_file, bool raw_flag);
  
  int
  vcd_obj_add_dir (VcdObj_t *p_vcdobj, const char iso_pathname[]);
  
  /* this is for actually adding mpeg items to VCD, returns 
     a negative value for error..  */
  
  int 
  vcd_obj_append_sequence_play_item (VcdObj_t *p_vcdobj, 
                                     VcdMpegSource_t *p_mpeg_source, 
                                     const char item_id[], 
                                     const char default_entry_id[]);
  
  int 
  vcd_obj_add_sequence_entry (VcdObj_t *p_vcdobj, const char sequence_id[], 
                              double entry_time, const char entry_id[]);
  
  int 
  vcd_obj_add_sequence_pause (VcdObj_t *p_vcdobj, const char sequence_id[], 
                              double pause_timestamp, const char pause_id[]);
  
  int 
  vcd_obj_add_segment_pause (VcdObj_t *p_vcdobj, const char segment_id[], 
                             double pause_timestamp, const char pause_id[]);
  
  int 
  vcd_obj_append_segment_play_item (VcdObj_t *p_vcdobj, 
                                    VcdMpegSource_t *mpeg_source, 
                                    const char item_id[]);
  
  /** warning -- api will change for pbc */
  typedef struct _pbc_t pbc_t;
  
  int
  vcd_obj_append_pbc_node (VcdObj_t *p_vcdobj, struct _pbc_t *p_pbc);
  
  /** removes item (sequence, entry, segment, ...) by id, returns
     negative value on error */
  int 
  vcd_obj_remove_item (VcdObj_t *p_vcdobj, const char id[]);
  
  /** returns image size in sectors */
  long 
  vcd_obj_get_image_size (VcdObj_t *p_vcdobj);
  
  /** this one is to be called when every parameter has been set and the
      image is about to be written. returns sectors to be written... */
  long 
  vcd_obj_begin_output (VcdObj_t *p_vcdobj);
  
  /** callback hook called every few (>|<) iterations, if it returns a
      value != 0 the writing process gets aborted */
  typedef struct
  {
    long sectors_written;
    long total_sectors;
    int in_track;
    int total_tracks;
  }
  progress_info_t;
  
  typedef int (*progress_callback_t) (const progress_info_t *progress_info,
                                      void *user_data);
  
  /** writes the actual bin image file; a return value != 0 means the
      action was aborted by user or some other error has occured... */
  int
  vcd_obj_write_image (VcdObj_t *p_vcdobj, VcdImageSink_t *p_image_sink,
                       progress_callback_t callback, void *p_user_data,
                       const time_t *p_create_time);
  
  /** this should be called writing the bin and/or cue file is done---even if 
      an error occurred */
  void 
  vcd_obj_end_output (VcdObj_t *p_vcdobj);
  
  /** destructor for VideoCD objects; call this to destory a VideoCD
      object created by vcd_obj_new () */
  void 
  vcd_obj_destroy (VcdObj_t *p_vcdobj);
  
  const char *
  vcd_version_string (bool full_text);
  
#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __VCD_H__ */

/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
