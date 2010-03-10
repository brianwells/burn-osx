/* Multichannel reference tables for buffer conversions
 *
 * Copyright Lee and Tim Feldkamp, 2008;
 * Modified by Fabrice Nicol, 20008 <fabrnicol@users.sourceforge.net>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */


#ifndef MULTICHANNEL_H_INCLUDED
#define MULTICHANNEL_H_INCLUDED
// used for multichannel encoding/decoding, in audio.c and libats2wav.c



// To enable inlining of the same function in two distinct files, it is necessary to place it in a header
// Performs permutation of buf by replacing buf[j] with associate value, depending on pits per second, channel number,
// and whether one converts to AOB or extracts from AOB.

static inline void permutation(uint8_t *buf, uint8_t *_buf, int bits_per_second_flag, uint8_t channels, short int reference_table[][6][36], int size)
{
    int j;


    for (j=0; j < size ; j++)
        _buf[j] = buf[reference_table[bits_per_second_flag][channels-1][j]];

    memcpy(buf,_buf, size);
}






#endif // MULTICHANNEL_H_INCLUDED
