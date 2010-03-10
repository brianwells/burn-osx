/*!
   \file inf.h

    Copyright (C) 2002, 2003, 2004 Rocky Bernstein <rocky@panix.com>

 \verbatim
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
 \endverbatim
*/

/* 
   Things here refer to lower-level structures using a structure other
   than vcdinfo_t. For higher-level structures via the vcdinfo_t, see
   info.h
*/

#ifndef _VCD_INF_H
#define _VCD_INF_H

#include <libvcd/info.h>
  
  const char * vcdinf_area_str (const struct psd_area_t *_area);

  /*!
    Return a string containing the VCD album id.
  */
  const char * vcdinf_get_album_id(const InfoVcd_t *info);

  /*!
    Get autowait time value for PsdPlayListDescriptor *d.
    Time is in seconds unless it is -1 (unlimited).
  */
  int vcdinf_get_autowait_time (const PsdPlayListDescriptor_t *d);
  
  /*!
    Return the base selection number. VCD_INVALID_BSN is returned if there
    is an error.
  */
  unsigned int vcdinf_get_bsn(const PsdSelectionListDescriptor_t *psd);
  
  /*!  Return the starting LBA (logical block address) for sequence
    entry_num in obj.  VCDINFO_NULL_LBA is returned if there is no entry.
    The first entry number is 0.
  */
  lba_t vcdinf_get_entry_lba(const EntriesVcd_t *entries, 
			     unsigned int entry_num);

  const char * vcdinf_get_format_version_str (vcd_type_t vcd_type);

  /*!
    Return loop count. 0 is infinite loop.
  */
  uint16_t vcdinf_get_loop_count (const PsdSelectionListDescriptor_t *psd);
  
  /*!
    Return LOT offset
  */
  uint16_t vcdinf_get_lot_offset (const LotVcd_t *lot, unsigned int n);

  /*!
    Return number of bytes in PSD. 
  */
  uint32_t vcdinf_get_psd_size (const InfoVcd_t *info);
       
  /*!
    Return the number of segments in the VCD. 
  */
  unsigned int vcdinf_get_num_entries(const EntriesVcd_t *entries);

  /*!
    Return number of LIDs. 
  */
  lid_t vcdinf_get_num_LIDs (const InfoVcd_t *info);

  /*!
    Return the number of segments in the VCD. 
  */
  segnum_t vcdinf_get_num_segments(const InfoVcd_t *info);

  /*!
    Return the number of menu selections for selection-list descriptor d.
  */
  unsigned int vcdinf_get_num_selections(const PsdSelectionListDescriptor_t *d);

  /*!
    Get play-time value for PsdPlayListDescriptor *d.
    Time is in 1/15-second units.
  */
  uint16_t vcdinf_get_play_time (const PsdPlayListDescriptor_t *d);
  
  /*!
    Get timeout offset for PsdPlayListDescriptor *d. Return 
    VCDINFO_INVALID_OFFSET if d is NULL;
    Time is in seconds unless it is -1 (unlimited).
  */
  uint16_t vcdinf_get_timeout_offset (const PsdSelectionListDescriptor_t *d);
  
  /*!
    Get timeout wait value for PsdPlayListDescriptor *d.
    Time is in seconds unless it is -1 (unlimited).
  */
  int vcdinf_get_timeout_time (const PsdSelectionListDescriptor_t *d);
  
  /*!
    Return the track number for entry n in obj. The first track starts
    at 1. 
  */
  track_t vcdinf_get_track(const EntriesVcd_t *entries, 
			   const unsigned int entry_num);

  /*!
    Return the VCD volume num - the number of the CD in the collection.
    This is a number between 1 and the volume count.
  */
  unsigned int vcdinf_get_volume_num(const InfoVcd_t *info);
  
  /*!
    Return the VCD volume count - the number of CD's in the collection.
  */
  unsigned int vcdinf_get_volume_count(const InfoVcd_t *info);

  /*!
    Get wait time value for PsdPlayListDescriptor *d.
    Time is in seconds unless it is -1 (unlimited).
  */
  int vcdinf_get_wait_time (const PsdPlayListDescriptor_t *d);
  
  /*!
    Return true if loop has a jump delay
  */
  bool vcdinf_has_jump_delay (const PsdSelectionListDescriptor_t *psd);

  /*!
    Comparison routine used in sorting. We compare LIDs and if those are 
    equal, use the offset.
    Note: we assume an unassigned LID is 0 and this compares as a high value.

    NOTE: Consider making static.
  */
  int vcdinf_lid_t_cmp (vcdinfo_offset_t *a, vcdinfo_offset_t *b);

  /**
     \brief  Get next offset for a given PSD selector descriptor.  
     \return  VCDINFO_INVALID_OFFSET is returned on error or if pld has no 
     "next" entry or pld is NULL. Otherwise the LID offset is returned.
  */
  uint16_t vcdinf_pld_get_next_offset(const PsdPlayListDescriptor_t *pld);
  
  /*!
    Get the LID from a given play-list descriptor. 
    VCDINFO_REJECTED_MASK is returned on error or pld is NULL. 
  */
  uint16_t vcdinf_pld_get_lid(const PsdPlayListDescriptor_t *pld);
  
  /*!
    Return the playlist item i in d. 
  */
  uint16_t vcdinf_pld_get_play_item(const PsdPlayListDescriptor_t *pld, 
				    unsigned int i);

  /**
     \brief Get prev offset for a given PSD selector descriptor. 
     \return  VCDINFO_INVALID_OFFSET is returned on error or if pld has no 
     "prev" entry or pld is NULL. Otherwise the LID offset is returned.
  */
  uint16_t vcdinf_pld_get_prev_offset(const PsdPlayListDescriptor_t *pld);
  
  /**
     \brief Get return offset for a given PLD selector descriptor. 
     \return  VCDINFO_INVALID_OFFSET is returned on error or if pld has no 
     "return" entry or pld is NULL. Otherwise the LID offset is returned.
  */
  uint16_t vcdinf_pld_get_return_offset(const PsdPlayListDescriptor_t *pld);

  /*!
    Return number of items in LIDs. Return 0 if error or not found.
  */
  int vcdinf_pld_get_noi (const PsdPlayListDescriptor_t *pld);
  
  /**
   * \brief Get next offset for a given PSD selector descriptor. 
   * \return VCDINFO_INVALID_OFFSET is returned on error or if psd is
   * NULL. Otherwise the LID offset is returned.
   */
  uint16_t vcdinf_psd_get_default_offset(const PsdSelectionListDescriptor_t *psd);

  /*!
    Get the item id for a given selection-list descriptor. 
    VCDINFO_REJECTED_MASK is returned on error or if psd is NULL. 
  */
  uint16_t vcdinf_psd_get_itemid(const PsdSelectionListDescriptor_t *psd);

  /*!
    Get the LID from a given selection-list descriptor. 
    VCDINFO_REJECTED_MASK is returned on error or psd is NULL. 
  */
  uint16_t vcdinf_psd_get_lid(const PsdSelectionListDescriptor_t *psd);
  
  /*!
    Get the LID rejected status for a given selection-list descriptor. 
  true is also returned d is NULL. 
  */
  bool
  vcdinf_psd_get_lid_rejected(const PsdSelectionListDescriptor_t *psd);
  
  /**
     \brief Get "next" offset for a given PSD selector descriptor. 
     \return  VCDINFO_INVALID_OFFSET is returned on error or if psd has no 
     "next" entry or psd is NULL. Otherwise the LID offset is returned.
  */
  lid_t vcdinf_psd_get_next_offset(const PsdSelectionListDescriptor_t *psd);
  
  /*!
    \brief Get offset entry_num for a given PSD selector descriptor. 
    \param d PSD selector containing the entry_num we query
    \param entry_num entry number that we want the LID offset for.
    \return VCDINFO_INVALID_OFFSET is returned if d on error or d is
  NULL. Otherwise the LID offset is returned.
  */
  uint16_t vcdinf_psd_get_offset(const PsdSelectionListDescriptor_t *d, 
				 unsigned int entry_num);
  /**
     \brief Get "prev" offset for a given PSD selector descriptor. 
     \return  VCDINFO_INVALID_OFFSET is returned on error or if psd has no 
     "prev"
     entry or psd is NULL. Otherwise the LID offset is returned.
  */
  uint16_t vcdinf_psd_get_prev_offset(const PsdSelectionListDescriptor_t *psd);
  
  /**
   \brief Get "return" offset for a given PSD selector descriptor. 
   \return  VCDINFO_INVALID_OFFSET is returned on error or if psd has no 
   "return" entry or psd is NULL. Otherwise the LID offset is returned.
  */
  uint16_t vcdinf_psd_get_return_offset(const PsdSelectionListDescriptor_t *psd);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /*_VCD_INF_H*/
