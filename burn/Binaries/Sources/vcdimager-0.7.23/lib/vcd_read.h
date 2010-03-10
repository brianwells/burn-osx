/*
    $Id: vcd_read.h,v 1.4 2005/04/28 10:19:47 rocky Exp $

    Copyright (C) 2003, 2005 Rocky Bernstein <rocky@gnu.org>

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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <cdio/cdio.h>
#include <cdio/iso9660.h>

/* FIXME: make this really private: */
#include <libvcd/files_private.h>

bool read_pvd(CdIo_t *p_cdio, iso9660_pvd_t *pvd);
bool read_entries(CdIo_t *p_cdio, EntriesVcd_t *entries);
bool read_info(CdIo_t *p_cdio, InfoVcd_t *info, vcd_type_t *vcd_type);



