/*

File:    atsi.c
Purpose: Create an Audio Titleset Information file

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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <errno.h>
#include "structures.h"
#include "audio2.h"
#include "c_utils.h"
#include "commonvars.h"
#include "structures.h"
#include "auxiliary.h"


extern globalData globals;



int get_afmt(fileinfo_t* info, audioformat_t* audioformats, int* numafmts)
{
    int i;
    int found;

    found=0;
    i=0;
    while ((i < *numafmts) && (!found))
    {
        if ((info->samplerate==audioformats[i].samplerate) && (info->bitspersample==audioformats[i].bitspersample) && (info->channels==audioformats[i].channels))
        {
            found=1;
        }
        else
        {
            i++;
        }
    }
    if (!found)
    {
        audioformats[i].samplerate=info->samplerate;
        audioformats[i].channels=info->channels;
        audioformats[i].bitspersample=info->bitspersample;
        (*numafmts)++;
    }
    return(i);
}

int create_atsi(char* audiotsdir,int titleset,fileinfo_t* files, int ntracks, int* atsi_sectors)
{
    int i,j,k,t,x;
    FILE* fpout;
    char outfile[CHAR_BUFSIZ+13+1];
    uint8_t atsi[2048*3];
    int numtitles;
    int ntitletracks[99];
    uint64_t title_length;
    int numafmts=0;
    audioformat_t audioformats[18];

    memset(atsi,0,sizeof(atsi));
    memcpy(&atsi[0],"DVDAUDIO-ATS",12);
    uint16_copy(&atsi[32],0x0012);  // DVD Specifications version
    uint32_copy(&atsi[128],0x07ff); // End byte address of ATSI_MAT
    uint32_copy(&atsi[204],1);      // Start sector of ATST_PGCI_UT

    i=256;
    j=0;
    numtitles=0;
    ntitletracks[numtitles]=0;
    while (j < ntracks)
    {

        ntitletracks[numtitles]=1;

        k=get_afmt(&files[j],audioformats,&numafmts);
        j++;

        while ((j < ntracks) && (files[j].samplerate==files[j-1].samplerate) && (files[j].bitspersample==files[j-1].bitspersample) && (files[j].channels==files[j-1].channels))
        {
            ntitletracks[numtitles]++;
            j++;
        }
        numtitles++;
    }



    for (j=0;j<numafmts;j++)
    {
        uint16_copy(&atsi[i],0x0000);  // [200806] 0x0000 if a menu is not generated; otherwise sector pointer from start of audio zone (AUDIO_PP.IFO to last sector of audio system space (here AUDIO_TS.IFO)
        i+=2;
        if (files[j].channels>2)
        {

            switch (audioformats[j].bitspersample)
            {

            case 16:
                atsi[i]=0x00;
                break;
            case 20:
                atsi[i]=0x11;
                break;
            case 24:
                atsi[i]=0x22;
                break;
            default:
                break;
            }

        }
        else
        {

            switch (audioformats[j].bitspersample)
            {

            case 16:
                atsi[i]=0x0f;
                break;
            case 20:
                atsi[i]=0x1f;
                break;
            case 24:
                atsi[i]=0x2f;
                break;
            default:
                break;
            }
        }
        i++;
        if (files[j].channels>2)
        {

            switch (audioformats[j].samplerate)
            {

            case 48000:
                atsi[i]=0x00;
                break;
            case 96000:
                atsi[i]=0x11;
                break;
            case 192000:
                atsi[i]=0x22;
                break;
            case 44100:
                atsi[i]=0x88;
                break;
            case 88200:
                atsi[i]=0x99;
                break;
            case 176400:
                atsi[i]=0xaa;
                break;
            default:
                break;
            }
        }
        else
        {
            switch (audioformats[j].samplerate)
            {

            case 48000:
                atsi[i]=0x0f;
                break;
            case 96000:
                atsi[i]=0x1f;
                break;
            case 192000:
                atsi[i]=0x2f;
                break;
            case 44100:
                atsi[i]=0x8f;
                break;
            case 88200:
                atsi[i]=0x9f;
                break;
            case 176400:
                atsi[i]=0xaf;
                break;
            default:
                break;
            }
        }

        i++;
        atsi[i]= files[j].cga;

        switch (audioformats[j].channels)
        {
        case 1:
            atsi[i]=0;
            break;
        case 2:
            atsi[i]=1;
            break;
        case 3:
            atsi[i]=2;
            break; // L-R-S    4 gives L-R-Lfe   other 3-ch configs could be supported -- laf
        case 4:
            atsi[i]=3;
            break;
        case 5:
            atsi[i]=6;
            break; // other 5-ch configs could be supported -- laf
        case 6:
            atsi[i]=20;
            break;
        default:
            foutput("[ERR] Unsupported number of channels (%d)\n",audioformats[j].channels);
            EXIT_ON_RUNTIME_ERROR
        }

        i++;


        atsi[i]=0x00; // ??? Unknown part of audio format
        i++;
        i+=10; // ??? Padding
    }

    // I have no idea what the following info is for:
    //[200806] : if a menu is generated: uint8_copy(&atsi[336],0x01);
    uint16_copy(&atsi[384],0x0000);
    uint16_copy(&atsi[386],0x1eff);
    uint16_copy(&atsi[388],0xff1e);
    uint16_copy(&atsi[390],0x2d2d);
    uint16_copy(&atsi[392],0x3cff);
    uint16_copy(&atsi[394],0xff3c);
    uint16_copy(&atsi[396],0x4b4b);
    uint16_copy(&atsi[398],0x0000);


    /* SECTOR 2 */

    i=0x800;
    uint16_copy(&atsi[i],numtitles);
    // [200806] The number numtitles must be equal to number of audio zone titles plus video zone titles linked to. Gapless tracks are packed in the same title.
    i+=2;
    i+=2; // Padding
    i+=4;

    for (j=0;j<numtitles;j++)
    {
        uint16_copy(&atsi[i],0x8000+(j+1)*0x100);
        i+=2;
        uint16_copy(&atsi[i],0x0000); // Unknown.  Maybe 0x0100 for Stereo, 0x0000 for surround
        i+=2;

        // To be filled later - pointer to a following table.
        i+=4;
    }

    k=0;
    for (j=0;j<numtitles;j++)
    {
        uint32_copy(&atsi[0x808+8*j+4],i-0x800);

        uint16_copy(&atsi[i],0x0000); // Unknown
        i+=2;
        atsi[i]=ntitletracks[j];
        i++;
        atsi[i]=ntitletracks[j];
        i++;
        title_length=0;
        for (t=0;t<ntitletracks[j];t++)
        {
            title_length+=files[k+t].PTS_length;
        }
        uint32_copy(&atsi[i],title_length);
        i+=4;
        uint16_copy(&atsi[i],0x0000);  // Unknown
        i+=2;
        uint16_copy(&atsi[i],0x0010);                 // Pointer to PTS table
        i+=2;
        uint16_copy(&atsi[i],16+20*ntitletracks[j]);  // Pointer to sector table
        i+=2;
        uint16_copy(&atsi[i],0x0000);                 // ?? Pointer to a third table (present in commercial DVD-As)
        i+=2;

        /* Timestamp and sector records */

        for (t=0;t<ntitletracks[j];t++)
        {

            // These seem to be pointers to a lookup table in the first sector of the ATSI
            x=get_afmt(&files[k],audioformats,&numafmts);
            x=((x*8)<<8)|0x0010;
            if (t==0)
            {
                x|=0xc000;
            }
            uint16_copy(&atsi[i],x);
            i+=2;
            uint16_copy(&atsi[i],0x0000);
            i+=2;
            atsi[i]=t+1;
            i++;
            atsi[i]=0x00;
            i++;
            uint32_copy(&atsi[i],files[k+t].first_PTS);
            i+=4;
            uint32_copy(&atsi[i],files[k+t].PTS_length);
            i+=4;
            i+=6; // Padding??
        }
        /* Sector pointer records */
        for (t=0;t<ntitletracks[j];t++)
        {
            atsi[i]=0x01;
            i+=4;
            uint32_copy(&atsi[i],files[k+t].first_sector);
            i+=4;
            uint32_copy(&atsi[i],files[k+t].last_sector);
            i+=4;
        }
        k+=ntitletracks[j];
    }
    uint32_copy(&atsi[0x0804],i-0x801);

    if (i > 2048)
    {
        *atsi_sectors=3;
    }
    else
    {
        *atsi_sectors=2;
    }

    uint32_copy(&atsi[12],files[ntracks-1].last_sector+(2*(*atsi_sectors))); // Pointer to last sector in ATS (i.e. numsectors-1)
    uint32_copy(&atsi[28],(*atsi_sectors)-1); // Last sector in ATSI
    uint32_copy(&atsi[196],(*atsi_sectors));      // Start sector of ATST_AOBS

    STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/ATS_%02d_0.IFO",audiotsdir,titleset)

    fpout=fopen(outfile,"wb+");
    fwrite(atsi,1,2048*(*atsi_sectors),fpout);
    fclose(fpout);

    STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/ATS_%02d_0.BUP",audiotsdir,titleset)
    fpout=fopen(outfile,"wb+");
    fwrite(atsi,1,2048*(*atsi_sectors),fpout);
    fclose(fpout);

    return(0);
}
