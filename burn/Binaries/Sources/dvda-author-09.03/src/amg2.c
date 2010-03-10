/*

File:    amg.c
Purpose: Create an Audio Manager (AUDIO_TS.IFO)

dvda-author  - Author a DVD-Audio DVD

(C) Dave Chapman <dave@dchapman.com> 2005
(C) Revised version with zone-to-zone linking Fabrice Nicol <fabnicol@users.sourceforge.net> 2007, 2008

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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include "structures.h"
#include "c_utils.h"
#include "auxiliary.h"
#include "amg.h"
#include "commonvars.h"


extern globalData globals;

/* Limitations */

/* Videolinking groups may have just one videolinking title and chapter per group. The sum of videolinking groups and audio groups
*  should not be greater than 9.
*  Video titlesets linked to may have just one identifiable single-chapter title in them, even if they actually have many titles. */


/* TODO: Dave Chapman's original code implements an implicit "automatic titling" mode: a new title is created sequentially when
*   the next file on the list does not have the same audio characteristics as the latest. This could be made optionally manual, to leave
*   room for choice and not depend on the file ordering, or make several titles within audio that have same characteristics */




int create_amg(char* audiotsdir, fileinfo_t ** files, int* ntracks, int ngroups, int vgroups, int* atsi_sectors, uint32_t *videotitlelength, int * VTSI_rank, uint32_t* relative_sector_pointer_VTSI)
{
    errno=0;

    int i,j=0,k=0,titleset=0,totaltitles=0,sectoroffset,titleintitleset;
    FILE* audio_ts_bup, *audio_ts_ifo;
    char outfile[CHAR_BUFSIZ];
    uint8_t amg[2048*SIZE_AMG];


    int naudio_groups=ngroups-vgroups;

    uint8_t numtitles[naudio_groups];
    int * ntitletracks[naudio_groups];
    uint64_t *titlelength[naudio_groups];

    for (k=0; k < naudio_groups; k++)
    {
        if (((ntitletracks[k]=calloc(ntracks[k], sizeof(int))) == NULL) || ((titlelength[k]=calloc(ntracks[k], 8)) ==  NULL))
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Memory shortage on creating AMG")
        }

    numtitles[titleset]=0;

    /* Normal case: audio files */

    // Files are packed together according to audio characteristics: bit rate, sampel rate, number of channels

    while  ((titleset < naudio_groups ) && (j < ntracks[titleset]) )
    {
        ntitletracks[titleset][numtitles[titleset]]=1;

        titlelength[titleset][numtitles[titleset]] = files[titleset][j].PTS_length;

        j++;

        while (  (j < ntracks[titleset])
                 &&(files[titleset][j].samplerate==files[titleset][j-1].samplerate)
                 && (files[titleset][j].bitspersample==files[titleset][j-1].bitspersample)
                 && (files[titleset][j].channels==files[titleset][j-1].channels))
        {

            /* counts the number of tracks with same-type audio characteristics, per titleset and title
            *  into ntitletracks[titleset][numtitles[titleset]], and corresponding PTS length in titlelength[titleset][numtitles[titleset]] */

            ntitletracks[titleset][numtitles[titleset]]++;
            titlelength[titleset][numtitles[titleset]]+=files[titleset][j].PTS_length;
            j++;


        }

        //  a new title begins when audio characteristics change, (whatever the titleset), except on reaching end of titleset tracks
        //  or: incrementing on leaving out titleset (0-based values)
        totaltitles++;
        numtitles[titleset]++;


        /* In case we've processed the last title in titleset,
         *so we've reached the end of titleset: new initialization of j to continue the loop and start new titleset */

        if (j == ntracks[titleset])
        {
            j=0;
            titleset++;

            /* bug fix: condition titleset < naudio_groups added (in original code, naudio_groups=9) buffer overflow could happen with titleset=8  */

            if (titleset < naudio_groups) numtitles[titleset]=0;
            continue;
        }

    }

    totaltitles+=vgroups;

    if (globals.debugging) foutput("[MSG]  AMG: totaltitles=%d  \n", totaltitles);

    memset(amg,0,sizeof(amg));

    /* Sector 1*/

    memcpy(amg,"DVDAUDIO-AMG",12);


    uint32_copy(&amg[12],5); 			// Last sector in AMG
    uint32_copy(&amg[28],2); 			// Last sector in AMGI
    uint16_copy(&amg[32],0x0012); 	// DVD Specifications
    uint16_copy(&amg[38],0x0001); 	// Number of Volumes
    uint16_copy(&amg[40],0x0001); 	// Current Volume
    amg[42]=1;  								// Disc Side
    amg[47]=1;
    uint32_copy(&amg[48],0);    			// Sector Pointer to AUDIO_SV.IFO
    amg[62]=0;  								// Number of AUDIO_TS video titlesets (DVD-Audio norm video titlesets, unused in current implementation)
    amg[63]=ngroups; 						 // Number of audio titlesets, must include video linking groups
    uint32_copy(&amg[128],0x07ff);

    uint32_copy(&amg[0xc4],1);  		// Pointer to sector 2
    uint32_copy(&amg[0xc8],2);  		// Pointer to sector 3

    /* Sector 2 */

    i=0x800;
    uint16_copy(&amg[i],totaltitles);		// total number of titles, audio and videolinking titles included
    i+=2;
    // pointer to end of sector table : 4 (bytes used) + 14 (size of table) *number of tables (totaltitles) -1
    uint16_copy(&amg[i],4+14*totaltitles-1);
    i+=2;

    sectoroffset=6; 								 // Size of AUDIO_TS.IFO+AUDIO_TS.BUP in this implementation; this number may vary
    titleset=0;
    titleintitleset=0;

    // Normal case: audio titles

    for (j=0; j < totaltitles-vgroups; j++)
    {
        // This implementation does not allow for VOB menus
        amg[i]=0x80|(titleset+1); 			// Table sector 2 first two bytes per title
        i++;
        amg[i]=ntitletracks[titleset][titleintitleset];
        i++;
        i+=2; // 0-padding

        uint32_copy(&amg[i],titlelength[titleset][titleintitleset]);
        i+=4;

        amg[i]=titleset+1;  // Titleset number
        i++;

        amg[i]=titleintitleset+1;
        i++;

        uint32_copy(&amg[i],sectoroffset); // Pointer to ATSI
        i+=4;

        titleintitleset++;
        if (titleintitleset == numtitles[titleset])
        {
            sectoroffset+=(files[titleset][ntracks[titleset]-1].last_sector+1)+atsi_sectors[titleset]*2;
            titleintitleset=0;
            titleset++;
        }
    }

    // Case 2: video-linking titles

    // supposing one title per videolinking group

    if (globals.videolinking)
    {

        for (k=0; k < vgroups ; k++)
        {

            /* if (k +1 == #number of videotitles in group)
                amg[i]=0x00|(titleset+1);                  // Table sector 2 first two bytes per title, non-last video linking title
            else
            */
            amg[i]=0x40|(++titleset);                  // Table sector 2 first two bytes per title, last video linking title

            i++;
            amg[i]=1;                                        // Experiment limitation: just one video chapter is visible within video zone title

            i++;
            amg[i]=1;                                        // Experiment limitation: just one video chapter is visible within video zone title (repeated)

            i++;
            i++;                                               // 0-padding

            uint32_copy(&amg[i],  videotitlelength[k]);        //  length of title in PTS ticks

            i+=4;
            amg[i]=VTSI_rank[k];                          // Video zone Titleset number

            i++;
            amg[i]=1;                                        // Experiment limitation: just one video title is visible within video zone titleset

            i++;

            uint32_copy(&amg[i], relative_sector_pointer_VTSI[VTSI_rank[k]-1]);       // Pointer to VTSI

            i+=4;

        }
    }


    /* Sector 3 */

    memcpy(&amg[4096],&amg[2048],2048);

    size_t  sizeofamg=sizeof(amg);

    /* Finalizing .IFO and .BUP -- I/O tests have been added to strengthen security */

    // Writing path to AUDIO_TS.IFO

    STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/AUDIO_TS.IFO",audiotsdir)

    // Creating AUDIO_TS.IFO

    foutput("\n[INF]  Creating %s\n",outfile);

    audio_ts_ifo=fopen(outfile,"wb+");
    if (audio_ts_ifo == NULL)
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR] AUDIO_TS.IFO could not be opened properly")

        if (  fwrite(amg, 1, sizeofamg, audio_ts_ifo) == sizeofamg )
            foutput("%s%s%s\n", "[MSG] ", outfile," was created.");
        else
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR] AUDIO_TS.IFO  could not be created properly -- fwrite error")

            if (fclose(audio_ts_ifo)== EOF)
                EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR] AUDIO_TS.IFO  could not be closed properly")

                // Writing path to AUDIO_TS.BUP

                STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/AUDIO_TS.BUP",audiotsdir)

                // Creating AUDIO_TS.BUP

                foutput("\n[INF]  Creating %s\n", outfile);

    audio_ts_bup=fopen(outfile,"wb+");
    if (audio_ts_bup == NULL)
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR] AUDIO_TS.BUP could not be opened properly")

        if (  fwrite(amg,1,sizeofamg,audio_ts_bup)== sizeofamg )
            foutput("%s%s%s\n", "[MSG] ", outfile, "  was created.");
        else
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR] AUDIO_TS.BUP could not be created properly -- fwrite error.")

            if (fclose(audio_ts_bup)== EOF)
                EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR] AUDIO_TS.BUP  could not be closed properly")

                for (k=0; k < naudio_groups; k++)
                {
                    FREE(ntitletracks[k])
                    FREE(titlelength[k])
                }

    return(errno);

}
