/*
    $Id: pbc.h,v 1.7 2005/06/18 03:27:24 rocky Exp $

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

#ifndef __VCD_PBC_H__
#define __VCD_PBC_H__

#include <libvcd/types.h>

/* Private includes */
#include "data_structures.h"
#include "util.h"
#include "vcd.h"

typedef enum {
  PBC_INVALID = 0,
  PBC_PLAYLIST,
  PBC_SELECTION,
  PBC_END
} pbc_type_t;

typedef struct psd_area_t pbc_area_t; /* fixme */
#define pbc_area_t_SIZEOF struct_psd_area_t_SIZEOF

static inline pbc_area_t *
vcd_pbc_area_new (uint8_t x1, uint8_t y1, uint8_t x2, uint8_t y2)
{
  pbc_area_t *_new_area = calloc(1, sizeof (pbc_area_t));

  _new_area->x1 = x1;
  _new_area->y1 = y1;
  _new_area->x2 = x2;
  _new_area->y2 = y2;

  return _new_area;
}

/* typedef struct _pbc_t pbc_t; */

struct _pbc_t {
  pbc_type_t type;

  char *id;

  bool rejected;

  /* pbc ref check */
  bool referenced;

  /* used for play/selection lists */
  char *prev_id;
  char *next_id;
  char *retn_id;

  /* used for play lists */
  double playing_time;
  int wait_time;
  int auto_pause_time;
  CdioList_t *item_id_list; /* char */

  /* used for selection lists */
  enum selection_type_t {
    _SEL_NORMAL = 0,
    _SEL_MULTI_DEF,
    _SEL_MULTI_DEF_NO_NUM
  } selection_type;

  pbc_area_t *prev_area;
  pbc_area_t *next_area;
  pbc_area_t *return_area;
  pbc_area_t *default_area; /* depends on selection_type */
  CdioList_t *select_area_list; /* pbc_area_t */

  unsigned bsn;
  char *default_id;
  char *timeout_id;
  int timeout_time;
  unsigned loop_count;
  bool jump_delayed;
  char *item_id;
  CdioList_t *select_id_list; /* char */

  /* used for end lists */
  char *image_id;
  unsigned next_disc;

  /* computed values */
  unsigned lid;
  unsigned offset;
  unsigned offset_ext;
};

enum item_type_t {
  ITEM_TYPE_NOTFOUND = 0,
  ITEM_TYPE_NOOP,
  ITEM_TYPE_TRACK,
  ITEM_TYPE_ENTRY,
  ITEM_TYPE_SEGMENT,
  ITEM_TYPE_PBC
};

/* functions */

pbc_t *
vcd_pbc_new (pbc_type_t type);

pbc_t *
_vcd_pbc_init (pbc_t *p_pbc);

void
vcd_pbc_destroy (pbc_t *p_pbc);

unsigned
_vcd_pbc_lid_lookup (const VcdObj_t *p_obj, const char item_id[]);

enum item_type_t
_vcd_pbc_lookup (const VcdObj_t *p_obj, const char item_id[]);

uint16_t
_vcd_pbc_pin_lookup (const VcdObj_t *p_obj, const char item_id[]);

unsigned 
_vcd_pbc_list_calc_size (const pbc_t *_pbc, bool b_extended);

bool
_vcd_pbc_finalize (VcdObj_t *p_obj);

bool
_vcd_pbc_available (const VcdObj_t *p_obj);

uint16_t
_vcd_pbc_max_lid (const VcdObj_t *p_obj);

void
_vcd_pbc_node_write (const VcdObj_t *p_obj, const pbc_t *_pbc, void *p_buf,
		     bool b_extended);

void
_vcd_pbc_check_unreferenced (const VcdObj_t *p_obj);

#endif /* __VCD_PBC_H__ */
