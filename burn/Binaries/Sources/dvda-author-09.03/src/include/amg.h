/*

File:    amg.h
Purpose: Create an Audio Manager (AUDIO_TS.IFO)

dvda-author  - Author a DVD-Audio DVD

(C) Dave Chapman <dave@dchapman.com> 2005

The latest version can be found at http://dvd-audio.sourceforge.net

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
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

*/

#ifndef _AMG_H
#define _AMG_H

#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>

#include "audio2.h"

int create_amg(char* audiotsdir, fileinfo_t** files, int* ntracks, int ngroups, int vgroups, int* atsi_sectors, uint32_t *videotitlelength, int * VTSI_rank, uint32_t* relative_sector_pointer_VTSI);

#endif
