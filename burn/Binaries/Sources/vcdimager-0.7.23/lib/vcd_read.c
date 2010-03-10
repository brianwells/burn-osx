/*
    $Id: vcd_read.c,v 1.5 2005/06/09 07:54:52 rocky Exp $

    Copyright (C) 2001,2003 Herbert Valerio Riedel <hvr@gnu.org>
    Copyright (C) 2003 Rocky Bernstein <rocky@gnu.org>

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


#include "vcd_read.h"
#include "vcd_assert.h"
#include <libvcd/inf.h>
#include <libvcd/files.h>
#include <libvcd/logging.h>

#ifdef HAVE_STRING_H
#include <string.h>
#endif

bool 
read_pvd(CdIo_t *cdio, iso9660_pvd_t *pvd) 
{
  if (cdio_read_mode2_sector (cdio, pvd, ISO_PVD_SECTOR, false)) {
    vcd_error ("error reading PVD sector (%d)", ISO_PVD_SECTOR);
    return false;
  }
  
  if (pvd->type != ISO_VD_PRIMARY) {
    vcd_error ("unexpected PVD type %d", pvd->type);
    return false;
  }
  
  if (memcmp (pvd->id, ISO_STANDARD_ID, sizeof (ISO_STANDARD_ID)))
    {
      vcd_error ("unexpected ID encountered (expected `"
		ISO_STANDARD_ID "', got `%.5s'", pvd->id);
      return false;
    }
  return true;
}

bool 
read_entries(CdIo_t *cdio, EntriesVcd_t *entries) 
{
  if (cdio_read_mode2_sector (cdio, entries, ENTRIES_VCD_SECTOR, false)) {
    vcd_error ("error reading Entries sector (%d)", ENTRIES_VCD_SECTOR);
    return false;
  }

  /* analyze signature/type */

  if (!strncmp (entries->ID, ENTRIES_ID_VCD, sizeof (entries->ID)))
    return true;
  else if (!strncmp (entries->ID, "ENTRYSVD", sizeof (entries->ID))) {
    vcd_warn ("found (non-compliant) SVCD ENTRIES.SVD signature");
    return true;
  }  else {
    vcd_error ("unexpected ID signature encountered `%.8s'", entries->ID);
    return false;
  }
}

bool 
read_info(CdIo_t *cdio, InfoVcd_t *info, vcd_type_t *vcd_type) 
{
  if (cdio_read_mode2_sector (cdio, info, INFO_VCD_SECTOR, false)) {
    vcd_error ("error reading Info sector (%d)", INFO_VCD_SECTOR);
    return false;
  }

  *vcd_type = vcd_files_info_detect_type (info);

  /* analyze signature/type */

  switch (*vcd_type)
    {
    case VCD_TYPE_VCD:
    case VCD_TYPE_VCD11:
    case VCD_TYPE_VCD2:
    case VCD_TYPE_SVCD:
    case VCD_TYPE_HQVCD:
      vcd_debug ("%s detected", vcdinf_get_format_version_str(*vcd_type));
      break;
    case VCD_TYPE_INVALID:
      vcd_error ("unknown ID encountered -- maybe not a proper (S)VCD?");
      return false;
      break;
    default:
      vcd_assert_not_reached ();
      break;
    }

  return true;
}

