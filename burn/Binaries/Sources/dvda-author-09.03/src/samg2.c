/*

File:    samg2.c
Purpose: Create an Simple Audio Manager (AUDIO_PP.IFO)

dvda-author  - Author a DVD-Audio DVD

Copyright Dave Chapman <dave@dchapman.com> 2005
Copyright Fabrice Nicol <fabnicol@users.sourceforge.net> 2007, 2008 (revisions)

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

/* Notes to revised version
*  Video Linking groups are considered to be normal groups here. However in files[...] linking groups will have
   null bit rate and sample rate, and null channel.
*  Further, the PTS tick length is null but the  presentation time stamp (PTS) is there.
*  This info should be encoded exclusively in files[...].PTS_length and files[...].first_PTS.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include <errno.h>
#include "structures.h"
#include "audio2.h"
#include "samg.h"
#include "commonvars.h"
#include "c_utils.h"
#include "auxiliary.h"


extern globalData globals;
extern unsigned int startsector;

uint32_t create_samg(char* audiotsdir, fileinfo_t ** files, int* ntracks, int ngroups, int nvideolinking_groups,   int* atsi_sectors)
{


    int i=0,j=0,g,  last_audio_group=0, last_audio_track=0;
    uint32_t absolute_sector_offset, last_sector=0;
    FILE* fpout;
    char outfile[CHAR_BUFSIZ];
    // size of SAMG is 64 sectors, 8 duplicates of matrix SAMG.
    uint8_t samg[2048*SIZE_SAMG/8];
    size_t sizeofsamg=sizeof(samg);

    memset(samg,0,sizeofsamg);
    memcpy(&samg[0],"DVDAUDIOSAPP",12);

    for (g=0; g < ngroups; g++)
        j+=ntracks[g];

    uint16_copy(&samg[12],j);
    uint16_copy(&samg[14],0x0012);

    i=16;

    /*
       absolute_sector_offset =startsector +  sizeof(AUDIO_PP.IFO)+sizeof(AUDIO_TS.IFO)+sizeof(AUDIO_TS.BUP)+sizeof(ATS_01_1.IFO)
    */

    absolute_sector_offset=(uint32_t) startsector+2*SIZE_AMG+SIZE_SAMG+atsi_sectors[0];

    /* Videolinking groups always come last (highest ranks) */

    for (g=0; g<ngroups-nvideolinking_groups; g++)
    {

        for (j=0; j<ntracks[g]; j++)
        {

            i+=2;
            samg[i]=g+1;
            i++;
            samg[i]=j+1;
            i++;

            uint32_copy(&samg[i],files[g][j].first_PTS);
            i+=4;
            uint32_copy(&samg[i],files[g][j].PTS_length);
            i+=4;
            i+=4;
            if (j==0)
            {
                samg[i]= (files[g][j].channels > 2)? 0xc0 : 0xc8;
            }
            else
            {
                samg[i]=0x48;
            }

            i++;

            if (files[g][j].channels > 2)
            {

                switch (files[g][j].bitspersample)
                {

                case 16:
                    samg[i]=0x00;
                    break;
                case 20:
                    samg[i]=0x11;
                    break;
                case 24:
                    samg[i]=0x22;
                    break;

                default:
                    EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Unsupported bit rate")
                }

            }
            else
            {

                switch (files[g][j].bitspersample)
                {

                case 16:
                    samg[i]=0x0f;
                    break;
                case 20:
                    samg[i]=0x1f;
                    break;
                case 24:
                    samg[i]=0x2f;
                    break;

                default:
                    EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Unsupported bit rate")

                }
            }


            i++;

            if (files[g][j].channels > 2)
            {

                switch (files[g][j].samplerate)
                {

                case 48000:
                    samg[i]=0x00;
                    break;
                case 96000:
                    samg[i]=0x11;
                    break;
                case 192000:
                    samg[i]=0x22;
                    break;
                case 44100:
                    samg[i]=0x88;
                    break;
                case 88200:
                    samg[i]=0x99;
                    break;
                case 176400:
                    samg[i]=0xaa;
                    break;
                default:
                    EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Unsupported bit rate")

                }
            }
            else
            {

                switch (files[g][j].samplerate)
                {

                case 48000:
                    samg[i]=0x0f;
                    break;
                case 96000:
                    samg[i]=0x1f;
                    break;
                case 192000:
                    samg[i]=0x2f;
                    break;
                case 44100:
                    samg[i]=0x8f;
                    break;
                case 88200:
                    samg[i]=0x9f;
                    break;
                case 176400:
                    samg[i]=0xaf;
                    break;
                default:
                    EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Unsupported bit rate")
                }
            }
            i++;
            samg[i]= files[g][j].cga;

            switch (files[g][j].channels)
            {
            case 1:
                samg[i]=0;
                break;
            case 2:
                samg[i]=1;
                break;
            case 3:
                samg[i]=2;
                break; // L-R-S   other 3-ch configs could be supported -- laf
            case 4:
                samg[i]=3;
                break;
            case 5:
                samg[i]=6;
                break; // other 5-ch configs could be supported -- laf
            case 6:
                samg[i]=20;
                break;
            default:
                fprintf(stderr,"ERR: samg Unsupported number of channels (%d)\n",files[g][j].channels);
                exit(0);
            }

            files[g][j].cga = samg[i];

            i+=21;
            uint32_copy(&samg[i],absolute_sector_offset+files[g][j].first_sector);
            i+=4;
            uint32_copy(&samg[i],absolute_sector_offset+files[g][j].first_sector);
            i+=4;
            uint32_copy(&samg[i],absolute_sector_offset+files[g][j].last_sector);
            i+=4;

            /* Memorizing last audio group and track processed */

            last_sector=absolute_sector_offset+files[g][j].last_sector;
        }

        /* absolute pointer to first AOB in titleset/group=
         *  		last sector of last AOB in last titleset + 1 + sizeof(ATS_(g+1)_0.BUP) + sizeof(ATS_(g+2)_0.IFO)
         */

        if (g < ngroups-nvideolinking_groups-1)
            absolute_sector_offset += files[g][ntracks[g]-1].last_sector+1
                                      +atsi_sectors[g]+atsi_sectors[g+1];


    }


    foutput("[MSG]  SAMG pointers\n       Last audio group=%d\n       Last audio track=%d\n       Absolute sector pointer to last AOB sector=%"PRIu32"\n", last_audio_group, last_audio_track, last_sector);

    STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/AUDIO_PP.IFO", audiotsdir)

    fpout=fopen(outfile,"wb+");

//    EXIT_ON_RUNTIME_ERROR_VERBOSE("MSG] Error: could not open AUDIO_PP.IFO")

    for (i=0; i < 8; i++)
        if  (fwrite(samg,1,sizeofsamg,fpout) < sizeofsamg )
            EXIT_ON_RUNTIME_ERROR_VERBOSE( "[ERR]  AUDIO_PP.IFO could not be written properly");

    if (fclose(fpout) == EOF)
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  AUDIO_PP.IFO could not be closed");


    return(last_sector);
}
