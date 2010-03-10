/*
    $Id: check_sizeof.c,v 1.4 2005/05/07 11:04:28 rocky Exp $

    Copyright (C) 2001, 2005 Herbert Valerio Riedel <hvr@gnu.org>

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

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include <cdio/iso9660.h>
#include <libvcd/types.h>
#include <libvcd/files.h>
#include <libvcd/files_private.h>
#include <libvcd/sector.h>

/* Private headers */
#include "pbc.h"
#include "sector_private.h"
#include "vcd.h"

#define CHECK_SIZEOF(typnam) { \
  printf ("checking sizeof (%s) ...", #typnam); \
  if (sizeof (typnam) != (typnam##_SIZEOF)) { \
      printf ("failed!\n==> sizeof (%s) == %d (but should be %d)\n", \
              #typnam, (int)sizeof(typnam), (int)(typnam##_SIZEOF)); \
      fail++; \
  } else { pass++; printf ("ok!\n"); } \
}

#define CHECK_SIZEOF_STRUCT(typnam) { \
  printf ("checking sizeof (struct %s) ...", #typnam); \
  if (sizeof (struct typnam) != (struct_##typnam##_SIZEOF)) { \
      printf ("failed!\n==> sizeof (struct %s) == %d (but should be %d)\n", \
              #typnam, (int)sizeof(struct typnam), (int)(struct_##typnam##_SIZEOF)); \
      fail++; \
  } else { pass++; printf ("ok!\n"); } \
}

int main (int argc, const char *argv[])
{
  unsigned fail = 0, pass = 0;

  /* vcd_types.h */
  CHECK_SIZEOF(msf_t);

  /* vcd_pbc.h */
  CHECK_SIZEOF_STRUCT(psd_area_t);
  CHECK_SIZEOF(pbc_area_t);

  /* vcd_mpeg.h */
  CHECK_SIZEOF_STRUCT(vcd_mpeg_scan_data_t);

  /* vcd_files_private.h */
  CHECK_SIZEOF(EntriesVcd_t);
  CHECK_SIZEOF(InfoStatusFlags_t);
  CHECK_SIZEOF(InfoSpiContents_t);
  CHECK_SIZEOF(InfoVcd_t);
  CHECK_SIZEOF(LotVcd_t);

  CHECK_SIZEOF(PsdEndListDescriptor_t);
  CHECK_SIZEOF(PsdSelectionListFlags_t);
  CHECK_SIZEOF(PsdSelectionListDescriptor_t);
  CHECK_SIZEOF(PsdSelectionListDescriptorExtended_t);
  CHECK_SIZEOF(PsdCommandListDescriptor_t);
  CHECK_SIZEOF(PsdPlayListDescriptor_t);
  CHECK_SIZEOF(SVDTrackContent_t);
  CHECK_SIZEOF(TracksSVD_t);
  CHECK_SIZEOF(TracksSVD2_t);
  CHECK_SIZEOF(TracksSVD_v30_t);
  CHECK_SIZEOF(SearchDat_t);
  CHECK_SIZEOF(SpicontxSvd_t);
  CHECK_SIZEOF(ScandataDat_v2_t);
  CHECK_SIZEOF(ScandataDat1_t);
  CHECK_SIZEOF(ScandataDat2_t);
  CHECK_SIZEOF(ScandataDat3_t);
  CHECK_SIZEOF(ScandataDat4_t);

  /* vcd_cd_sector_private.h */
  CHECK_SIZEOF(raw_cd_sector_t);
  CHECK_SIZEOF(sector_header_t);
  CHECK_SIZEOF(mode0_sector_t);
  CHECK_SIZEOF(mode2_form1_sector_t);
  CHECK_SIZEOF(mode2_form2_sector_t);

  if (fail)
    return 1;

  return 0;
}
