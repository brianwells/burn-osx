/*
    $Id: util.h,v 1.3 2005/02/02 00:37:37 rocky Exp $

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

#ifndef __VCD_UTIL_H__
#define __VCD_UTIL_H__

#include <stdlib.h>
#include <libvcd/types.h>

static inline unsigned
_vcd_len2blocks (unsigned len, int blocksize)
{
  unsigned blocks;

  blocks = len / blocksize;
  if (len % blocksize)
    blocks++;

  return blocks;
}

/* round up to next block boundary */
static inline unsigned 
_vcd_ceil2block (unsigned offset, int blocksize)
{
  return _vcd_len2blocks (offset, blocksize) * blocksize;
}

static inline unsigned 
_vcd_ofs_add (unsigned offset, unsigned length, int blocksize)
{
  if (blocksize - (offset % blocksize) < length)
    offset = _vcd_ceil2block (offset, blocksize);

  offset += length;

  return offset;
}

size_t
_vcd_strlenv(char **str_array);

char *
_vcd_strjoin (char *strv[], unsigned count, const char delim[]);

char **
_vcd_strsplit(const char str[], char delim);

void
_vcd_strfreev(char **strv);

void *
_vcd_memdup (const void *mem, size_t count);

char *
_vcd_strdup_upper (const char str[]);

static inline const char *
_vcd_bool_str (bool b)
{
  return b ? "yes" : "no";
}

#endif /* __VCD_UTIL_H__ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
