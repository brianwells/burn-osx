/*
    $Id: types.h,v 1.4 2005/05/08 03:48:55 rocky Exp $

    Copyright (C) 2000, 2004 Herbert Valerio Riedel <hvr@gnu.org>

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

#ifndef __VCD_TYPES_H__
#define __VCD_TYPES_H__

#include <cdio/types.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */
  
  /* Opaque types ... */
  
  /* Defined fully in data_structures.c */
  typedef struct _VcdList VcdList;
  typedef struct _VcdListNode VcdListNode;
  
  /* Defined fully in files_private.h */
  typedef struct _InfoVcd_tag    InfoVcd_t;
  typedef struct _EntriesVcd_tag EntriesVcd_t;
  typedef struct _LotVcd_tag     LotVcd_t;
  
  typedef struct _PsdPlayListDescriptor_tag      PsdPlayListDescriptor_t;
  typedef struct _PsdSelectionListDescriptor_tag PsdSelectionListDescriptor_t;

  /* Overall data structure representing a VideoCD object.
     Defined fully in info_private.h. 
   */
  typedef struct _VcdObj VcdObj_t;
  
  /* enum defining supported VideoCD types */
  typedef enum
    {
      VCD_TYPE_INVALID = 0,
      VCD_TYPE_VCD,
      VCD_TYPE_VCD11,
      VCD_TYPE_VCD2,
      VCD_TYPE_SVCD,
      VCD_TYPE_HQVCD
    }
    vcd_type_t;
  
  /* The type of an playback control list ID (LID). */
  typedef uint16_t lid_t;
  
  /* The type of a segment number 0..1980 segment items possible. */
  typedef uint16_t segnum_t;
  
  /* (0,0) == upper left , (255,255) == lower right 
     setting all to zero disables area */
  PRAGMA_BEGIN_PACKED
  struct psd_area_t
  {
    uint8_t x1; /* upper left */
    uint8_t y1; /* upper left */
    uint8_t x2; /* lower right */
    uint8_t y2; /* lower right */
  } GNUC_PACKED;
  PRAGMA_END_PACKED
  
#define struct_psd_area_t_SIZEOF 4
  
#define PSD_OFS_DISABLED         0xffff
#define PSD_OFS_MULTI_DEF        0xfffe
#define PSD_OFS_MULTI_DEF_NO_NUM 0xfffd
  
#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __VCD_TYPES_H__ */

/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
