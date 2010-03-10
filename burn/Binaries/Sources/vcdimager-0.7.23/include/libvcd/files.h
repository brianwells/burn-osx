/*
    $Id: files.h,v 1.3 2005/05/08 03:48:55 rocky Exp $

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

#ifndef VCDFILES_H
#define VCDFILES_H

#include <libvcd/types.h>

#define INFO_VCD_SECTOR    150
#define ENTRIES_VCD_SECTOR 151
#define LOT_VCD_SECTOR     152
#define LOT_VCD_SIZE       32
#define PSD_VCD_SECTOR     (LOT_VCD_SECTOR+LOT_VCD_SIZE)

#define MAX_SEGMENTS       1980
#define MAX_ENTRIES        500
#define MAX_SEQ_ENTRIES    99

/* these are used for SVCDs only */
#define TRACKS_SVD_SECTOR  (PSD_VCD_SECTOR+1)
#define SEARCH_DAT_SECTOR  (TRACKS_SVD_SECTOR+1)

/* Maximum index of optional LOT.VCD (the List ID Offset Table.) */
#define LOT_VCD_OFFSETS ((1 << 15)-1)

typedef enum {
  PSD_TYPE_PLAY_LIST = 0x10,        /* Play List */
  PSD_TYPE_SELECTION_LIST = 0x18,   /* Selection List (+Ext. for SVCD) */
  PSD_TYPE_EXT_SELECTION_LIST = 0x1a, /* Extended Selection List (VCD2.0) */
  PSD_TYPE_END_LIST = 0x1f,         /* End List */
  PSD_TYPE_COMMAND_LIST = 0x20      /* Command List */
} psd_descriptor_types;

#define ENTRIES_ID_VCD  "ENTRYVCD"
#define ENTRIES_ID_VCD3 "ENTRYSVD"
#define ENTRIES_ID_SVCD "ENTRYVCD" /* not ENTRYSVD! */

#define SCANDATA_VERSION_VCD2 0x02
#define SCANDATA_VERSION_SVCD 0x01

void
set_entries_vcd(VcdObj_t *p_vcdobj, void *p_buf);

void 
set_info_vcd (VcdObj_t *p_vcdobj, void *p_buf);

uint32_t
get_psd_size (VcdObj_t *p_vcdobj, bool extended);

void
set_lot_vcd (VcdObj_t *p_vcdobj, void *p_buf, bool extended);

void
set_psd_vcd (VcdObj_t *p_vcdobj, void *p_buf, bool extended);

void
set_tracks_svd (VcdObj_t *p_vcdobj, void *p_buf);

uint32_t 
get_search_dat_size (const VcdObj_t *p_vcdobj);

void
set_search_dat (VcdObj_t *p_vcdobj, void *p_buf);

uint32_t 
get_scandata_dat_size (const VcdObj_t *p_vcdobj);

void
set_scandata_dat (VcdObj_t *p_vcdobj, void *p_buf);


vcd_type_t
vcd_files_info_detect_type (const void *info_buf);

#endif /* VCDFILES_H */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
