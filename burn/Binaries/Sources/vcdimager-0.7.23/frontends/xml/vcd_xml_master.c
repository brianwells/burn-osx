/*
    $Id: vcd_xml_master.c,v 1.38 2005/06/09 00:53:23 rocky Exp $

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

/* Private headers */
#include "image_sink.h"
#include "stream_stdio.h"
#include "vcd.h"

#include "vcd_xml_master.h"
#include "vcd_xml_common.h"

/* Public headers */
#include <cdio/bytesex.h>
#include <libvcd/logging.h>

#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#include <stdio.h>

static const char _rcsid[] = "$Id: vcd_xml_master.c,v 1.38 2005/06/09 00:53:23 rocky Exp $";

/* important date to celebrate (for me at least =)
   -- until user customization is implemented... */
static const time_t _vcd_time = 269222400L;

static VcdDataSource_t *
mk_dsource (const char prefix[], const char pathname[])
{
  vcd_assert (pathname != 0);

  if (prefix) 
    {
      VcdDataSource_t *retval = 0;
      char *tmp = calloc(1, strlen (prefix) + strlen (pathname) + 1);
      strcpy (tmp, prefix);
      strcat (tmp, pathname);
      retval = vcd_data_source_new_stdio (tmp);
      free (tmp);
      return retval;
    }

  return vcd_data_source_new_stdio (pathname);
}

bool 
vcd_xml_master (const vcdxml_t *p_vcdxml, VcdImageSink_t *p_image_sink, 
		time_t *create_time)
{
  VcdObj_t *_vcd;
  CdioListNode_t *node;
  int idx;
  bool _relaxed_aps = false;
  bool _update_scan_offsets = false;

  vcd_assert (p_vcdxml != NULL);

  _vcd = vcd_obj_new (p_vcdxml->vcd_type);

  if (vcd_xml_check_mode)
    vcd_obj_set_param_str (_vcd, VCD_PARM_PREPARER_ID, 
			   "GNU VCDIMAGER CHECK MODE");

  if (p_vcdxml->info.album_id)
    vcd_obj_set_param_str (_vcd, VCD_PARM_ALBUM_ID, p_vcdxml->info.album_id);

  vcd_obj_set_param_uint (_vcd, VCD_PARM_VOLUME_NUMBER, 
			  p_vcdxml->info.volume_number);
  vcd_obj_set_param_uint (_vcd, VCD_PARM_VOLUME_COUNT, 
			  p_vcdxml->info.volume_count);
  vcd_obj_set_param_uint (_vcd, VCD_PARM_RESTRICTION, 
			  p_vcdxml->info.restriction);
  vcd_obj_set_param_bool (_vcd, VCD_PARM_NEXT_VOL_SEQ2, 
			  p_vcdxml->info.use_sequence2);
  vcd_obj_set_param_bool (_vcd, VCD_PARM_NEXT_VOL_LID2, 
			  p_vcdxml->info.use_lid2);

  if (p_vcdxml->pvd.volume_id)
    vcd_obj_set_param_str (_vcd, VCD_PARM_VOLUME_ID, 
			   p_vcdxml->pvd.volume_id);

  if (p_vcdxml->pvd.publisher_id)
    vcd_obj_set_param_str (_vcd, VCD_PARM_PUBLISHER_ID, 
			   p_vcdxml->pvd.publisher_id);

  if (p_vcdxml->pvd.application_id)
    vcd_obj_set_param_str (_vcd, VCD_PARM_APPLICATION_ID, 
			   p_vcdxml->pvd.application_id);

  _CDIO_LIST_FOREACH (node, p_vcdxml->option_list)
    {
      const struct option_t *_option = _cdio_list_node_data (node);

      struct {
	const char *str;
	enum {
	  OPT_BOOL = 1,
	  OPT_UINT,
	  OPT_STR
	} val_type;
	vcd_parm_t parm_id;
      } const _opt_cfg[] = {
	{ OPT_SVCD_VCD3_MPEGAV, OPT_BOOL, VCD_PARM_SVCD_VCD3_MPEGAV },
	{ OPT_SVCD_VCD3_ENTRYSVD, OPT_BOOL, VCD_PARM_SVCD_VCD3_ENTRYSVD },
	{ OPT_SVCD_VCD3_TRACKSVD, OPT_BOOL, VCD_PARM_SVCD_VCD3_TRACKSVD },
	{ OPT_RELAXED_APS, OPT_BOOL, VCD_PARM_RELAXED_APS },
	{ OPT_UPDATE_SCAN_OFFSETS, OPT_BOOL, VCD_PARM_UPDATE_SCAN_OFFSETS },
	{ OPT_LEADOUT_PAUSE, OPT_BOOL, VCD_PARM_LEADOUT_PAUSE },

	{ OPT_LEADOUT_PREGAP, OPT_UINT, VCD_PARM_LEADOUT_PREGAP },
	{ OPT_TRACK_PREGAP, OPT_UINT, VCD_PARM_TRACK_PREGAP },
	{ OPT_TRACK_FRONT_MARGIN, OPT_UINT, VCD_PARM_TRACK_FRONT_MARGIN },
	{ OPT_TRACK_REAR_MARGIN, OPT_UINT, VCD_PARM_TRACK_REAR_MARGIN },
	{ 0, }
      }, *_opt_cfg_p = _opt_cfg;

      if (!_option->name)
	{
	  vcd_error ("no option name given!");
	  continue;
	}

      if (!_option->value)
	{
	  vcd_error ("no value given for option name '%s'", _option->name);
	  continue;
	}

      for (; _opt_cfg_p->str; _opt_cfg_p++)
	if (!strcmp (_opt_cfg_p->str, _option->name))
	  break;

      if (!_opt_cfg_p->str)
	{
	  vcd_error ("unknown option name '%s'", _option->name);
	  continue;
	}

      switch (_opt_cfg_p->val_type) 
	{
	case OPT_BOOL:
	  {
	    bool _value;
	    if (!strcmp (_option->value, "true"))
	      _value = true;
	    else if (!strcmp (_option->value, "false"))
	      _value = false;
	    else
	      {
		vcd_error ("option value '%s' invalid (use 'true' or 'false')",
			   _option->value);
		continue;
	      }

	    vcd_obj_set_param_bool (_vcd, _opt_cfg_p->parm_id, _value);

	    if (_opt_cfg_p->parm_id == VCD_PARM_UPDATE_SCAN_OFFSETS)
	      _update_scan_offsets = _value;
	    if (_opt_cfg_p->parm_id == VCD_PARM_RELAXED_APS)
	      _relaxed_aps = _value;
	  }
	  break;

	case OPT_UINT:
	  {
	    unsigned _value;
	    char *endptr;

	    _value = strtol (_option->value, &endptr, 10);
	    
	    if (*endptr)
	      {
		vcd_error ("error while converting string '%s' to integer", 
			   _option->value);
		_value = 0;
	      }
	   
	    vcd_obj_set_param_uint (_vcd, _opt_cfg_p->parm_id, _value);
	  }
	  break;

	case OPT_STR:
	  vcd_assert_not_reached ();
	  break;
	}
    }  

  _CDIO_LIST_FOREACH (node, p_vcdxml->pbc_list)
    {
      pbc_t *_pbc = _cdio_list_node_data (node);

      vcd_debug ("adding pbc (%s/%d)", _pbc->id, _pbc->type);

      vcd_obj_append_pbc_node (_vcd, _pbc);
    }

  _CDIO_LIST_FOREACH (node, p_vcdxml->filesystem)
    {
      struct filesystem_t *dentry = _cdio_list_node_data (node);
      
      if (dentry->file_src) 
	{
	  VcdDataSource_t *_source = mk_dsource (p_vcdxml->file_prefix, 
					       dentry->file_src);
	  
	  vcd_assert (_source != NULL);

	  vcd_obj_add_file (_vcd, dentry->name, _source, dentry->file_raw);
	}
      else
	vcd_obj_add_dir (_vcd, dentry->name);
      
    }

  idx = 0;
  _CDIO_LIST_FOREACH (node, p_vcdxml->segment_list)
    {
      struct segment_t *p_segment = _cdio_list_node_data (node);
      VcdDataSource_t *_source = mk_dsource (p_vcdxml->file_prefix, 
					   p_segment->src);
      CdioListNode_t *p_node2;
      VcdMpegSource_t *_mpeg_src;

      vcd_debug ("adding segment #%d, %s", idx, p_segment->src);

      vcd_assert (_source != NULL);

      _mpeg_src = vcd_mpeg_source_new (_source);

      vcd_mpeg_source_scan (_mpeg_src, !_relaxed_aps, _update_scan_offsets,
			    vcd_xml_show_progress 
			    ? vcd_xml_scan_progress_cb : NULL,
			    p_segment->id);

      vcd_obj_append_segment_play_item (_vcd, _mpeg_src, p_segment->id);
      
      _CDIO_LIST_FOREACH (p_node2, p_segment->autopause_list)
	{
	  double *_ap_ts = _cdio_list_node_data (p_node2);

	  vcd_obj_add_segment_pause (_vcd, p_segment->id, *_ap_ts, NULL);
	}

      idx++;
    }

  vcd_debug ("sequence count %d", _cdio_list_length (p_vcdxml->sequence_list));
  
  idx = 0;
  _CDIO_LIST_FOREACH (node, p_vcdxml->sequence_list)
    {
      struct sequence_t *sequence = _cdio_list_node_data (node);
      VcdDataSource_t *data_source;
      CdioListNode_t *node2;
      VcdMpegSource_t *_mpeg_src;

      vcd_debug ("adding sequence #%d, %s", idx, sequence->src);

      data_source = mk_dsource (p_vcdxml->file_prefix, sequence->src);
      vcd_assert (data_source != NULL);

      _mpeg_src = vcd_mpeg_source_new (data_source);

      vcd_mpeg_source_scan (_mpeg_src, !_relaxed_aps, _update_scan_offsets,
			    (vcd_xml_show_progress)
			    ? vcd_xml_scan_progress_cb : NULL,
			    sequence->id);

      vcd_obj_append_sequence_play_item (_vcd, _mpeg_src, sequence->id, 
					 sequence->default_entry_id);

      _CDIO_LIST_FOREACH (node2, sequence->entry_point_list)
	{
	  struct entry_point_t *entry = _cdio_list_node_data (node2);

	  vcd_obj_add_sequence_entry (_vcd, sequence->id, entry->timestamp, 
				      entry->id);
	}

      _CDIO_LIST_FOREACH (node2, sequence->autopause_list)
	{
	  double *_ap_ts = _cdio_list_node_data (node2);

	  vcd_obj_add_sequence_pause (_vcd, sequence->id, *_ap_ts, NULL);
	}
    }

  /****************************************************************************
   *
   */

  {
    unsigned sectors;
    char *_tmp;

    sectors = vcd_obj_begin_output (_vcd);

    vcd_obj_write_image (_vcd, p_image_sink, vcd_xml_show_progress 
			 ? vcd_xml_write_progress_cb : NULL, 
			 NULL, &_vcd_time);

    vcd_obj_end_output (_vcd);

    vcd_info ("finished ok, image created with %d sectors [%s]",
	      sectors, _tmp = cdio_lba_to_msf_str (sectors));

    free (_tmp);
  }

  vcd_obj_destroy (_vcd);

  return false;
}


