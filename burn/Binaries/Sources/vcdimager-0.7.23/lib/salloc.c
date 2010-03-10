/*
    $Id: salloc.c,v 1.3 2005/02/02 00:37:37 rocky Exp $

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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <string.h>
#include <stdlib.h>

#include <cdio/cdio.h>

/* Public headers */
#include <libvcd/types.h>
#include <libvcd/logging.h>

/* Private headers */
#include "vcd_assert.h"
#include "salloc.h"
#include "util.h"

static const char _rcsid[] = "$Id: salloc.c,v 1.3 2005/02/02 00:37:37 rocky Exp $";

#define VCD_SALLOC_CHUNK_SIZE 16

struct _VcdSalloc
{
  uint8_t *data;
  uint32_t len;
  uint32_t alloced_chunks;
};

static void
_vcd_salloc_set_size (VcdSalloc *bitmap, uint32_t newlen)
{
  uint32_t new_alloced_chunks;

  vcd_assert (bitmap != NULL);
  vcd_assert (newlen >= bitmap->len);

  new_alloced_chunks = newlen / VCD_SALLOC_CHUNK_SIZE;
  if (newlen % VCD_SALLOC_CHUNK_SIZE)
    new_alloced_chunks++;

  if (bitmap->alloced_chunks < new_alloced_chunks)
    {
      bitmap->data =
        realloc (bitmap->data, new_alloced_chunks * VCD_SALLOC_CHUNK_SIZE);
      memset (bitmap->data + (VCD_SALLOC_CHUNK_SIZE * bitmap->alloced_chunks),
              0,
              VCD_SALLOC_CHUNK_SIZE * (new_alloced_chunks -
                                       bitmap->alloced_chunks));
      bitmap->alloced_chunks = new_alloced_chunks;
    }

  bitmap->len = newlen;
}

static bool
_vcd_salloc_is_set (const VcdSalloc *bitmap, uint32_t sector)
{
  unsigned _byte = sector / 8;
  unsigned _bit = sector % 8;

  if (_byte < bitmap->len)
    return (bitmap->data[_byte] & (1 << _bit)) != 0;
  else
    return false;
}

static void
_vcd_salloc_set (VcdSalloc *bitmap, uint32_t sector)
{
  unsigned _byte = sector / 8;
  unsigned _bit = sector % 8;

  if (_byte >= bitmap->len)
    {
      unsigned oldlen = bitmap->len;
      _vcd_salloc_set_size (bitmap, _byte + 1);
      memset (bitmap->data + oldlen, 0x00, _byte + 1 - oldlen);
    }

  bitmap->data[_byte] |= (1 << _bit);
}

static void
_vcd_salloc_unset (VcdSalloc *bitmap, uint32_t sector)
{
  unsigned _byte = sector / 8;
  unsigned _bit = sector % 8;

  if (_byte >= bitmap->len)
    vcd_assert_not_reached ();

  bitmap->data[_byte] &= ~(1 << _bit);
}

/* exported */

uint32_t _vcd_salloc (VcdSalloc *bitmap, uint32_t hint, uint32_t size)
{
  if (!size)
    {
      size++;
      vcd_warn
        ("request of 0 sectors allocment fixed up to 1 sector (this is harmless)");
    }

  vcd_assert (size > 0);

  if (hint != SECTOR_NIL)
    {
      uint32_t i;
      for (i = 0; i < size; i++)
        if (_vcd_salloc_is_set (bitmap, hint + i))
          return SECTOR_NIL;

      /* everything's ok for allocing */

      i = size;
      while (i)
        _vcd_salloc_set (bitmap, hint + (--i));
      /* we begin with highest byte, in order to minimizing
         realloc's in sector_set */

      return hint;
    }

  /* find the lowest possible ... */

  hint = 0;

  while (_vcd_salloc (bitmap, hint, size) == SECTOR_NIL)
    hint++;

  return hint;
}

void
_vcd_salloc_free (VcdSalloc *bitmap, uint32_t sec, uint32_t size)
{
  uint32_t i;

  for (i = 0; i < size; i++) 
    {
      vcd_assert (_vcd_salloc_is_set (bitmap, sec + i));
      
      _vcd_salloc_unset (bitmap, sec + i);
    }
}

VcdSalloc *
_vcd_salloc_new (void)
{
  VcdSalloc *newobj = calloc(1, sizeof (VcdSalloc));
  return newobj;
}

void
_vcd_salloc_destroy (VcdSalloc *bitmap)
{
  vcd_assert (bitmap != NULL);

  free (bitmap->data);
  free (bitmap);
}

uint32_t _vcd_salloc_get_highest (const VcdSalloc *bitmap)
{
  uint8_t last;
  unsigned n;

  vcd_assert (bitmap != NULL);

  last = bitmap->data[bitmap->len - 1];

  vcd_assert (last != 0);

  n = 8;
  while (n)
    if ((1 << --n) & last)
      break;

  return (bitmap->len - 1) * 8 + n;
}


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
