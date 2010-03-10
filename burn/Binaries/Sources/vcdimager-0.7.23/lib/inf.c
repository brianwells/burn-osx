/*
    $Id: inf.c,v 1.6 2004/11/19 02:15:42 rocky Exp $

    Copyright (C) 2002,2003 Rocky Bernstein <rocky@panix.com>

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
   Things here refer to lower-level structures using a structure other
   than vcdinfo_t. For higher-level structures via the vcdinfo_t, see
   info.c
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

/* Eventually move above libvcd includes but having vcdinfo including. */
#include <libvcd/info.h>

/* Private headers */
#include "info_private.h"
#include "pbc.h"

static const char _rcsid[] = "$Id: inf.c,v 1.6 2004/11/19 02:15:42 rocky Exp $";

#define BUF_COUNT 16
#define BUF_SIZE 80

/* Return a pointer to a internal free buffer */
static char *
_getbuf (void)
{
  static char _buf[BUF_COUNT][BUF_SIZE];
  static int _num = -1;
  
  _num++;
  _num %= BUF_COUNT;

  memset (_buf[_num], 0, BUF_SIZE);

  return _buf[_num];
}

const char *
vcdinf_area_str (const struct psd_area_t *_area)
{
  char *buf;

  if (!_area->x1  
      && !_area->y1
      && !_area->x2
      && !_area->y2)
    return "disabled";

  buf = _getbuf ();

  snprintf (buf, BUF_SIZE, "[%3d,%3d] - [%3d,%3d]",
            _area->x1, _area->y1,
            _area->x2, _area->y2);
            
  return buf;
}

/*!
   Return a string containing the VCD album id, or NULL if there is 
   some problem in getting this. 
*/
const char *
vcdinf_get_album_id(const InfoVcd_t *info)
{
  if (NULL==info) return NULL;
  return vcdinfo_strip_trail (info->album_desc, MAX_ALBUM_LEN);
}

/*!
  Get autowait time value for PsdPlayListDescriptor *d.
  Time is in seconds unless it is -1 (unlimited).
*/
int
vcdinf_get_autowait_time (const PsdPlayListDescriptor_t *d) 
{
  return vcdinfo_get_wait_time (d->atime);
}

/*!
  Return the base selection number. VCD_INVALID_BSN is returned if there
  is an error.
*/
unsigned int
vcdinf_get_bsn(const PsdSelectionListDescriptor_t *psd)
{
  if (NULL==psd) return VCDINFO_INVALID_BSN;
  return(psd->bsn);
}

/*!
   Return a string giving VCD format (VCD 1.0 VCD 1.1, SVCD, ... 
   for this object.
*/
const char *
vcdinf_get_format_version_str (vcd_type_t vcd_type) 
{
  switch (vcd_type)
    {
    case VCD_TYPE_VCD:
      return ("VCD 1.0");
      break;
    case VCD_TYPE_VCD11:
      return ("VCD 1.1");
      break;
    case VCD_TYPE_VCD2:
      return ("VCD 2.0");
      break;
    case VCD_TYPE_SVCD:
      return ("SVCD");
      break;
    case VCD_TYPE_HQVCD:
      return ("HQVCD");
      break;
    case VCD_TYPE_INVALID:
      return ("INVALID");
      break;
    default:
      return ( "????");
    }
}

/*!
  Return loop count. 0 is infinite loop.
*/
uint16_t
vcdinf_get_loop_count (const PsdSelectionListDescriptor_t *psd) 
{
  return 0x7f & psd->loop;
}

/*!
  Return LOT offset
*/
uint16_t
vcdinf_get_lot_offset (const LotVcd_t *lot, unsigned int n) 
{
  return uint16_from_be (lot->offset[n]);
}

/*!
  Return the number of entries in the VCD.
*/
unsigned int
vcdinf_get_num_entries(const EntriesVcd_t *entries)
{
  if (NULL==entries) return 0;
  return (uint16_from_be (entries->entry_count));
}

/*!
  Return the number of segments in the VCD. 
*/
segnum_t
vcdinf_get_num_segments(const InfoVcd_t *info)
{
  if (NULL==info) return 0;
  return (uint16_from_be (info->item_count));
}

/*!
  Return number of LIDs. 
*/
lid_t
vcdinf_get_num_LIDs (const InfoVcd_t *info) 
{
  if (NULL==info) return 0;
  /* Should probably use _vcd_pbc_max_lid instead? */
  return uint16_from_be (info->lot_entries);
}

/*!
  Return the number of menu selections for selection list descriptor psd.
*/
unsigned int
vcdinf_get_num_selections(const PsdSelectionListDescriptor_t *psd)
{
  return psd->nos;
}

/*!
  Get play time value for PsdPlayListDescriptor *d.
  Time is in 1/15-second units.
*/
uint16_t
vcdinf_get_play_time (const PsdPlayListDescriptor_t *d) 
{
  if (NULL==d) return 0;
  return uint16_from_be (d->ptime);
}

/*!
  Return number of bytes in PSD. 
*/
uint32_t
vcdinf_get_psd_size (const InfoVcd_t *info)
{
  if (NULL==info) return 0;
  return uint32_from_be (info->psd_size);
}

/*!
  Get timeout wait time value for PsdPlayListDescriptor *d.
  Return VCDINFO_INVALID_OFFSET if d is NULL;
  Time is in seconds unless it is -1 (unlimited).
*/
uint16_t
vcdinf_get_timeout_offset (const PsdSelectionListDescriptor_t *d)
{
  if (NULL == d) return VCDINFO_INVALID_OFFSET;
  return uint16_from_be (d->timeout_ofs);
}

/*!
  Get timeout wait time value for PsdPlayListDescriptor *d.
  Time is in seconds unless it is -1 (unlimited).
*/
int
vcdinf_get_timeout_time (const PsdSelectionListDescriptor_t *d)
{
  return vcdinfo_get_wait_time (d->totime);
}

/*!
  Return the track number for entry n in obj. The first track starts
  at 1. Note this is one less than the track number reported in vcddump.
  (We don't count the header track?)
*/
track_t
vcdinf_get_track(const EntriesVcd_t *entries, const unsigned int entry_num)
{
  const unsigned int entry_count = uint16_from_be (entries->entry_count);
  /* Note entry_num is 0 origin. */
  return entry_num < entry_count ?
    cdio_from_bcd8 (entries->entry[entry_num].n):
    VCDINFO_INVALID_TRACK;
}

/*!
  Return the VCD volume count - the number of CD's in the collection.
*/
unsigned int 
vcdinf_get_volume_count(const InfoVcd_t *info) 
{
  if (NULL==info) return 0;
  return(uint16_from_be( info->vol_count));
}

/*!
  Return the VCD volume num - the number of the CD in the collection.
  This is a number between 1 and the volume count.
*/
unsigned int
vcdinf_get_volume_num(const InfoVcd_t *info)
{
  if (NULL == info) return 0;
  return uint16_from_be(info->vol_id);
}

/*!
  Get wait time value for PsdPlayListDescriptor *d.
  Time is in seconds unless it is -1 (unlimited).
*/
int
vcdinf_get_wait_time (const PsdPlayListDescriptor_t *d) 
{
  return vcdinfo_get_wait_time (d->wtime);
}

/*!
  Return true if loop has a jump delay
*/
bool
vcdinf_has_jump_delay (const PsdSelectionListDescriptor_t *psd) 
{
  if (NULL==psd) return false;
  return ((0x80 & psd->loop) != 0);
}
  
/*! 
  Comparison routine used in sorting. We compare LIDs and if those are 
  equal, use the offset.
  Note: we assume an unassigned LID is 0 and this compares as a high value.
  
  NOTE: Consider making static.
*/
int
vcdinf_lid_t_cmp (vcdinfo_offset_t *a, vcdinfo_offset_t *b)
{
  if (a->lid && b->lid)
    {
      if (a->lid > b->lid) return +1;
      if (a->lid < b->lid) return -1;
      vcd_warn ("LID %d at offset %d has same nunber as LID of offset %d", 
                a->lid, a->offset, b->offset);
    } 
  else if (a->lid) return -1;
  else if (b->lid) return +1;

  /* Failed to sort on LID, try offset now. */

  if (a->offset > b->offset) return +1;
  if (a->offset < b->offset) return -1;
  
  /* LIDS and offsets are equal. */
  return 0;
}

/* Get the LID from a given play-list descriptor. 
   VCDINFO_REJECTED_MASK is returned d on error or pld is NULL. 
*/
lid_t
vcdinf_pld_get_lid(const PsdPlayListDescriptor_t *pld)
{
  return (pld != NULL) 
    ? uint16_from_be (pld->lid) & VCDINFO_LID_MASK
    : VCDINFO_REJECTED_MASK;
}

/**
 \fn vcdinfo_pld_get_next_offset(const PsdPlayListDescriptor *pld); 
 \brief  Get next offset for a given PSD selector descriptor.  
 \return  VCDINFO_INVALID_OFFSET is returned on error or if pld has no "next"
 entry or pld is NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_pld_get_next_offset(const PsdPlayListDescriptor_t *pld)
{
  if (NULL == pld) return VCDINFO_INVALID_OFFSET;
  return uint16_from_be (pld->next_ofs);
}

/*!
  Return number of items in LIDs. Return 0 if error or not found.
*/
int 
vcdinf_pld_get_noi (const PsdPlayListDescriptor_t *pld)
{
  if ( NULL == pld ) return 0;
  return pld->noi;
}

/*!
  Return the playlist item i in d. 
*/
uint16_t
vcdinf_pld_get_play_item(const PsdPlayListDescriptor_t *pld, unsigned int i)
{
  if (NULL==pld) return 0;
  return uint16_from_be(pld->itemid[i]);
}

/**
 \fn vcdinf_pld_get_prev_offset(const PsdPlayListDescriptor *pld);
 \brief Get prev offset for a given PSD selector descriptor. 
 \return  VCDINFO_INVALID_OFFSET is returned on error or if pld has no "prev"
 entry or pld is NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_pld_get_prev_offset(const PsdPlayListDescriptor_t *pld)
{
  return (pld != NULL) ? 
    uint16_from_be (pld->prev_ofs) : VCDINFO_INVALID_OFFSET;
}

/**
 \fn vcdinf_pld_get_return_offset(const PsdPlayListDescriptor *pld);
 \brief Get return offset for a given PLD selector descriptor. 
 \return  VCDINFO_INVALID_OFFSET is returned on error or if pld has no 
 "return" entry or pld is NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_pld_get_return_offset(const PsdPlayListDescriptor_t *pld)
{
  return (pld != NULL) ? 
    uint16_from_be (pld->return_ofs) : VCDINFO_INVALID_OFFSET;
}

/**
 * \fn vcdinfo_psd_get_default_offset(const PsdSelectionListDescriptor *psd);
 * \brief Get next offset for a given PSD selector descriptor. 
 * \return VCDINFO_INVALID_OFFSET is returned on error or if psd is
 * NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_psd_get_default_offset(const PsdSelectionListDescriptor_t *psd)
{
  if (NULL == psd) return VCDINFO_INVALID_OFFSET;
  return uint16_from_be (psd->default_ofs);
}

/*!
  Get the item id for a given selection-list descriptor. 
  VCDINFO_REJECTED_MASK is returned on error or if psd is NULL. 
*/
uint16_t
vcdinf_psd_get_itemid(const PsdSelectionListDescriptor_t *psd)
{
  return (psd != NULL) ? uint16_from_be(psd->itemid) : VCDINFO_REJECTED_MASK;
}

/*!
  Get the LID from a given selection-list descriptor. 
  VCDINFO_REJECTED_MASK is returned on error or psd is NULL. 
*/
lid_t
vcdinf_psd_get_lid(const PsdSelectionListDescriptor_t *psd)
{
  return (psd != NULL) 
    ? uint16_from_be (psd->lid) & VCDINFO_LID_MASK
    : VCDINFO_REJECTED_MASK;
}

/*!
  Get the LID rejected status for a given PSD selector descriptor. 
  true is also returned d is NULL. 
*/
bool
vcdinf_psd_get_lid_rejected(const PsdSelectionListDescriptor_t *psd)
{
  return (psd != NULL) 
    ? vcdinfo_is_rejected(uint16_from_be(psd->lid)) 
    : true;
}

/**
 * \fn vcdinf_psd_get_next_offset(const PsdSelectionListDescriptor *psd);
 * \brief Get "next" offset for a given PSD selector descriptor. 
 * \return VCDINFO_INVALID_OFFSET is returned on error or if psd is
 * NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_psd_get_next_offset(const PsdSelectionListDescriptor_t *psd)
{
  if (NULL == psd) return VCDINFO_INVALID_OFFSET;
  return uint16_from_be (psd->next_ofs);
}

/**
 * \fn vcdinf_psd_get_offset(const PsdSelectionListDescriptor *d, 
 *                           unsigned int entry_num);
 * \brief Get offset entry_num for a given PSD selector descriptor. 
 * \return VCDINFO_INVALID_OFFSET is returned if d on error or d is
 * NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_psd_get_offset(const PsdSelectionListDescriptor_t *psd, 
                      unsigned int entry_num) 
{
  return (psd != NULL && entry_num < vcdinf_get_num_selections(psd))
    ? uint16_from_be (psd->ofs[entry_num]) : VCDINFO_INVALID_OFFSET;
}

/**
 \fn vcdinf_psd_get_prev_offset(const PsdSelectionListDescriptor *psd);
 \brief Get "prev" offset for a given PSD selector descriptor. 
 \return  VCDINFO_INVALID_OFFSET is returned on error or if psd has no "prev"
 entry or psd is NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_psd_get_prev_offset(const PsdSelectionListDescriptor_t *psd)
{
  return (psd != NULL) ? 
    uint16_from_be (psd->prev_ofs) : VCDINFO_INVALID_OFFSET;
}

/**
 * \fn vcdinf_psd_get_return_offset(const PsdSelectionListDescriptor *psd);
 * \brief Get return offset for a given PSD selector descriptor. 
 \return  VCDINFO_INVALID_OFFSET is returned on error or if psd has no 
 "return" entry or psd is NULL. Otherwise the LID offset is returned.
 */
uint16_t
vcdinf_psd_get_return_offset(const PsdSelectionListDescriptor_t *psd)
{
  return (psd != NULL) ? 
    uint16_from_be (psd->return_ofs) : VCDINFO_INVALID_OFFSET;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
