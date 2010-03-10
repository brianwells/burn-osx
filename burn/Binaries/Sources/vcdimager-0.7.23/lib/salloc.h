/*
    $Id: salloc.h,v 1.2 2003/11/10 11:57:50 rocky Exp $

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

/* sector allocation management */

#ifndef _SALLOC_H_
#define _SALLOC_H_

#include <libvcd/types.h>

#define SECTOR_NIL ((uint32_t)(-1))

typedef struct _VcdSalloc VcdSalloc;

VcdSalloc *
_vcd_salloc_new (void);

void
_vcd_salloc_destroy (VcdSalloc *bitmap);

uint32_t
_vcd_salloc (VcdSalloc *bitmap, uint32_t hint, uint32_t size);

void
_vcd_salloc_free (VcdSalloc *bitmap, uint32_t sec, uint32_t size);

uint32_t
_vcd_salloc_get_highest (const VcdSalloc *bitmap);

#endif /* _SALLOC_H_ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
