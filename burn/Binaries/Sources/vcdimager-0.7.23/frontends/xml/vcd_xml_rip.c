/*
    $Id: vcd_xml_rip.c,v 1.71 2005/06/14 16:19:22 rocky Exp $

    Copyright (C) 2001, 2003, 2004, 2005 Herbert Valerio Riedel <hvr@gnu.org>
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

/* Private headers */
#include "vcd_read.h"
#include "vcdxml.h"
#include "vcd_xml_dtd.h"
#include "vcd_xml_dump.h"
#include "vcd_xml_common.h"


/* FIXME: Make this really private: */
#include <libvcd/files_private.h>

/* Public headers */

#include <cdio/bytesex.h>
#include <cdio/cd_types.h>
#include <cdio/iso9660.h>
#include <cdio/logging.h>

#include <libvcd/sector.h>
#include <libvcd/files.h>
#include <libvcd/info.h>

#if defined ( WIN32 )
#define ftruncate chsize
#endif

#include <stdio.h>
#include <errno.h>
#include <ctype.h>
#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <popt.h>

static const char _rcsid[] = "$Id: vcd_xml_rip.c,v 1.71 2005/06/14 16:19:22 rocky Exp $";

static int _verbose_flag = 0;
static int _quiet_flag = 0;

static void
_register_file (vcdxml_t *p_vcdxml, const char *pathname,
		iso9660_stat_t const *statbuf)
{
  uint16_t xa_attr = uint16_from_be (statbuf->xa.attributes);

  while (*pathname == '/')
    pathname++;

  switch (statbuf->type)
    {
    case _STAT_DIR:
	{
	  struct filesystem_t *p_fs 
	    = calloc(1, sizeof (struct filesystem_t));
	  _cdio_list_append (p_vcdxml->filesystem, p_fs);
	  
	  p_fs->name = strdup (pathname);
	}
      break;

    case _STAT_FILE:
      {
	char *namebuf = strdup (pathname);
	struct filesystem_t *p_fs = calloc(1, sizeof (struct filesystem_t));
	_cdio_list_append (p_vcdxml->filesystem, p_fs);

	if (strrchr (namebuf, ';'))
	  *strrchr (namebuf, ';') = '\0';

	p_fs->name = namebuf;

	{
	  char namebuf2[strlen (namebuf) + 2];
	  int i;
		
	  namebuf2[0] = '_';

	  for (i = 0; namebuf[i]; i++)
	    namebuf2[i + 1] = (namebuf[i] == '/') ? '_' : tolower (namebuf[i]);

	  namebuf2[i + 1] = '\0';

	  p_fs->file_src = strdup (namebuf2);
	}

	p_fs->lsn = statbuf->lsn;
	p_fs->size = statbuf->size;
	p_fs->file_raw = (xa_attr & XA_ATTR_MODE2FORM2) != 0;

	vcd_debug ("file %s", namebuf);

	if (p_fs->file_raw)
	  {
	    if (p_fs->size % ISO_BLOCKSIZE == 0)
	      { 
		p_fs->size /= ISO_BLOCKSIZE;
		p_fs->size *= M2RAW_SECTOR_SIZE;
	      }
	    else if (p_fs->size % M2RAW_SECTOR_SIZE == 0)
	      vcd_warn ("detected wrong size calculation for form2 file `%s'; fixing up", namebuf);
	    else 
	      vcd_error ("form2 file has invalid file size");
	  }
      }
      break;
      
    default:
      vcd_assert_not_reached ();
      break;
    }
}

static int
_parse_isofs_r (vcdxml_t *p_vcdxml, CdIo_t *p_cdio, 
		const char pathname[])
{ 
  CdioList_t *entlist = iso9660_fs_readdir (p_cdio, pathname, true);
  CdioListNode_t *entnode;

  if (entlist == NULL)
    return -1;

  _CDIO_LIST_FOREACH (entnode, entlist)
    {
      iso9660_stat_t *statbuf = _cdio_list_node_data (entnode);
      char _fullname[4096] = { 0, };
      char *_name = statbuf->filename;

      strncpy (_fullname, pathname, sizeof (_fullname));
      strncat (_fullname, _name, sizeof (_fullname));

      if (NULL == statbuf)
	return -1;
      
      if (!strcmp (_name, ".") 
	  || !strcmp (_name, "..")
	  || !strcmp (_name, "MPEGAV")
	  || !strcmp (_name, "MPEG2")
	  || !strcmp (_name, "VCD")
	  || !strcmp (_name, "SVCD")
	  || !strcmp (_name, "SEGMENT")
	  || !strcmp (_name, "EXT")
	  || !strcmp (_name, "CDDA"))
	continue;

      _register_file (p_vcdxml, _fullname, statbuf);

      if (statbuf->type == _STAT_DIR) {
	strncat (_fullname, "/", sizeof (_fullname));
	if (_parse_isofs_r (p_vcdxml, p_cdio, _fullname)) {
	  return -1;
	}
      }
    }

  _cdio_list_free (entlist, true);

  return 0;
}

static int
_parse_isofs (vcdxml_t *p_vcdxml, CdIo_t *p_cdio)
{
  return _parse_isofs_r (p_vcdxml, p_cdio, "/");
}

static int
_parse_pvd (vcdxml_t *p_vcdxml, CdIo_t *p_cdio)
{
  iso9660_pvd_t pvd;

  memset (&pvd, 0, sizeof (iso9660_pvd_t));
  vcd_assert (sizeof (iso9660_pvd_t) == ISO_BLOCKSIZE);

  if (!iso9660_fs_read_pvd(p_cdio, &pvd)) {
    return -1;
  }

  p_vcdxml->pvd.volume_id      = iso9660_get_volume_id(&pvd);
  p_vcdxml->pvd.system_id      = iso9660_get_system_id(&pvd);
  p_vcdxml->pvd.publisher_id   = iso9660_get_publisher_id(&pvd);
  p_vcdxml->pvd.preparer_id    = iso9660_get_preparer_id(&pvd);
  p_vcdxml->pvd.application_id = iso9660_get_application_id(&pvd);

  return 0;
}

static int
_parse_info (vcdxml_t *p_vcdxml, CdIo_t *p_cdio)
{
  InfoVcd_t info;

  memset (&info, 0, sizeof (InfoVcd_t));
  vcd_assert (sizeof (InfoVcd_t) == ISO_BLOCKSIZE);

  if (!read_info(p_cdio, &info, &(p_vcdxml->vcd_type)))
    return -1;

  if (p_vcdxml->vcd_type == VCD_TYPE_INVALID)
    return -1;

  p_vcdxml->info.album_id      = strdup (vcdinf_get_album_id(&info));
  p_vcdxml->info.volume_count  = vcdinf_get_volume_count(&info);
  p_vcdxml->info.volume_number = vcdinf_get_volume_num(&info);

  p_vcdxml->info.restriction = info.flags.restriction;
  p_vcdxml->info.use_lid2 = info.flags.use_lid2;
  p_vcdxml->info.use_sequence2 = info.flags.use_track3;

  p_vcdxml->info.psd_size = vcdinf_get_psd_size(&info);
  p_vcdxml->info.max_lid = vcdinf_get_num_LIDs(&info);

  {
    lba_t segment_start;
    segnum_t max_seg_num;
    int idx, n;
    struct segment_t *_segment = NULL;

    segment_start = cdio_msf_to_lba (&info.first_seg_addr);

    max_seg_num = vcdinf_get_num_segments(&info);

    if (segment_start < CDIO_PREGAP_SECTORS)
      return 0;

    segment_start = cdio_lba_to_lsn(segment_start);

    vcd_assert (segment_start % CDIO_CD_FRAMES_PER_SEC == 0);

    p_vcdxml->info.segments_start = segment_start;

    if (!max_seg_num)
      return 0;

    n = 0;
    for (idx = 0; idx < max_seg_num; idx++)
      {
	if (!info.spi_contents[idx].item_cont)
	  { /* new segment */
	    char buf[80];
	    _segment = calloc(1, sizeof (struct segment_t));

	    snprintf (buf, sizeof (buf), "segment-%4.4d", idx);
	    _segment->id = strdup (buf);

	    snprintf (buf, sizeof (buf), "item%4.4d.mpg", idx + 1);
	    _segment->src = strdup (buf);

	    _segment->autopause_list = _cdio_list_new ();

	    _cdio_list_append (p_vcdxml->segment_list, _segment);
	    n++;
	  }

	vcd_assert (_segment != NULL);

	_segment->segments_count++;
      }
  }

  return 0;
}

static int
_parse_entries (vcdxml_t *p_vcdxml, CdIo_t *p_cdio)
{
  EntriesVcd_t entries;
  int idx;
  track_t ltrack;

  memset (&entries, 0, sizeof (EntriesVcd_t));
  vcd_assert (sizeof (EntriesVcd_t) == ISO_BLOCKSIZE);

  if (!read_entries(p_cdio, &entries)) {
    return -1;
  }

  ltrack = 0;
  for (idx = 0; idx < vcdinf_get_num_entries(&entries); idx++)
    {
      lba_t extent = vcdinf_get_entry_lba(&entries, idx);
      track_t track = vcdinf_get_track(&entries, idx);
      bool newtrack = (track != ltrack);
      ltrack = track;
      
      vcd_assert (extent >= CDIO_PREGAP_SECTORS);
      extent = cdio_lba_to_lsn(extent);

      vcd_assert (track >= 2);
      track -= 2;

      if (newtrack)
	{
	  char buf[80];
	  struct sequence_t *p_new_sequence;

	  p_new_sequence = calloc(1, sizeof (struct sequence_t));

	  snprintf (buf, sizeof (buf), "sequence-%2.2d", track);
	  p_new_sequence->id = strdup (buf);

	  snprintf (buf, sizeof (buf), "avseq%2.2d.mpg", track + 1);
	  p_new_sequence->src = strdup (buf);

	  p_new_sequence->entry_point_list = _cdio_list_new ();
	  p_new_sequence->autopause_list = _cdio_list_new ();
	  p_new_sequence->start_extent = extent;

	  snprintf (buf, sizeof (buf), "entry-%3.3d", idx);
	  p_new_sequence->default_entry_id = strdup (buf);
	  
	  _cdio_list_append (p_vcdxml->sequence_list, p_new_sequence);
	}
      else
	{
	  char buf[80];
	  struct sequence_t *p_seq =
	    _cdio_list_node_data (_cdio_list_end (p_vcdxml->sequence_list));

	  struct entry_point_t *p_entry = 
	    calloc(1, sizeof (struct entry_point_t));

	  snprintf (buf, sizeof (buf), "entry-%3.3d", idx);
	  p_entry->id = strdup (buf);

	  p_entry->extent = extent;

	  _cdio_list_append (p_seq->entry_point_list, p_entry);
	}

      /* vcd_debug ("%d %d %d %d", idx, track, extent, newtrack); */
    }

  return 0;
}

static char *
_xstrdup(const char *s)
{
  if (s)
    return strdup (s);
  
  return NULL;
}

typedef struct _pbc_ctx {
  unsigned psd_size;
  unsigned maximum_lid;
  unsigned offset_mult;
  CdioList_t *offset_list;

  uint8_t *psd;
  LotVcd_t *lot;
  bool extended;
} pbc_ctx_t ;

static const char *
_pin2id (unsigned pin)
{
  static char buf[80];
  vcdinfo_itemid_t itemid;
  
  vcdinfo_classify_itemid (pin, &itemid);

  switch(itemid.type) {
  case VCDINFO_ITEM_TYPE_NOTFOUND:
    return NULL;
  case VCDINFO_ITEM_TYPE_TRACK:
    snprintf (buf, sizeof (buf), "sequence-%2.2d", itemid.num-1);
    break;
  case VCDINFO_ITEM_TYPE_ENTRY:
    snprintf (buf, sizeof (buf), "entry-%3.3d", itemid.num);
    break;
  case VCDINFO_ITEM_TYPE_SEGMENT:
    snprintf (buf, sizeof (buf), "segment-%4.4d", itemid.num);
    break;
  case VCDINFO_ITEM_TYPE_SPAREID2:
  default:
    return NULL;
  }
  return buf;
}

static const char *
_ofs2id (unsigned offset, const pbc_ctx_t *_ctx)
{
  CdioListNode_t *node;
  static char buf[80];
  unsigned sl_num = 0, el_num = 0, pl_num = 0;
  vcdinfo_offset_t *ofs = NULL;
  
  if (offset == PSD_OFS_DISABLED)
    return NULL;

  _CDIO_LIST_FOREACH (node, _ctx->offset_list)
    {
      ofs = _cdio_list_node_data (node);
	
      switch (ofs->type)
	{
	case PSD_TYPE_PLAY_LIST:
	  pl_num++;
	  break;

	case PSD_TYPE_EXT_SELECTION_LIST:
	case PSD_TYPE_SELECTION_LIST:
	  sl_num++;
	  break;

	case PSD_TYPE_END_LIST:
	  el_num++;
	  break;

	default:
	  vcd_assert_not_reached ();
	  break;
	}

      if (ofs->offset == offset)
	break;
    }

  if (node)
    {
      switch (ofs->type)
	{
	case PSD_TYPE_PLAY_LIST:
	  snprintf (buf, sizeof (buf), "playlist-%.2d", pl_num);
	  break;

	case PSD_TYPE_EXT_SELECTION_LIST:
	case PSD_TYPE_SELECTION_LIST:
	  snprintf (buf, sizeof (buf), "selection-%.2d", sl_num);
	  break;

	case PSD_TYPE_END_LIST:
	  snprintf (buf, sizeof (buf), "end-%d", el_num);
	  break;

	default:
	  snprintf (buf, sizeof (buf), "unknown-type-%4.4x", offset);
	  break;
	}
    }
  else
    snprintf (buf, sizeof (buf), "unknown-offset-%4.4x", offset);

  return buf;
}

static pbc_t *
_pbc_node_read (const pbc_ctx_t *_ctx, unsigned offset)
{
  pbc_t *p_pbc = NULL;
  const uint8_t *_buf = &_ctx->psd[offset * _ctx->offset_mult];
  vcdinfo_offset_t *ofs = NULL;

  {
    CdioListNode_t *node;
    _CDIO_LIST_FOREACH (node, _ctx->offset_list)
      {
	ofs = _cdio_list_node_data (node);

	if (ofs->offset == offset)
	  break;
      }
    vcd_assert (node);
  }

  switch (*_buf)
    {
      int n;

    case PSD_TYPE_PLAY_LIST:
      p_pbc = vcd_pbc_new (PBC_PLAYLIST);
      {
	const PsdPlayListDescriptor_t *d = (const void *) _buf;
	p_pbc->prev_id = _xstrdup (_ofs2id (vcdinf_pld_get_prev_offset(d), 
					   _ctx));
	p_pbc->next_id = _xstrdup (_ofs2id (vcdinf_pld_get_next_offset(d),
					   _ctx));
	p_pbc->retn_id = _xstrdup (_ofs2id (vcdinf_pld_get_return_offset(d),
					   _ctx));
	
	p_pbc->playing_time = (double) (vcdinf_get_play_time(d)) / 15.0;
	p_pbc->wait_time       = vcdinf_get_wait_time(d);
	p_pbc->auto_pause_time = vcdinf_get_autowait_time(d);

	for (n = 0; n < vcdinf_pld_get_noi(d); n++) {
	  _cdio_list_append (p_pbc->item_id_list, 
			    _xstrdup(_pin2id(vcdinf_pld_get_play_item(d,n)
					     )));
	  }
      }
      break;

    case PSD_TYPE_EXT_SELECTION_LIST:
    case PSD_TYPE_SELECTION_LIST:
      p_pbc = vcd_pbc_new (PBC_SELECTION);
      {
	const PsdSelectionListDescriptor_t *d = (const void *) _buf;
	p_pbc->bsn = vcdinf_get_bsn(d);
	p_pbc->prev_id = _xstrdup (_ofs2id (vcdinf_psd_get_prev_offset(d), 
					   _ctx));
	p_pbc->next_id = _xstrdup (_ofs2id (vcdinf_psd_get_next_offset(d), 
					   _ctx));
	p_pbc->retn_id = _xstrdup (_ofs2id (vcdinf_psd_get_return_offset(d),
					   _ctx));

	switch (vcdinf_psd_get_default_offset(d))
	  {
	  case PSD_OFS_DISABLED:
	    p_pbc->default_id = NULL;
	    p_pbc->selection_type = _SEL_NORMAL;
	    break;

	  case PSD_OFS_MULTI_DEF:
	    p_pbc->default_id = NULL;
	    p_pbc->selection_type = _SEL_MULTI_DEF;
	    break;

	  case PSD_OFS_MULTI_DEF_NO_NUM:
	    p_pbc->default_id = NULL;
	    p_pbc->selection_type = _SEL_MULTI_DEF_NO_NUM;
	    break;

	  default:
	    p_pbc->default_id = _xstrdup (_ofs2id (vcdinf_psd_get_default_offset(d),
						  _ctx));
	    p_pbc->selection_type = _SEL_NORMAL;
	    break;
	  }

	p_pbc->timeout_id   = _xstrdup (_ofs2id (vcdinf_get_timeout_offset(d), 
						_ctx));
	p_pbc->timeout_time = vcdinf_get_timeout_time (d);
	p_pbc->jump_delayed = vcdinf_has_jump_delay(d);
	p_pbc->loop_count   = vcdinf_get_loop_count(d);
	p_pbc->item_id      = _xstrdup (_pin2id (vcdinf_psd_get_itemid(d)));

	for (n = 0; n < vcdinf_get_num_selections(d); n++)
	  {
	    _cdio_list_append (p_pbc->select_id_list, 
			      _xstrdup(_ofs2id(vcdinf_psd_get_offset(d,n),
					       _ctx)));
	  }

	if (d->type == PSD_TYPE_EXT_SELECTION_LIST
	    || d->flags.SelectionAreaFlag)
	  {
	    PsdSelectionListDescriptorExtended_t *d2 = 
	      (void *) &d->ofs[d->nos];

	    p_pbc->prev_area = calloc(1, sizeof (pbc_area_t));
	    p_pbc->next_area = calloc(1, sizeof (pbc_area_t));
	    p_pbc->return_area = calloc(1, sizeof (pbc_area_t));
	    p_pbc->default_area = calloc(1, sizeof (pbc_area_t));

	    *p_pbc->prev_area = d2->prev_area;
	    *p_pbc->next_area = d2->next_area;
	    *p_pbc->return_area = d2->return_area;
	    *p_pbc->default_area = d2->default_area;

	    for (n = 0; n < vcdinf_get_num_selections(d); n++)
	      {
		pbc_area_t *p_area = calloc(1, sizeof (pbc_area_t));

		*p_area = d2->area[n];

		_cdio_list_append (p_pbc->select_area_list, p_area);
	      }

	    vcd_assert (_cdio_list_length (p_pbc->select_area_list) 
			== _cdio_list_length (p_pbc->select_id_list));
	  }
      }
      break;

    case PSD_TYPE_END_LIST:
      p_pbc = vcd_pbc_new (PBC_END);
      {
	const PsdEndListDescriptor_t *d = (const void *) _buf;
	
	p_pbc->next_disc = d->next_disc;
	p_pbc->image_id = _xstrdup (_pin2id (uint16_from_be (d->change_pic)));
      }      
      break;

    default:
      vcd_warn ("Unknown PSD type %d", *_buf);
      break;
    }

  if (p_pbc)
    {
      p_pbc->id = _xstrdup (_ofs2id (offset, _ctx));
      p_pbc->rejected = !ofs->in_lot;
    }

  return p_pbc;
}

static void
_visit_pbc (pbc_ctx_t *p_pbc_ctx, lid_t lid, unsigned int offset, 
	    bool in_lot)
{
  CdioListNode_t *node;
  vcdinfo_offset_t *ofs;
  unsigned _rofs = offset * p_pbc_ctx->offset_mult;

  vcd_assert (p_pbc_ctx->psd_size % 8 == 0);

  switch (offset)
    {
    case PSD_OFS_DISABLED:
    case PSD_OFS_MULTI_DEF:
    case PSD_OFS_MULTI_DEF_NO_NUM:
      return;

    default:
      break;
    }

  if (_rofs >= p_pbc_ctx->psd_size)
    {
      if (p_pbc_ctx->extended)
	vcd_error ("psd offset out of range in extended PSD"
		   " (try --no-ext-psd option)");
      else
	vcd_warn ("psd offset out of range, ignoring...");
      return;
    }

  vcd_assert (_rofs < p_pbc_ctx->psd_size);

  if (!p_pbc_ctx->offset_list)
    p_pbc_ctx->offset_list = _cdio_list_new ();

  _CDIO_LIST_FOREACH (node, p_pbc_ctx->offset_list)
    {
      ofs = _cdio_list_node_data (node);

      if (offset == ofs->offset)
        {
          if (in_lot)
            ofs->in_lot = true;

          if (lid) {
            /* Our caller thinks she knows what our LID is.
               This should help out getting the LID for end descriptors
               if not other things as well.
             */
            ofs->lid = lid;
          }
          
          return; /* already been there... */
        }
    }

  ofs = calloc(1, sizeof (vcdinfo_offset_t));

  ofs->offset = offset;
  ofs->lid    = lid;
  ofs->in_lot = in_lot;
  ofs->type   = p_pbc_ctx->psd[_rofs];

  switch (ofs->type)
    {
    case PSD_TYPE_PLAY_LIST:
      _cdio_list_append (p_pbc_ctx->offset_list, ofs);
      {
        const PsdPlayListDescriptor_t *d = 
	  (const void *) (p_pbc_ctx->psd + _rofs);
        const lid_t lid = vcdinf_pld_get_lid(d);

        if (!ofs->lid)
          ofs->lid = lid;
        else 
          if (ofs->lid != lid)
            vcd_warn ("LOT entry assigned LID %d, but descriptor has LID %d",
                      ofs->lid, lid);

        _visit_pbc (p_pbc_ctx, 0, vcdinf_pld_get_prev_offset(d), false);
        _visit_pbc (p_pbc_ctx, 0, vcdinf_pld_get_next_offset(d), false);
        _visit_pbc (p_pbc_ctx, 0, vcdinf_pld_get_return_offset(d), false);
      }
      break;

    case PSD_TYPE_EXT_SELECTION_LIST:
    case PSD_TYPE_SELECTION_LIST:
      _cdio_list_append (p_pbc_ctx->offset_list, ofs);
      {
        const PsdSelectionListDescriptor_t *d =
          (const void *) (p_pbc_ctx->psd + _rofs);

        int idx;
	lid_t lid = vcdinf_psd_get_lid (d);

        if (!ofs->lid)
          ofs->lid = lid;
        else 
          if (ofs->lid != lid)
            vcd_warn ("LOT entry assigned LID %d, but descriptor has LID %d",
                      ofs->lid, lid);

        _visit_pbc (p_pbc_ctx, 0, vcdinf_psd_get_prev_offset(d), false);
        _visit_pbc (p_pbc_ctx, 0, vcdinf_psd_get_next_offset(d), false);
        _visit_pbc (p_pbc_ctx, 0, vcdinf_psd_get_return_offset(d), false);
        _visit_pbc (p_pbc_ctx, 0, vcdinf_psd_get_default_offset(d), false);
        _visit_pbc (p_pbc_ctx, 0, vcdinf_get_timeout_offset(d), false);

        for (idx = 0; idx < vcdinf_get_num_selections(d); idx++)
          _visit_pbc (p_pbc_ctx, 0, vcdinf_psd_get_offset (d, idx), false);
        
      }
      break;

    case PSD_TYPE_END_LIST:
      _cdio_list_append (p_pbc_ctx->offset_list, ofs);
      break;

    default:
      vcd_warn ("corrupt PSD???????");
      free (ofs);
      return;
      break;
    }
}

static void
_visit_lot (pbc_ctx_t *p_pbc_ctx)
{
  const LotVcd_t *lot = p_pbc_ctx->lot;
  unsigned int n, tmp;

  for (n = 0; n < LOT_VCD_OFFSETS; n++)
    if ((tmp = vcdinf_get_lot_offset(lot, n)) != PSD_OFS_DISABLED)
      _visit_pbc (p_pbc_ctx, n + 1, tmp, true);

  _vcd_list_sort (p_pbc_ctx->offset_list, 
		  (_cdio_list_cmp_func) vcdinf_lid_t_cmp);
}

static int
_parse_pbc (vcdxml_t *p_vcdxml, CdIo_t *p_cdio, bool no_ext_psd)
{
  int n;
  pbc_ctx_t _pbc_ctx;
  CdioListNode_t *node;
  bool extended = false;
  uint32_t _lot_vcd_sector = -1;
  uint32_t _psd_vcd_sector = -1;
  unsigned _psd_size = -1;
  iso9660_stat_t *statbuf;
  int rc = 0;

  if (!p_vcdxml->info.psd_size)
    {
      vcd_debug ("No PBC info");
      return 0;
    }

  if (p_vcdxml->vcd_type == VCD_TYPE_VCD2)
    {
      statbuf = iso9660_fs_stat (p_cdio, "EXT/LOT_X.VCD;1");
      if (statbuf != NULL) {
	extended = true;
	_lot_vcd_sector = statbuf->lsn;
	vcd_assert (statbuf->size == ISO_BLOCKSIZE * LOT_VCD_SIZE);
      }  

      free(statbuf);
      if (extended &&
	  NULL != (statbuf = iso9660_fs_stat (p_cdio, "EXT/PSD_X.VCD;1"))) {
	_psd_vcd_sector = statbuf->lsn;
	_psd_size = statbuf->size;
	free(statbuf);
      } else
	extended = false;
    }

  _pbc_ctx.extended = extended;

  if (extended && !no_ext_psd)
    vcd_info ("detected extended VCD2.0 PBC files");
  else {
    if (extended)
      vcd_info ("ignoring detected extended VCD2.0 PBC files");
    
    _pbc_ctx.extended = false;
    
    _lot_vcd_sector = LOT_VCD_SECTOR;
    _psd_vcd_sector = PSD_VCD_SECTOR;
    _psd_size = p_vcdxml->info.psd_size;
  }

  _pbc_ctx.psd_size = _psd_size;
  _pbc_ctx.offset_mult = 8;
  _pbc_ctx.maximum_lid = p_vcdxml->info.max_lid;

  _pbc_ctx.offset_list = _cdio_list_new ();

  /* read in LOT */
  
  _pbc_ctx.lot = calloc(1, ISO_BLOCKSIZE * LOT_VCD_SIZE);
  
  if (cdio_read_mode2_sectors (p_cdio, _pbc_ctx.lot, _lot_vcd_sector, false, 
			       LOT_VCD_SIZE)) {
    _cdio_list_free (_pbc_ctx.offset_list, true);
    free(_pbc_ctx.lot);
    return -1;
  }
  

  /* read in PSD */

  n = _vcd_len2blocks (_psd_size, ISO_BLOCKSIZE);

  _pbc_ctx.psd = calloc(1, ISO_BLOCKSIZE * n);

  if (cdio_read_mode2_sectors (p_cdio, _pbc_ctx.psd,_psd_vcd_sector, false, n)) {
    rc = -1;
    goto free_and_return;
  }
  

  /* traverse it */

  _visit_lot (&_pbc_ctx);

  _CDIO_LIST_FOREACH (node, _pbc_ctx.offset_list)
    {
      vcdinfo_offset_t *ofs = _cdio_list_node_data (node);
      pbc_t *_pbc;

      vcd_assert (ofs->offset != PSD_OFS_DISABLED);
      
      if ((_pbc = _pbc_node_read (&_pbc_ctx, ofs->offset)))
	_cdio_list_append (p_vcdxml->pbc_list, _pbc);
    }

 free_and_return:
  _cdio_list_free (_pbc_ctx.offset_list, true);
  free(_pbc_ctx.lot);
  free(_pbc_ctx.psd);
  return 0;
}

static int
_rip_isofs (vcdxml_t *p_vcdxml, CdIo_t *p_cdio)
{
  CdioListNode_t *node;
  
  _CDIO_LIST_FOREACH (node, p_vcdxml->filesystem)
    {
      struct filesystem_t *_fs = _cdio_list_node_data (node);
      int idx;
      FILE *outfd;
      const int blocksize = _fs->file_raw ? M2RAW_SECTOR_SIZE : ISO_BLOCKSIZE;

      if (!_fs->file_src)
	continue;

      vcd_info ("extracting %s to %s (lsn %u, size %u, raw %d)", 
		_fs->name, _fs->file_src,
		(unsigned int) _fs->lsn, (unsigned int) _fs->size, 
		_fs->file_raw);

      if (!(outfd = fopen (_fs->file_src, "wb")))
        {
          perror ("fopen()");
          exit (EXIT_FAILURE);
        }

      for (idx = 0; idx < _fs->size; idx += blocksize)
	{
	  char buf[blocksize];
	  /* some EDG based compilers segfault on the commented out code */
	  /* memset (buf, 0, sizeof (buf)); */
	  memset (buf, 0, blocksize);

	  cdio_read_mode2_sector (p_cdio, buf, _fs->lsn + (idx / blocksize),
				  _fs->file_raw);

	  fwrite (buf, blocksize, 1, outfd);

	  if (ferror (outfd))
	    {
	      perror ("fwrite()");
	      exit (EXIT_FAILURE);
	    }
	}

      fflush (outfd);
      if (ftruncate (fileno (outfd), _fs->size))
	perror ("ftruncate()");

      fclose (outfd);
      
    }

  return 0;
}

static int
_rip_segments (vcdxml_t *p_vcdxml, CdIo_t *p_cdio)
{
  CdioListNode_t *node;
  lsn_t start_extent;

  start_extent = p_vcdxml->info.segments_start;

  vcd_assert (start_extent % CDIO_CD_FRAMES_PER_SEC == 0);

  _CDIO_LIST_FOREACH (node, p_vcdxml->segment_list)
    {
      struct segment_t *p_seg = _cdio_list_node_data (node);
      uint32_t n;
      FILE *outfd = NULL;
      VcdMpegStreamCtx mpeg_ctx;
      double last_pts = 0;

      vcd_assert (p_seg->segments_count > 0);

      memset (&mpeg_ctx, 0, sizeof (VcdMpegStreamCtx));

      vcd_info ("extracting %s... (start lsn %u, %d segments)",
		p_seg->src, (unsigned int) start_extent, 
		p_seg->segments_count);

      if (!(outfd = fopen (p_seg->src, "wb")))
        {
          perror ("fopen()");
          exit (EXIT_FAILURE);
        }

      for (n = 0; n < p_seg->segments_count * VCDINFO_SEGMENT_SECTOR_SIZE; n++)
	{
	  struct m2f2sector
          {
            uint8_t subheader[8];
            uint8_t data[M2F2_SECTOR_SIZE];
            uint8_t spare[4];
          }
          buf;

	  memset (&buf, 0, sizeof (buf));
	  cdio_read_mode2_sector (p_cdio, &buf, start_extent + n, true);
	  
	  if (!buf.subheader[0] 
              && !buf.subheader[1]
              && (buf.subheader[2] | SM_FORM2) == SM_FORM2
              && !buf.subheader[3])
            {
              vcd_warn ("no EOF seen, but stream ended");
              break;
            }

	  vcd_mpeg_parse_packet (buf.data, M2F2_SECTOR_SIZE, false, &mpeg_ctx);

	  if (mpeg_ctx.packet.has_pts)
	    {
	      last_pts = mpeg_ctx.packet.pts;
	      if (mpeg_ctx.stream.seen_pts)
		last_pts -= mpeg_ctx.stream.min_pts;
	      if (last_pts < 0)
		last_pts = 0;
	      /* vcd_debug ("pts %f @%d", mpeg_ctx.packet.pts, n); */
	    }

	  if (buf.subheader[2] & SM_TRIG)
	    {
	      double *_ap_ts = calloc(1, sizeof (double));
	      
	      vcd_debug ("autopause @%u (%f)", (unsigned int) n, last_pts);
	      *_ap_ts = last_pts;

	      _cdio_list_append (p_seg->autopause_list, _ap_ts);
	    }

	  fwrite (buf.data, M2F2_SECTOR_SIZE, 1, outfd);

	  if (ferror (outfd))
            {
              perror ("fwrite()");
              exit (EXIT_FAILURE);
            }

	  if (buf.subheader[2] & SM_EOF)
            break;
	}

      fclose (outfd);

      start_extent += p_seg->segments_count * VCDINFO_SEGMENT_SECTOR_SIZE;
    }

  return 0;
}

static int
_rip_sequences (vcdxml_t *p_vcdxml, CdIo_t *p_cdio, int i_track)
{
  CdioListNode_t *node;
  int counter=1;

  _CDIO_LIST_FOREACH (node, p_vcdxml->sequence_list)
    {
      struct sequence_t *_seq = _cdio_list_node_data (node);
      CdioListNode_t *nnode = _cdio_list_node_next (node);
      struct sequence_t *_nseq = nnode ? _cdio_list_node_data (nnode) : NULL;
      FILE *outfd = NULL;
      bool in_data = false;
      VcdMpegStreamCtx mpeg_ctx;
      uint32_t start_lsn, end_lsn, n, last_nonzero, first_data;
      double last_pts = 0;

      _read_progress_t _progress;

      struct m2f2sector
      {
	uint8_t subheader[CDIO_CD_SUBHEADER_SIZE];
	uint8_t data[M2F2_SECTOR_SIZE];
	uint8_t spare[4];
      }
      buf[15];

      if (i_track > 0 && i_track!=counter++) {
	vcd_info("Track %d selected, skipping track %d", i_track,counter-1);
	continue;
      }
	  
      if (i_track < 0 && -i_track==counter++) {
	vcd_info("Skipping track %d", -i_track);
	continue;
      }
	  
      memset (&mpeg_ctx, 0, sizeof (VcdMpegStreamCtx));

      start_lsn = _seq->start_extent;
      end_lsn = _nseq ? _nseq->start_extent : cdio_stat_size (p_cdio);

      vcd_info ("extracting %s... (start lsn %lu (+%lu))",
		_seq->src, (long unsigned int) start_lsn, 
		(long unsigned int) (end_lsn - start_lsn));

      if (!(outfd = fopen (_seq->src, "wb")))
        {
          perror ("fopen()");
          exit (EXIT_FAILURE);
        }

      last_nonzero = start_lsn - 1;
      first_data = 0;

      _progress.total = end_lsn;

      for (n = start_lsn; n < end_lsn; n++)
	{
	  const int buf_idx = (n - start_lsn) % 15;

	  if (n - _progress.done > (end_lsn / 100))
	    {
	      _progress.done = n;
	      vcd_xml_read_progress_cb (&_progress, _seq->src);
	    }

	  if (!buf_idx)
	    {
	      const int secs_left = end_lsn - n;

	      memset (buf, 0, sizeof (buf));
	      cdio_read_mode2_sectors (p_cdio, buf, n, true, (secs_left > 15 
							   ? 15 : secs_left));
	    }

	  if (_nseq && n + CDIO_POSTGAP_SECTORS == end_lsn + 1)
	    vcd_warn ("reading into gap @%u... :-(", (unsigned int) n);

	  if (!(buf[buf_idx].subheader[2] & SM_FORM2))
	    {
	      vcd_warn ("encountered non-form2 sector -- leaving loop");
	      break;
	    }
	  
	  if (in_data)
	    { /* end conditions... */
	      if (!buf[buf_idx].subheader[0])
		{
		  vcd_debug ("fn -edge @%u", (unsigned int) n);
		  break;
		}

	      if (!(buf[buf_idx].subheader[2] & SM_REALT))
		{
		  vcd_debug ("subheader: no realtime data anymore @%u", 
			     (unsigned int) n);
		  break;
		}
	    }

	  if (buf[buf_idx].subheader[1] && !in_data)
	    {
	      vcd_debug ("cn +edge @%u", (unsigned int) n);
	      in_data = true;
	    }


#if defined(DEBUG)
	  if (!in_data)
	    vcd_debug ("%2.2x %2.2x %2.2x %2.2x",
		       buf[buf_idx].subheader[0],
		       buf[buf_idx].subheader[1],
		       buf[buf_idx].subheader[2],
		       buf[buf_idx].subheader[3]);
#endif

	  if (in_data)
	    {
	      CdioListNode_t *_node;

	      vcd_mpeg_parse_packet (buf[buf_idx].data, M2F2_SECTOR_SIZE, 
				     false, &mpeg_ctx);

	      if (!mpeg_ctx.packet.zero)
		last_nonzero = n;

	      if (!first_data && !mpeg_ctx.packet.zero)
		first_data = n;
	      
	      if (mpeg_ctx.packet.has_pts)
		{
		  last_pts = mpeg_ctx.packet.pts;
		  if (mpeg_ctx.stream.seen_pts)
		    last_pts -= mpeg_ctx.stream.min_pts;
		  if (last_pts < 0)
		    last_pts = 0;
		  /* vcd_debug ("pts %f @%d", mpeg_ctx.packet.pts, n); */
		}

	      if (buf[buf_idx].subheader[2] & SM_TRIG)
		{
		  double *_ap_ts = calloc(1, sizeof (double));

		  vcd_debug ("autopause @%u (%f)", (unsigned int) n, 
			     last_pts);
		  *_ap_ts = last_pts;

		  _cdio_list_append (_seq->autopause_list, _ap_ts);
		}
	      
	      _CDIO_LIST_FOREACH (_node, _seq->entry_point_list)
		{
		  struct entry_point_t *_ep = _cdio_list_node_data (_node);

		  if (_ep->extent == n)
		    {
		      vcd_debug ("entry point @%u (%f)", (unsigned int) n, 
				 last_pts);
		      _ep->timestamp = last_pts;
		    }
		}
	      
	      if (first_data)
		{
		  fwrite (buf[buf_idx].data, M2F2_SECTOR_SIZE, 1, outfd);

		  if (ferror (outfd))
		    {
		      perror ("fwrite()");
		      exit (EXIT_FAILURE);
		    }
		}

	    } /* if (in_data) */
	  
	  if (buf[buf_idx].subheader[2] & SM_EOF)
	    {
	      vcd_debug ("encountered subheader EOF @%u", (unsigned int) n);
	      break;
	    }
	} /* for */
      
      _progress.done = _progress.total;
      vcd_xml_read_progress_cb (&_progress, _seq->src);

      if (in_data)
	{
	  uint32_t length;

	  if (n == end_lsn)
	    vcd_debug ("stream till end of track");
	  
	  length = (1 + last_nonzero) - first_data;

	  vcd_debug ("truncating file to %u packets", 
		     (unsigned int) length);

	  fflush (outfd);
	  if (ftruncate (fileno (outfd), length * M2F2_SECTOR_SIZE))
	    perror ("ftruncate()");
	}

      fclose (outfd);
    } /* _CDIO_LIST_FOREACH */

  return 0;
}

static vcd_log_handler_t  gl_default_vcd_log_handler = NULL;
static cdio_log_handler_t gl_default_cdio_log_handler = NULL;

static void 
_vcd_log_handler (vcd_log_level_t level, const char message[])
{
  if (level == VCD_LOG_DEBUG && !_verbose_flag)
    return;

  if (level == VCD_LOG_INFO && _quiet_flag)
    return;
  
  gl_default_vcd_log_handler (level, message);
}

#define DEFAULT_XML_FNAME      "videocd.xml"
#define DEFAULT_IMG_FNAME      "videocd.bin"

poptContext optCon;

int
main (int argc, const char *argv[])
{
  CdIo_t *img_src = NULL;
  vcdxml_t vcdxml;

  /* cl params */
  char *xml_fname = NULL;
  char *source_name = NULL;
  int norip_flag = 0;
  int nocommand_comment_flag = 0;
  int nofile_flag = 0;
  int noseq_flag = 0;
  int noseg_flag = 0;
  int no_ext_psd_flag = 0;
  int sector_2336_flag = 0;
  int _progress_flag = 0;
  int _gui_flag = 0;
  int _track_flag=0;
  int _x_track_flag=0;

  enum { 
    OP_SOURCE_UNDEF = DRIVER_UNKNOWN, 
    OP_SOURCE_BINCUE= DRIVER_BINCUE,
    OP_SOURCE_NRG   = DRIVER_NRG,
    OP_SOURCE_CDRDAO= DRIVER_CDRDAO,
    OP_SOURCE_CDROM = DRIVER_DEVICE,
    OP_VERSION      = 20
  } source_type = OP_SOURCE_UNDEF;

  vcd_xml_progname = "vcdxrip";

  vcd_xml_init (&vcdxml);

  gl_default_vcd_log_handler  = vcd_log_set_handler (_vcd_log_handler);
  gl_default_cdio_log_handler = 
    cdio_log_set_handler ( (cdio_log_handler_t) _vcd_log_handler);

  {
    int opt;

    struct poptOption optionsTable[] = {
      {"output-file", 'o', POPT_ARG_STRING, &xml_fname, 0,
       "specify xml file for output (default: '" DEFAULT_XML_FNAME "')",
       "FILE"},

      {"bin-file", 'b', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
       OP_SOURCE_BINCUE,
       "set image file as source (default: '" DEFAULT_IMG_FNAME "')", 
       "FILE"},

      {"cue-file", 'c', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
       OP_SOURCE_BINCUE, "set \"cue\" CD-ROM disk image file as source", "FILE"},

      {"nrg-file", 'N', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
       OP_SOURCE_NRG, "set Nero CD-ROM disk image image file as source",
       "FILE"},

      {"toc-file", '\0', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
       OP_SOURCE_CDRDAO, "set \"toc\" CD-ROM disk image file as source", "FILE"},
      {"cdrom-device", 'C', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name,
       OP_SOURCE_CDROM,"set CDROM device as source", "DEVICE"},

      {"sector-2336", '\0', POPT_ARG_NONE, &sector_2336_flag, 0,
       "use 2336 byte sector mode for image file"},

      {"input", 'i', POPT_ARG_STRING|POPT_ARGFLAG_OPTIONAL, &source_name, 
       OP_SOURCE_UNDEF, 
       "set source and determine if \"bin\" image or device", "FILE"},

      {"no-ext-psd", '\0', POPT_ARG_NONE, &no_ext_psd_flag, 0,
       "ignore /EXT/PSD_X.VCD"},

      {"no-command-comment", '\0', POPT_ARG_NONE, &nocommand_comment_flag, 0,
       "Don't include command name as a comment"},

      {"norip", '\0', POPT_ARG_NONE, &norip_flag, 0,
       "only extract XML structure"},

      {"nofiles", '\0', POPT_ARG_NONE, &nofile_flag, 0,
       "don't extract files"},

      {"nosequences", '\0', POPT_ARG_NONE, &noseq_flag, 0,
       "don't extract sequences"},

      {"nosegments", '\0', POPT_ARG_NONE, &noseg_flag, 0,
       "don't extract segment play items"},

      {"progress", 'p', POPT_ARG_NONE, &_progress_flag, 0,  
       "show progress"}, 

      { "track", 't', POPT_ARG_INT, &_track_flag, 0,
	"rip only this track"},
      
      { "notrack", 'T', POPT_ARG_INT, &_x_track_flag, 0,
	"do not rip this track"},
      
      { "filename-encoding", '\0', POPT_ARG_STRING, &vcd_xml_filename_charset, 0,
        "use given charset encoding for filenames instead of UTF8" },

      {"verbose", 'v', POPT_ARG_NONE, &_verbose_flag, 0, 
       "be verbose"},
    
      {"quiet", 'q', POPT_ARG_NONE, &_quiet_flag, 0, 
       "show only critical messages"},

      {"gui", '\0', POPT_ARG_NONE, &_gui_flag, 0, "enable GUI mode"},

      {"version", 'V', POPT_ARG_NONE, NULL, OP_VERSION,
       "display version and copyright information and exit"},
	   
      POPT_AUTOHELP {NULL, 0, 0, NULL, 0}
    };

    optCon = poptGetContext (NULL, argc, argv, optionsTable, 0);

    while ((opt = poptGetNextOpt (optCon)) >= 0)
      switch (opt)
	{
	case OP_VERSION:
          vcd_xml_gui_mode = _gui_flag;
          vcd_xml_print_version ();
	  poptFreeContext(optCon);
	  exit (EXIT_SUCCESS);
	  break;

	case OP_SOURCE_UNDEF:
	case OP_SOURCE_BINCUE:
	case OP_SOURCE_CDRDAO:
	case OP_SOURCE_NRG:
	case OP_SOURCE_CDROM:
	  if (OP_SOURCE_UNDEF != source_type && !source_name)
	    {
	      vcd_error ("Only one image (type) supported at once - try --help");
	      exit (EXIT_FAILURE);
	    }
	  source_type = opt;
	  break;
	
	default:
	  fprintf (stderr, "%s: %s\n", 
		   poptBadOption(optCon, POPT_BADOPTION_NOALIAS),
		   poptStrerror(opt));
	  fprintf (stderr, "error while parsing command line - try --help\n");
	  poptFreeContext(optCon);
	  exit (EXIT_FAILURE);
	  break;
      }

    if (_verbose_flag && _quiet_flag)
      vcd_error ("I can't be both, quiet and verbose... either one or another ;-)");
    
    if (poptGetArgs (optCon) != NULL)
      vcd_error ("Why are you giving me non-option arguments? -- try --help");

  }

  if (_quiet_flag)
    vcd_xml_verbosity = VCD_LOG_WARN;
  else if (_verbose_flag)
    vcd_xml_verbosity = VCD_LOG_DEBUG;
  else
    vcd_xml_verbosity = VCD_LOG_INFO;

  if (_gui_flag)
    vcd_xml_gui_mode = true;

  if (_progress_flag)
    vcd_xml_show_progress = true;

  if (!xml_fname) {
    xml_fname = strdup (DEFAULT_XML_FNAME);
  }

  /* If we don't specify a driver_id or a source_name, scan the
     system for a CD that contains a VCD.
   */
  if (NULL == source_name && source_type == DRIVER_UNKNOWN) {
    char **cd_drives=NULL;
    cd_drives = cdio_get_devices_with_cap(NULL, 
                (CDIO_FS_ANAL_SVCD|CDIO_FS_ANAL_CVD|CDIO_FS_ANAL_VIDEOCD
                |CDIO_FS_UNKNOWN),
                                          true);
    if ( NULL == cd_drives || NULL == cd_drives[0] ) {
      return VCDINFO_OPEN_ERROR;
    }
    source_name = strdup(cd_drives[0]);
    cdio_free_device_list(cd_drives);
  }

  img_src = cdio_open(source_name, source_type);
  if (NULL == img_src) {
    vcd_error ("Error determining place to read from.");
    exit (EXIT_FAILURE);
  }
  
  if (NULL == source_name) 
    source_name = cdio_get_default_device(img_src);

  vcdxml.comment = vcd_xml_dump_cl_comment (argc, argv, 
					      nocommand_comment_flag);

  /* start with ISO9660 PVD */
  _parse_pvd (&vcdxml, img_src);

  _parse_isofs (&vcdxml, img_src); 
  
  /* needs to be parsed in order */
  _parse_info (&vcdxml, img_src);
  _parse_entries (&vcdxml, img_src);

  /* needs to be parsed last! */
  _parse_pbc (&vcdxml, img_src, no_ext_psd_flag);

  if (_x_track_flag) _track_flag = - _x_track_flag;
  
  if (norip_flag || noseq_flag || noseg_flag || _track_flag) {
    vcd_warn ("Entry offsets inside sequence-items may incorrect...");
    vcd_warn ("and auto-pause locations might not be checked.");
  }

  if (!norip_flag)
    {
      if (!nofile_flag)
	_rip_isofs (&vcdxml, img_src);

      if (!noseg_flag)
	_rip_segments (&vcdxml, img_src);

      if (!noseq_flag)
	_rip_sequences (&vcdxml, img_src, _track_flag);
    }

  vcd_info ("Writing XML description to `%s'...", xml_fname);
  vcd_xml_dump (&vcdxml, xml_fname);
  vcd_xml_destroy(&vcdxml);
  free(xml_fname);
  free(source_name);
  poptFreeContext(optCon);

  cdio_destroy (img_src);
  vcd_info ("done");
  return EXIT_SUCCESS;
}
