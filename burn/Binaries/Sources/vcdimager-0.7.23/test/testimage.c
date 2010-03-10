/*
    $Id: testimage.c,v 1.3 2005/02/02 00:37:38 rocky Exp $

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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <cdio/cdio.h>

/* Public headers */
#include <libvcd/logging.h>

/* Private headers */
#include "vcd_assert.h"
#include "util.h"


int
main (int argc, const char *argv[])
{
  CdIo_t *img = NULL;
  lsn_t lsn = 0;

  vcd_assert (argc == 4);

  if (!strcmp ("nrg", argv[1]))
    img = cdio_open_nrg (argv[2]);
  else if (!strcmp ("bincue", argv[1]))
    img = cdio_open_bincue (argv[2]) /* src, NULL, false) */; 
  else if (!strcmp ("cd", argv[1]))
    img = cdio_open_cd (argv[2]) /* argv[2]) */;
  else 
    vcd_error ("unrecognized img type");

  vcd_assert (img != NULL);

  {
    uint32_t n = cdio_stat_size (img);
    char buf[M2RAW_SECTOR_SIZE];
    lsn = atoi (argv[3]);

    vcd_debug ("size = %lu", (unsigned long int) n);

    vcd_debug ("reading sector %lu to testimage.out", (unsigned long int) lsn);
    
    if (!cdio_read_mode2_sector (img, buf, lsn, true))
      {
	struct m2f2sector
	{
	  uint8_t subheader[8];
	  uint8_t data[2324];
	  uint8_t spare[4];
	}
	*_sect = (void *) buf;
	FILE *fd;

	vcd_debug ("fn = %d, cn = %d, sm = 0x%x, ci = 0x%x",
		   _sect->subheader[0],
		   _sect->subheader[1],
		   _sect->subheader[2],
		   _sect->subheader[3]);

	fd = fopen ("testimage.out", "wb");
	fwrite (buf, sizeof (buf), 1, fd);
	fclose (fd);

	/* vcd_assert_not_reached (); */
      }
    else
      vcd_error ("failed...");

    
  }

  return 0;
}
