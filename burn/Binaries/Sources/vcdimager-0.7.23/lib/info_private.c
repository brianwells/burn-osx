/*
    $Id: info_private.c,v 1.7 2005/02/02 00:37:37 rocky Exp $

    Copyright (C) 2003, 2005 Rocky Bernstein <rocky@panix.com>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Foundation
    Software, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/
/* 
   Like vcdinfo but exposes more of the internal structure. It is probably
   better to use vcdinfo, when possible.
*/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdio.h>
#include <stddef.h>
#include <errno.h>

#ifdef HAVE_STDLIB_H
#include <stdlib.h>
#endif
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif
#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include <cdio/cdio.h>
#include <cdio/bytesex.h>
#include <cdio/util.h>

#include <libvcd/types.h>
#include <libvcd/files.h>

#include <libvcd/info.h>

/* Private headers */
#include "vcd_assert.h"
#include "data_structures.h"
#include "info_private.h"
#include "pbc.h"

static const char _rcsid[] = "$Id: info_private.c,v 1.7 2005/02/02 00:37:37 rocky Exp $";

/*
  This fills in unassigned LIDs in the offset table.  Due to
  "rejected" LOT entries, some of these might not have gotten filled
  in while scanning PBC (if in fact there even was a PBC).

  Note: We assume that an unassigned LID is one whose value is 0.
 */
static void
vcdinf_update_offset_list(struct _vcdinf_pbc_ctx *obj, bool extended)
{
  if (NULL==obj) return;
  {
    CdioListNode_t *node;
    CdioList_t *unused_lids = _cdio_list_new();
    CdioListNode_t *next_unused_node = _cdio_list_begin(unused_lids);
    
    unsigned int last_lid=0;
    CdioList_t *offset_list = extended ? obj->offset_x_list : obj->offset_list;
    
    lid_t max_seen_lid=0;

    _CDIO_LIST_FOREACH (node, offset_list)
      {
        vcdinfo_offset_t *ofs = _cdio_list_node_data (node);
        if (!ofs->lid) {
          /* We have a customer! Assign a LID from the free pool
             or take one from the end if no skipped LIDs.
          */
          CdioListNode_t *node=_cdio_list_node_next(next_unused_node);
          if (node != NULL) {
            lid_t *next_unused_lid=_cdio_list_node_data(node);
            ofs->lid = *next_unused_lid;
            next_unused_node=node;
          } else {
            max_seen_lid++;
            ofs->lid = max_seen_lid;
          }
        } else {
          /* See if we've skipped any LID numbers. */
          last_lid++;
          while (last_lid != ofs->lid ) {
            lid_t * lid=calloc(1, sizeof(lid_t));
            *lid = last_lid;
            _cdio_list_append(unused_lids, lid);
          }
          if (last_lid > max_seen_lid) max_seen_lid=last_lid;
        }
      }
    _cdio_list_free(unused_lids, true);
  }
}

/*!
   Calls recursive routine to populate obj->offset_list or obj->offset_x_list
   by going through LOT.

   Returns false if there was some error.
*/
bool
vcdinf_visit_lot (struct _vcdinf_pbc_ctx *obj)
{
  const LotVcd_t *lot = obj->extended ? obj->lot_x : obj->lot;
  unsigned int n, tmp;
  bool ret=true;

  if (obj->extended) {
    if (!obj->psd_x_size) return false;
  } else if (!obj->psd_size) return false;

  for (n = 0; n < LOT_VCD_OFFSETS; n++)
    if ((tmp = vcdinf_get_lot_offset(lot, n)) != PSD_OFS_DISABLED)
      ret &= vcdinf_visit_pbc (obj, n + 1, tmp, true);

  _vcd_list_sort (obj->extended ? obj->offset_x_list : obj->offset_list, 
                  (_cdio_list_cmp_func) vcdinf_lid_t_cmp);

  /* Now really complete the offset table with LIDs.  This routine
     might obviate the need for vcdinf_visit_pbc() or some of it which is
     more complex. */
  vcdinf_update_offset_list(obj, obj->extended);
  return ret;
}

/*!
   Recursive routine to populate obj->offset_list or obj->offset_x_list
   by reading playback control entries referred to via lid.

   Returns false if there was some error.
*/
bool
vcdinf_visit_pbc (struct _vcdinf_pbc_ctx *obj, lid_t lid, unsigned int offset, 
                  bool in_lot)
{
  CdioListNode_t *node;
  vcdinfo_offset_t *ofs;
  unsigned int psd_size  = obj->extended ? obj->psd_x_size : obj->psd_size;
  const uint8_t *psd = obj->extended ? obj->psd_x : obj->psd;
  unsigned int _rofs = offset * obj->offset_mult;
  CdioList_t *offset_list;
  bool ret=true;

  vcd_assert (psd_size % 8 == 0);

  switch (offset)
    {
    case PSD_OFS_DISABLED:
    case PSD_OFS_MULTI_DEF:
    case PSD_OFS_MULTI_DEF_NO_NUM:
      return true;

    default:
      break;
    }

  if (_rofs >= psd_size)
    {
      if (obj->extended)
	vcd_warn ("psd offset out of range in extended PSD (%d >= %d)",
		   _rofs, psd_size);
      else
        vcd_warn ("psd offset out of range (%d >= %d)", _rofs, psd_size);
      return false;
    }

  if (!obj->offset_list)
    obj->offset_list = _cdio_list_new ();

  if (!obj->offset_x_list)
    obj->offset_x_list = _cdio_list_new ();

  if (obj->extended) {
    offset_list = obj->offset_x_list;
  } else 
    offset_list = obj->offset_list;

  _CDIO_LIST_FOREACH (node, offset_list)
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
          
          ofs->ext = obj->extended;

          return true; /* already been there... */
        }
    }

  ofs = calloc(1, sizeof (vcdinfo_offset_t));

  ofs->ext    = obj->extended;
  ofs->in_lot = in_lot;
  ofs->lid    = lid;
  ofs->offset = offset;
  ofs->type   = psd[_rofs];

  switch (ofs->type)
    {
    case PSD_TYPE_PLAY_LIST:
      _cdio_list_append (offset_list, ofs);
      {
        const PsdPlayListDescriptor_t *d = (const void *) (psd + _rofs);
        const lid_t lid = vcdinf_pld_get_lid(d);

        if (!ofs->lid)
          ofs->lid = lid;
        else 
          if (ofs->lid != lid)
            vcd_warn ("LOT entry assigned LID %d, but descriptor has LID %d",
                      ofs->lid, lid);

        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_pld_get_prev_offset(d), false);
        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_pld_get_next_offset(d), false);
        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_pld_get_return_offset(d), 
                                 false);
      }
      break;

    case PSD_TYPE_EXT_SELECTION_LIST:
    case PSD_TYPE_SELECTION_LIST:
      _cdio_list_append (offset_list, ofs);
      {
        const PsdSelectionListDescriptor_t *d =
          (const void *) (psd + _rofs);

        int idx;

        if (!ofs->lid)
          ofs->lid = uint16_from_be (d->lid) & 0x7fff;
        else 
          if (ofs->lid != (uint16_from_be (d->lid) & 0x7fff))
            vcd_warn ("LOT entry assigned LID %d, but descriptor has LID %d",
                      ofs->lid, uint16_from_be (d->lid) & 0x7fff);

        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_psd_get_prev_offset(d), false);
        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_psd_get_next_offset(d), false);
        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_psd_get_return_offset(d), 
                                 false);
        ret &= vcdinf_visit_pbc (obj, 0, vcdinf_psd_get_default_offset(d), 
                                 false);
        ret &= vcdinf_visit_pbc (obj, 0, uint16_from_be (d->timeout_ofs), 
                                 false);

        for (idx = 0; idx < vcdinf_get_num_selections(d); idx++)
          ret &= vcdinf_visit_pbc (obj, 0, vcdinf_psd_get_offset(d, idx), 
                                   false);
      }
      break;

    case PSD_TYPE_END_LIST:
      _cdio_list_append (offset_list, ofs);
      break;

    default:
      vcd_warn ("corrupt PSD???????");
      free (ofs);
      return false;
      break;
    }
  return ret;
}

/*!  Return the starting LBA (logical block address) for sequence
  entry_num in obj.  VCDINFO_NULL_LBA is returned if there is no entry.
*/
lba_t
vcdinf_get_entry_lba(const EntriesVcd_t *entries, unsigned int entry_num)
{
  const msf_t *msf = vcdinf_get_entry_msf(entries, entry_num);
  return (msf != NULL) ? cdio_msf_to_lba(msf) : VCDINFO_NULL_LBA;
}

/*!  Return the starting MSF (minutes/secs/frames) for sequence
  entry_num in obj.  NULL is returned if there is no entry.
  The first entry number is 0.
*/
const msf_t *
vcdinf_get_entry_msf(const EntriesVcd_t *entries, unsigned int entry_num)
{
  const unsigned int entry_count = uint16_from_be (entries->entry_count);
  return entry_num < entry_count ?
    &(entries->entry[entry_num].msf)
    : NULL;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
