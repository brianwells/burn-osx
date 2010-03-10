/*
    $Id: bitvec.h,v 1.2 2003/11/10 11:57:49 rocky Exp $

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

#ifndef __VCD_BITVEC_H__
#define __VCD_BITVEC_H__

#include <libvcd/types.h>

#include "vcd_assert.h"

static inline bool
_vcd_bit_set_p (const uint32_t n, const unsigned bit)
{
  return ((n >> bit) & 0x1) == 0x1;
}

static inline int
vcd_bitvec_align (int value, const int boundary)
{
  if (value % boundary)
    value += (boundary - (value % boundary));

  return value;
}

/*
 * PEEK 
 */

#define vcd_bitvec_peek_bits16(bitvec, offset) \
 vcd_bitvec_peek_bits ((bitvec), (offset), 16)

static inline uint32_t 
vcd_bitvec_peek_bits (const uint8_t bitvec[],
		      const unsigned offset, 
		      const unsigned bits)
{
  uint32_t result = 0;
  unsigned i = offset;

  vcd_assert (bits > 0 && bits <= 32);

#if 0
  j = 0;
  while (j < bits)
    if (i % 8 || (bits - j) < 8)
      {
	result <<= 1;
	if (_vcd_bit_set_p (bitvec[i >> 3], 7 - (i % 8)))
	  result |= 0x1;
	j++, i++;
      }
    else
      {
	result <<= 8;
	result |= bitvec[i >> 3];
	j += 8, i += 8;
      }
#else
  if (!(offset % 8) && !(bits % 8)) /* optimization */
    for (i = offset; i < (offset + bits); i+= 8)
      {
        result <<= 8;
        result |= bitvec[i >> 3];
      }
  else /* general case */
    for (i = offset; i < (offset + bits); i++)
      {
        result <<= 1;
        if (_vcd_bit_set_p (bitvec[i >> 3], 7 - (i % 8)))
          result |= 0x1;
      }
#endif  

  return result;
}

static inline uint32_t 
vcd_bitvec_peek_bits32 (const uint8_t bitvec[], unsigned offset)
{
  if (offset % 8)
    return vcd_bitvec_peek_bits (bitvec, offset, 32);

  offset >>= 3;

  return (bitvec[offset] << 24 
	  | bitvec[offset + 1] << 16
	  | bitvec[offset + 2] << 8
	  | bitvec[offset + 3]);
}

/* 
 * READ
 */

static inline uint32_t 
vcd_bitvec_read_bits (const uint8_t bitvec[], unsigned *offset, const unsigned bits)
{
  const unsigned i = *offset;
  
  *offset += bits;

  return vcd_bitvec_peek_bits (bitvec, i, bits);
}

static inline bool
vcd_bitvec_read_bit (const uint8_t bitvec[], unsigned *offset)
{
  const unsigned i = (*offset)++;

  return _vcd_bit_set_p (bitvec[i >> 3], 7 - (i % 8));
}

#endif /* __VCD_BITVEC_H__ */
