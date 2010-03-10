/*
    $Id: sector.h,v 1.2 2003/11/10 11:57:49 rocky Exp $

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

#ifndef _VCD_SECTOR_H_
#define _VCD_SECTOR_H_

#include <libvcd/types.h>

/* subheader */

/*
  
  SVCD 1.0
  ~~~~~~~~
 
   empty sector:  fn=0 cn=0 sm=%00100000 ci=0
   data sector:   fn=0 cn=0 sm=%x0001000 ci=0
   mpeg sector:   fn=1 cn=1 sm=%x11x001x ci=0x80
  
  VCD 2.0
  ~~~~~~~

   /MPEGAV/AVSEQyy.DAT
    empty sector: fn=yy cn=0 sm=%x11x000x ci=0
    video sector: fn=yy cn=1 sm=%x11x001x ci=0x0f
    audio sector: fn=yy cn=1 sm=%x11x010x ci=0x7f

   /SEGMENT/ITEMzzzz.DAT
    empty sector: fn=1 cn=0  sm=%x11x000x ci=0
    video sector: fn=1 cn=1  sm=%x11x001x ci=0x0f
    lores still:  fn=1 cn=2  sm=%x11x001x ci=0x1f
    hires still:  fn=1 cn=3  sm=%x11x001x ci=0x3f
    audio sector: fn=1 cn=1  sm=%x11x010x ci=0x7f
  
   /VCD/ *.VCD
    data sector:  fn=0 cn=0  sm=%x000100x ci=0

   *.*
    data sector:  fn=1 cn=0  sm=%x0001000 ci=0

*/

/* file numbers */

/* dynamic */

/* channel numbers */
#define CN_VIDEO   0x01
#define CN_STILL   0x02
#define CN_STILL2  0x03
#define CN_AUDIO   0x01
#define CN_AUDIO2  0x02
#define CN_OGT     0x02 /* fixme -- is it 0x04 ?? */
#define CN_PAD     0x00
#define CN_EMPTY   0x00

/* submode byte */
#define SM_EOF    (1<<7)
#define SM_REALT  (1<<6)
#define SM_FORM2  (1<<5)
#define SM_TRIG   (1<<4)
#define SM_DATA   (1<<3)
#define SM_AUDIO  (1<<2)
#define SM_VIDEO  (1<<1)
#define SM_EOR    (1<<0)

/* coding information */
#define CI_VIDEO   0x0f
#define CI_STILL   0x1f
#define CI_STILL2  0x3f
#define CI_AUDIO   0x7f
#define CI_AUDIO2  0x7f
#define CI_OGT     0x0f
#define CI_PAD     0x1f
#define CI_MPEG2   0x80
#define CI_EMPTY   0x00

/* make mode 2 form 1/2 sector
 *
 * data must be a buffer of size 2048 or 2324 for SM_FORM2
 * raw_sector must be a writable buffer of size 2352
 */
void
_vcd_make_mode2 (void *raw_sector, const void *data, uint32_t extent,
                 uint8_t fnum, uint8_t cnum, uint8_t sm, uint8_t ci);

/* ...data must be a buffer of size 2336 */

void
_vcd_make_raw_mode2 (void *raw_sector, const void *data, uint32_t extent);

#endif /* _VCD_SECTOR_H_ */


/* 
 * Local variables:
 *  c-file-style: "gnu"
 *  tab-width: 8
 *  indent-tabs-mode: nil
 * End:
 */
