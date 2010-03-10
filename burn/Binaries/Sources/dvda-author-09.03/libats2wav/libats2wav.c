/*

ats2wav - extract uncompressed LPCM audio from a DVD-Audio disc

Copyright Dave Chapman <dave@dchapman.com> 2005,
revised by Fabrice Nicol <fabnicol@users.sourceforge.net> 2008
for Windows compatibility, directory output and dvda-author integration.

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
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <inttypes.h>
#include <stdint.h>
#include "libats2wav.h"
#include "c_utils.h"
#include "structures.h"
#include "winport.h"
#include "multichannel.h"
#include "auxiliary.h"

extern globalData globals;

static unsigned char wav_header[44]={'R','I','F','F',    //  0 - ChunkID
                                     0,0,0,0,            //  4 - ChunkSize (filesize-8)
                                     'W','A','V','E',    //  8 - Format
                                     'f','m','t',' ',    // 12 - SubChunkID
                                     16,0,0,0,           // 16 - SubChunk1ID  // 16 for PCM
                                     1,0,                // 20 - AudioFormat (1=16-bit)
                                     2,0,                // 22 - NumChannels
                                     0,0,0,0,            // 24 - SampleRate in Hz
                                     0,0,0,0,            // 28 - Byte Rate (SampleRate*NumChannels*(BitsPerSample/8)
                                     4,0,                // 32 - BlockAlign (== NumChannels * BitsPerSample/8)
                                     16,0,               // 34 - BitsPerSample
                                     'd','a','t','a',    // 36 - Subchunk2ID
                                     0,0,0,0             // 40 - Subchunk2Size
                                    };


static short int  _S[2][6][36]={{ {0}, {0},
        {5, 4, 7, 6, 1, 0, 9, 8, 11, 10, 3, 2},
        {9, 8, 11, 10, 1, 0, 3, 2, 13, 12, 15, 14, 5, 4 ,7, 6},
        {13, 12, 15, 14, 1, 0, 3, 2, 5, 4, 17, 16, 19, 18, 7, 6, 9, 8, 11, 10},
    {9, 8, 11, 10, 1, 0, 3, 2, 13, 12, 15, 14, 17, 16, 19, 18, 5, 4, 7, 6, 21, 20, 23, 22}},
    {{4,  1,  0,  5,  3,  2},
        {8, 1, 0, 9, 3, 2, 10, 5, 4, 11, 7, 6},
        {14, 7, 6, 15, 9, 8, 4, 1, 0, 16, 11, 10, 17, 13, 12, 5, 3, 2},
        {20, 13, 12, 21, 15, 14, 8, 1, 0, 9, 3, 2, 22, 17, 16, 23, 19, 18, 10, 5, 4, 11, 7, 6},
        {26, 19, 18, 27, 21, 20, 12, 1, 0, 13, 3, 2, 14, 5,  4,  28, 23, 22, 29, 25, 24, 15,  7, 6,  16, 9, 8, 17, 11, 10},
        {28, 13, 12, 29, 15, 14,  8, 1, 0,  9, 3, 2, 30, 17, 16, 31, 19, 18, 32, 21, 20, 33, 23, 22, 10, 5, 4, 11, 7,  6, 34, 25, 24, 35, 27, 26 }}
};




inline void calc_size(_fileinfo_t* info)
{
    uint64_t x;

    info->numsamples=(info->pts_length*info->samplerate)/90000;
    x=(90000*info->numsamples)/info->samplerate;

    // Adjust for rounding errors:
    if (x < info->pts_length)
    {
        info->numsamples++;
    }

    info->numbytes=(info->numsamples*info->channels*info->bitspersample)/8;
}

inline int setinfo(_fileinfo_t* info, uint8_t buf[4])
{

    switch (buf[0]&0xf0)
    {
    case 0x00:
        info->bitspersample=16;
        break;

    case 0x20:
        info->bitspersample=24;
        break;

    default:
        foutput("%s", "[ERR]  Unsupported bits per sample\n");
        exit(0);
    }

    switch (buf[1]&0xf0)
    {
    case 0x00:
        info->samplerate=48000;
        break;

    case 0x10:
        info->samplerate=96000;
        break;

    case 0x20:
        info->samplerate=192000;
        break;

    case 0x80:
        info->samplerate=44100;
        break;

    case 0x90:
        info->samplerate=88200;
        break;

    case 0xa0:
        info->samplerate=176400;
        break;
    }

    int T[21] = {1, 2, 3, 4, 3, 4, 5, 3, 4, 5, 4, 5, 6, 4, 5, 4, 5, 6, 5, 5, 6 };

    if (buf[3] > 20)
        
        {
        	foutput("%s\n", "[ERR] Unsupported number of channels, skipping file...\n");
        	return(0);
        }

     info->channels = T[buf[3]] ;

     calc_size(info);
     return(1);

}

inline unsigned int write_data(_fileinfo_t* info, uint8_t* buf, unsigned int count)
{
    unsigned int n;


    n= (info->byteswritten+count > info->numbytes) ? info->numbytes-info->byteswritten : count;


    fwrite(buf,n,1,info->fpout);

    info->byteswritten+=n;

    return(n);
}

/*	 Convert LPCM samples to little-endian WAV samples and deinterleave.

Here the interleaving that is performed during dvd_audio authoring is reversed so as to recover the proper byte order
for a wave file.  The transformation for each of the 12 cases is specified by the following.
A "round trip," i.e., authoring followed by extraction, is now illustrated for the 16-bit, 3-channel case.

authoring:
WAV:  0  1  2  3  4  5  6  7  8  9 10 11
AOB:  5  4 11  10 1  0  3  2  7  6  9  8

extraction:
AOB: 0  1  2  3  4  5  6  7  8  9  10  11
WAV: 5  4  7  6  1  0  9  8  11  10  3  2

These values are encoded in _S matrix to be found in src/include/multichannel.h

 */

/*
 16-bit 1  channel
AOB: 0  1
WAV: 1  0

 16-bit 2  channel
AOB: 0  1
WAV: 1  0
*/

/*
 16-bit 3  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11
WAV: 5  4  7  6  1  0  9  8  11  10  3  2
*/

/*
 16-bit 4  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15
WAV: 9  8  11  10  1  0  3  2  13  12  15  14  5  4  7  6
*/


/*
 16-bit 5  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17  18  19
WAV: 13  12  15  14  1  0  3  2  5  4  17  16  19  18  7  6  9  8  11  10
*/


/*
 16-bit 6  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17  18  19  20  21  22  23
WAV: 9  8  11  10  1  0  3  2  13  12  15  14  17  16  19  18  5  4  7  6  21  20  23  22
*/


/*
 24-bit 1  channel
AOB: 0  1  2  3  4  5
WAV: 4  1  0  5  3  2
*/


/*
 24-bit 2  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11
WAV: 8  1  0  9  3  2  10  5  4  11  7  6
*/


/*
 24-bit 3  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17
WAV: 14  7  6  15  9  8  4  1  0  16  11  10  17  13  12  5  3  2
*/


/*
 24-bit 4  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17  18  19  20  21  22  23
WAV: 20  13  12  21  15  14  8  1  0  9  3  2  22  17  16  23  19  18  10  5  4  11  7  6
*/

/*
 24-bit 5  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29
WAV: 26  19  18  27  21  20  12  1  0  13  3  2  14  5  4  28  23  22  29  25  24  15  7  6  16  9  8  17  11  10
*/
/*
 24-bit 6  channel
AOB: 0  1  2  3  4  5  6  7  8  9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26  27  28  29  30  31  32  33  34  35
WAV: 28  13  12  29  15  14  8  1  0  9  3  2  30  17  16  31  19  18  32  21  20  33  23  22  10  5  4  11  7  6  34  25  24  35  27  26
*/




static inline void deinterleave_24_bit_sample_extended(int channels, int count, uint8_t *buf)
{
    // Processing 16-bit case
    int i, size=channels*6;
    // Requires C99
    uint8_t _buf[size];

    for (i=0; i < count ; i += size)
        permutation(buf+i, _buf, 1, channels, _S, size);

}

static inline void deinterleave_sample_extended(int channels, int count, uint8_t *buf)
{

    // Processing 16-bit case
    int x,i, size=channels*4;
    // Requires C99
    uint8_t _buf[size];

    switch (channels)
    {
    case 1:
    case 2:
        for (i=0;i<count;i+= 2 )
        {
            x= buf[i ];
            buf[i ] = buf[i+ 1 ];
            buf[i+ 1 ]=x;
        }
        break;

    default:
        for (i=0; i < count ; i += size)
            permutation(buf+i, _buf, 0, channels, _S, size);

    }
}



static inline void convert_buffer(_fileinfo_t* info, uint8_t* buf, int count)
{

    switch (info->bitspersample)
    {

    case 24:


        deinterleave_24_bit_sample_extended(info->channels, count, buf);
        break;

    case 16:


        deinterleave_sample_extended(info->channels, count, buf);
        break;

    default:
        // FIX: Handle 20-bit audio and maybe convert other formats.
        foutput("[ERR]  %d bit %d channel audio is not supported\n",info->bitspersample,info->channels);
        exit(EXIT_FAILURE);

    }

}


static inline void wav_open(_fileinfo_t* info, char* outfile)
{

    info->fpout=fopen(outfile,"wb");

    if (info->fpout==0)
    {
        foutput("[ERR]  Could not open %s\n",outfile);
        exit(EXIT_FAILURE);
    }
    fwrite(wav_header,sizeof(wav_header),1,info->fpout);
}


static inline void wav_close(_fileinfo_t* info , const char* filename)
{

    uint64_t filesize=0;
    
    
    if (filesize > UINT32_MAX)
    {
        foutput("%s", "[ERR]  WAV standards do not support files > 4 GB--exiting...\n");
        pause_dos_type();
        exit(EXIT_FAILURE);
    }
    
    filesize=info->numbytes;
        
	if (filesize == 0) 
	{
	    foutput("[WAR]  filename: %s\n       filesize is null, closing file...\n", filename);
	    fclose(info->fpout);
	    return;
	}
	    
    if (globals.debugging) foutput("[MSG]  IFO file: %s\n       IFO file size: %"PRIu64"\n", filename, info->numbytes);

    fseek(info->fpout,0,SEEK_SET);

    // ChunkSize

    uint32_copy_reverse(wav_header+4, filesize-8);

    wav_header[22]=info->channels;

    // Samplerate
    uint32_copy_reverse(wav_header+24, info->samplerate);

    // ByteRate

    uint32_copy_reverse(wav_header+28, (info->samplerate*info->bitspersample*info->channels)/8);

    wav_header[32]=(info->channels*info->bitspersample)/8;
    wav_header[34]=info->bitspersample;

    // Subchunk2Size
    uint32_copy_reverse(wav_header+40, (uint32_t) filesize-44);


    fwrite(wav_header,sizeof(wav_header), 1, info->fpout);
    fclose(info->fpout);
}



FILE* open_aob(FILE* fp, const char* filename, char* atstemplate, int ats)
{
    int length=strlen(filename);
    char atsfilename[length+1];

    
    memcpy(atstemplate,filename,length-5);
    memcpy(&atstemplate[length-5],"%d.AOB",6);
    atstemplate[length+1]=0;
    sprintf(atsfilename,atstemplate,ats);

    
    fp=fopen(atsfilename,"rb");

    if (fp==NULL)
    {
        foutput("[ERR]  Cannot open %s\n",atsfilename);
        exit(EXIT_FAILURE);
    }

    return(fp);
}



int scan_ats_ifo(_fileinfo_t * files, uint8_t *buf)
{
    int i,j,k,t=0,ntracks,ntracks1, numtitles;


    i=2048;
    numtitles=uint16_read(buf+i);

    uint8_t titleptr[numtitles];

    i+=8;
    ntracks=0;

    for (j=0;j<numtitles;j++)
    {

        i+=4;
        titleptr[j]=uint32_read(buf+i);
        i+=4;
    }

    for (j=0;j<numtitles;j++)
    {
        i=0x802+titleptr[j];
        ntracks1=buf[i];
        i+=14;

        t=ntracks;

        for (k=0;k<ntracks1;k++)
        {
            i+=10;
            files[t].pts_length=uint32_read(buf+i);
            i+=10;
            t++;
        }

        t=ntracks;
        /* 12 byte sector records */
        if (globals.debugging)
            for (k=0;k<ntracks1;k++)
            {

                i+=4;
                files[t].first_sector=uint32_read(buf+i);
                i+=4;
                files[t].last_sector=uint32_read(buf+i);
                i+=4;
                t++;
            }

        ntracks+=ntracks1;
    }
    if (globals.debugging)
        for (i=0;i<ntracks;i++)
        {
            foutput("     track first sector  last sector   pts length\n     %02d    %12"PRIu64" %12"PRIu64" %12"PRIu64"\n\n",i+1,files[i].first_sector,files[i].last_sector,files[i].pts_length);
        }

    return(ntracks);
}

void write_wav_file(char* outfile, const char* outdir, int length, _fileinfo_t * files, int t)
{
char tmp[length+1+14];
memcpy(tmp, outdir, length);

memcpy(&tmp[length], "/track%02d.wav", 14);
tmp[length+14]=0;
sprintf(outfile, tmp ,t+1);
wav_open(&files[t],outfile);
return;
}


int ats2wav(const char* filename, const char* outdir)
{
    FILE* file;
    FILE* fp=NULL;
    
    
    
    char atstemplate[512];

    unsigned int n, payload_length;
    int ats=1;
    int sector=0;
    _fileinfo_t files[99];
    int ntracks;
    int length=strlen(outdir);
    char outfile[length+1+14];
    int i,k, t;
    uint8_t buf[BUFFER_SIZE];


    file=fopen(filename, "rb");
    if (file == NULL)
    {
        foutput("[ERR]  Could not open %s\n", filename);
        return(EXIT_FAILURE);
    }

    n=fread(buf,1,sizeof(buf), file);
    if (globals.debugging)
       foutput( "[INF]  Read %d bytes\n", n);
    fclose(file);

    if (memcmp(buf,"DVDAUDIO-ATS",12)!=0)
    {
        foutput("[ERR]  %s is not an ATSI file (ATS_XX_0.IFO)\n",filename);
        return(EXIT_FAILURE);
    }

    foutput("%c", '\n');

    ntracks=scan_ats_ifo(files, buf);

    fp=open_aob( fp,  filename,  atstemplate,  ats);

    for (t=0;t<ntracks;t++)
    {
        files[t].started=0;
        files[t].byteswritten=0;
    }

    t=0;

    while (t < ntracks)
    {

        NEXT:
        
        while (fread(buf,2048,1,fp) != 1)
        {
            fclose(fp);
            ats++;
            fp=open_aob(fp, filename, atstemplate, ats);
            t=0;
        }

        sector++;
        i=0;

        while ((buf[i]==0x00) && (buf[i+1]==0x00) && (buf[i+2]==0x01))
        {
            i+=4;

            switch (buf[i-1])
            {
            case 0xba:
                i+=10;
                break;
            case 0xbb:
                i+=14;
                break;
            case 0xbd:  // Audio PES Packet

                k=i+2+uint16_read(buf+i);
                i+=4;
                i+=1+buf[i];


                if (files[t].started==0)
                {
                    write_wav_file(outfile, outdir, length, files, t);
                    
                    if (!setinfo(&files[t],&buf[i+7])) 
                    {
                    	/* skipping file */
                    	t++;
                    	fclose(fp);
                    	/* label jump is preferable here, to avoid testing a skip boolean repetitively for rare cases at end of while loops */
                        goto NEXT;
                    	break;
                    }
                    
                    files[t].started=1;
                    if (globals.debugging)
                       foutput("[INF]  Extracting %s\n       %dHz, %d bits/sample, %d channels - %lld samples\n",outfile,files[t].samplerate,files[t].bitspersample,files[t].channels,files[t].numsamples);
                }

                i+=buf[i+3]+4;

                payload_length=k-i;

                convert_buffer(&files[t],&buf[i],payload_length);
                n=write_data(&files[t],&buf[i],payload_length);

                if ((n==0) && (globals.debugging))
                {
                    foutput("[MSG]  Wrote %d bytes, written=%lld, size=%lld\n",n,files[t].byteswritten,files[t].numbytes);
                }

                if (files[t].byteswritten==files[t].numbytes)
                {
				    wav_close(&files[t], filename);
                             
                    t++;

                    if (t < ntracks)
                    {
                        if (n < payload_length)
                        {
							write_wav_file(outfile, outdir, length, files, t);
							
                            files[t].samplerate=files[t-1].samplerate;
                            files[t].bitspersample=files[t-1].bitspersample;
                            files[t].channels=files[t-1].channels;
                            files[t].started=1;
                            calc_size(&files[t]);

                            foutput("[INF]  Extracting %s\n       %dHz, %d bits/sample, %d channels - %lld samples\n",outfile,files[t].samplerate,files[t].bitspersample,files[t].channels,files[t].numsamples);

                            n=write_data(&files[t],&buf[i+n],payload_length-n);
                        }
                    }
                }

                i=k;
                break;
            case 0xbe:  // Audio PES Packet

                i+=2+uint16_read(buf+i);
                break;
            }
            
        }
    }

    return(EXIT_SUCCESS);
}
