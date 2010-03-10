/*
    $Id: vcdxml.h,v 1.27 2005/05/08 13:05:44 rocky Exp $

    Copyright (C) 2001 Herbert Valerio Riedel <hvr@gnu.org>
    Copyright (C) 2005 Herbert Valerio Riedel <hvr@gnu.org>

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

#ifndef __VCDXML_H__
#define __VCDXML_H__

#include <string.h>

/* Public headers */
#include <libvcd/types.h>

/* Private headers */
#include "vcd_assert.h"
#include "data_structures.h"
#include "pbc.h"

typedef struct vcdxml_tag {
  char *comment; /* just a xml comment... */

  char *file_prefix;

  vcd_type_t vcd_type;
  CdioList_t *option_list;

  struct {
    char *album_id;
    unsigned volume_count;
    unsigned volume_number;
    unsigned restriction;
    bool use_sequence2;
    bool use_lid2;
    double time_offset;

    /* used for restoring vcd */
    unsigned psd_size;
    unsigned max_lid;
    unsigned segments_start;
  } info;

  struct {
    char *volume_id;
    char *system_id;
    char *application_id;
    char *preparer_id;
    char *publisher_id;
  } pvd;

  CdioList_t *pbc_list;

  CdioList_t *sequence_list;

  CdioList_t *segment_list;

  CdioList_t *filesystem;
} vcdxml_t;

#define OPT_LEADOUT_PREGAP          "leadout pregap"
#define OPT_LEADOUT_PAUSE           "leadout pause"
#define OPT_RELAXED_APS             "relaxed aps"
#define OPT_SVCD_VCD3_ENTRYSVD      "svcd vcd30 entrysvd"
#define OPT_SVCD_VCD3_MPEGAV        "svcd vcd30 mpegav"
#define OPT_SVCD_VCD3_TRACKSVD      "svcd vcd30 tracksvd"
#define OPT_TRACK_FRONT_MARGIN      "track front margin"
#define OPT_TRACK_PREGAP            "track pregap"
#define OPT_TRACK_REAR_MARGIN       "track rear margin"
#define OPT_UPDATE_SCAN_OFFSETS     "update scan offsets"

struct option_t {
  char *name;
  char *value;
};

struct sequence_t {
  char *id;
  char *src;

  char *default_entry_id;
  CdioList_t *entry_point_list; /* entry_point_t */
  CdioList_t *autopause_list; /* double * */

  /* used for restoring */
  uint32_t start_extent;
};

struct entry_point_t {
  char *id;
  double timestamp;
  
  /* used for restoring */
  uint32_t extent;
};

struct segment_t
{
  char *id;
  char *src;
  
  CdioList_t *autopause_list; /* double * */

  /* used for restoring vcds */
  unsigned segments_count;
};

struct filesystem_t
{
  char *name;
  char *file_src; /* if NULL then dir */
  bool file_raw;

  /* for ripping */
  uint32_t size;
  uint32_t lsn;
};

static inline void
vcd_xml_init (vcdxml_t *p_vcdxml)
{
  vcd_assert (p_vcdxml != NULL);

  memset (p_vcdxml, 0, sizeof (vcdxml_t));

  p_vcdxml->option_list = _cdio_list_new ();
  p_vcdxml->segment_list = _cdio_list_new ();
  p_vcdxml->filesystem = _cdio_list_new ();
  p_vcdxml->sequence_list = _cdio_list_new ();
  p_vcdxml->pbc_list = _cdio_list_new ();
}

static inline void
vcd_xml_destroy (vcdxml_t *p_vcdxml)
{
  CdioListNode_t *p_node;

  vcd_assert (p_vcdxml != NULL);

  _cdio_list_free (p_vcdxml->option_list,   true);
  _cdio_list_free (p_vcdxml->segment_list,  true);

  _CDIO_LIST_FOREACH (p_node, p_vcdxml->pbc_list)
    {
      pbc_t *p_pbc = _cdio_list_node_data(p_node);
      vcd_pbc_destroy(p_pbc);
    }
  
  _CDIO_LIST_FOREACH (p_node, p_vcdxml->sequence_list)
    {
      struct sequence_t *p_sequence = _cdio_list_node_data(p_node);
      CdioListNode_t *p_node2;
      free(p_sequence->src);
      free(p_sequence->id);
      free(p_sequence->default_entry_id);
      _CDIO_LIST_FOREACH (p_node2, p_sequence->entry_point_list)
	{
	  struct entry_point_t *p_entry = _cdio_list_node_data(p_node2);
	  free(p_entry->id);
	}
      _cdio_list_free (p_sequence->entry_point_list, true);
      _cdio_list_free (p_sequence->autopause_list, true);
    }
  
  _CDIO_LIST_FOREACH (p_node, p_vcdxml->filesystem)
    {
      struct filesystem_t *p_fs = _cdio_list_node_data(p_node);
      free(p_fs->name);
      free(p_fs->file_src);
    }

  _cdio_list_free (p_vcdxml->filesystem,    true);
  _cdio_list_free (p_vcdxml->pbc_list, true);
  _cdio_list_free (p_vcdxml->sequence_list, true);
  free (p_vcdxml->comment);
  free (p_vcdxml->info.album_id);
  free (p_vcdxml->pvd.volume_id);
  free (p_vcdxml->pvd.system_id);
  free (p_vcdxml->pvd.publisher_id);
  free (p_vcdxml->pvd.application_id);
  free (p_vcdxml->pvd.preparer_id);
}

#endif /* __VCDXML_H__ */
