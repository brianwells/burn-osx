/*

File:    ats.c
Purpose: Create an Audio Titleset

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
#include "auxiliary.h"
#include "commonvars.h"



extern globalData globals;

uint8_t pack_start_code[4]={0x00,0x00,0x01,0xBA};
uint8_t system_header_start_code[4]={0x00,0x00,0x01,0xBB};
uint8_t program_mux_rate_bytes[3]={0x01,0x89,0xc3};

/* pack_scr was taken from mplex (part of the mjpegtools) */
#define MARKER_MPEG2_SCR 1
ALWAYS_INLINE_GCC  inline void pack_scr(uint8_t scr_bytes[6],uint64_t SCR_base, uint16_t SCR_ext)
{

    uint8_t temp;
    uint64_t msb, lsb;

    msb = (SCR_base>> 32) & 1;
    lsb = SCR_base & (0xFFFFFFFF);

    temp = (MARKER_MPEG2_SCR << 6) | (msb << 5) | ((lsb >> 27) & 0x18) | 0x4 | ((lsb >> 28) & 0x3);
    scr_bytes[0]=temp;
    temp = (lsb & 0x0ff00000) >> 20;
    scr_bytes[1]=temp;
    temp = ((lsb & 0x000f8000) >> 12) | 0x4 | ((lsb & 0x00006000) >> 13);
    scr_bytes[2]=temp;
    temp = (lsb & 0x00001fe0) >> 5;
    scr_bytes[3]=temp;
    temp = ((lsb & 0x0000001f) << 3) | 0x4 | ((SCR_ext & 0x00000180) >> 7);
    scr_bytes[4]=temp;
    temp = ((SCR_ext & 0x0000007F) << 1) | 1;
    scr_bytes[5]=temp;
}

ALWAYS_INLINE_GCC inline void pack_pts_dts(uint8_t PTS_DTS_data[10],uint32_t pts, uint32_t dts)
{
    uint8_t p3,p2,p1,p0,d3,d2,d1,d0;

    p3=(pts&0xff000000)>>24;
    p2=(pts&0x00ff0000)>>16;
    p1=(pts&0x0000ff00)>>8;
    p0=pts&0xff;
    d3=(dts&0xff000000)>>24;
    d2=(dts&0x00ff0000)>>16;
    d1=(dts&0x0000ff00)>>8;
    d0=dts&0xff;

    PTS_DTS_data[0]=0x31|((p3&0xc0)>>5);              // [32],31,30
    PTS_DTS_data[1]=((p3&0x3f)<<2)|((p2&0xc0)>>6);    // 29,28,27,26,25,24 ,23,22
    PTS_DTS_data[2]=((p2&0x3f)<<2)|((p1&0x80)>>6)|1;  // 21,20,19,18,17,16, 15
    PTS_DTS_data[3]=((p1&0x7f)<<1)|((p0&0x80)>>7);    // 14,13,12,11,10,9,8, 7
    PTS_DTS_data[4]=((p0&0x7f)<<1)|1;                 // 6,5,4,3,2,1,0
    PTS_DTS_data[5]=0x11|((d3&0xc0)>>5);              // [32],31,30
    PTS_DTS_data[6]=((d3&0x3f)<<2)|((d2&0xc0)>>6);    // 29,28,27,26,25,24 ,23,22
    PTS_DTS_data[7]=((d2&0x3f)<<2)|((d1&0x80)>>6)|1;  // 21,20,19,18,17,16, 15
    PTS_DTS_data[8]=((d1&0x7f)<<1)|((d0&0x80)>>7);    // 14,13,12,11,10,9,8, 7
    PTS_DTS_data[9]=((d0&0x7f)<<1)|1;                 // 6,5,4,3,2,1,0
}

ALWAYS_INLINE_GCC inline void pack_pts(uint8_t PTS_DTS_data[10],uint32_t pts)
{
    uint8_t p3,p2,p1,p0;

    p3=(pts&0xff000000)>>24;
    p2=(pts&0x00ff0000)>>16;
    p1=(pts&0x0000ff00)>>8;
    p0=pts&0xff;

    PTS_DTS_data[0]=0x21|((p3&0xc0)>>5);              // [32],31,30
    PTS_DTS_data[1]=((p3&0x3f)<<2)|((p2&0xc0)>>6);    // 29,28,27,26,25,24 ,23,22
    PTS_DTS_data[2]=((p2&0x3f)<<2)|((p1&0x80)>>6)|1;  // 21,20,19,18,17,16, 15
    PTS_DTS_data[3]=((p1&0x7f)<<1)|((p0&0x80)>>7);    // 14,13,12,11,10,9,8, 7
    PTS_DTS_data[4]=((p0&0x7f)<<1)|1;                 // 6,5,4,3,2,1,0
}

ALWAYS_INLINE_GCC inline void write_pack_header(FILE* fp,  uint64_t SCRint)
{

    uint8_t scr_bytes[6];
    uint8_t pack_stuffing_length_byte[1]={0xf8};

    /*200806  patch Fabrice Nicol <fabnicol@users.sourceforge.net>
    * floor returns a double (type conversion error).
    * SCRint=floor(SCR);
    */

    fwrite(pack_start_code,4,1,fp);
    pack_scr(scr_bytes,(SCRint/300),(SCRint%300));
    fwrite(scr_bytes,6,1,fp);
    fwrite(program_mux_rate_bytes,3,1,fp);
    fwrite(pack_stuffing_length_byte,1,1,fp);
}

ALWAYS_INLINE_GCC inline void write_system_header(FILE* fp)
{
    uint8_t header_length[2]={0x00,0x0c};
    uint8_t rate_bound[3]={0x80,0xc4,0xe1};
    uint8_t audio_bound[1]={0x04};
    uint8_t video_bound[1]={0xa0};
    uint8_t packet_rate_restriction_flag[1]={0x7f};
    uint8_t stream_info1[3]={0xb8, 0xc0, 0x40};
    uint8_t stream_info2[3]={0xbd, 0xe0, 0x0a};

    fwrite(system_header_start_code,4,1,fp);
    fwrite(header_length,2,1,fp);
    fwrite(rate_bound,3,1,fp);
    fwrite(audio_bound,1,1,fp);
    fwrite(video_bound,1,1,fp);
    fwrite(packet_rate_restriction_flag,1,1,fp);
    fwrite(stream_info1,3,1,fp);
    fwrite(stream_info2,3,1,fp);
}

ALWAYS_INLINE_GCC inline void write_pes_padding(FILE* fp,uint16_t length)
{
    uint8_t packet_start_code_prefix[3]={0x00,0x00,0x01};
    uint8_t stream_id[1]={0xbe};
    uint8_t length_bytes[2];
    uint8_t ff_buf[2048];

    memset(ff_buf,0xff,sizeof(ff_buf));

    length-=6; // We have 6 bytes of PES header.

    length_bytes[0]=(length&0xff00)>>8;
    length_bytes[1]=(length&0xff);

    fwrite(packet_start_code_prefix,3,1,fp);
    fwrite(&stream_id,1,1,fp);
    fwrite(length_bytes,2,1,fp);
    fwrite(ff_buf,length,1,fp);
}

ALWAYS_INLINE_GCC inline void write_audio_pes_header(FILE* fp, uint16_t PES_packet_len, uint8_t extension_flag, uint64_t PTS)
{
    uint8_t packet_start_code_prefix[3]={0x00,0x00,0x01};
    uint8_t stream_id[1]={0xbd}; // private_stream_1
    uint8_t PES_packet_len_bytes[2];
    uint8_t flags1[1]={0x81};  // various flags - original_or_copy=1
    uint8_t flags2[1]={0};  // various flags - contains pts_dts_flags and extension_flav
    uint8_t PES_header_data_length[1]={0};
    uint8_t PES_extension_flags[1]={0x1e};  // PSTD_buffer_flag=1
    uint8_t PTS_DTS_data[10];
    uint8_t PSTD_buffer_scalesize[2];
    uint16_t PSTD=10240/1024;

    /* Set PTS_DTS_flags in flags2 to 2 (top 2 bits) - PTS only*/
    flags2[0]=(2<<6);

    if (extension_flag)
    {
        PES_header_data_length[0]+=3;
    }

    PES_header_data_length[0]+=5;        // PTS only (and PSTD)

    flags2[0]|=extension_flag;  // PES_extension_flag=1

    PES_packet_len_bytes[0]=(PES_packet_len&0xff00)>>8;
    PES_packet_len_bytes[1]=PES_packet_len&0xff;

    fwrite(packet_start_code_prefix,3,1,fp);
    fwrite(stream_id,1,1,fp);
    fwrite(PES_packet_len_bytes,2,1,fp);
    fwrite(flags1,1,1,fp);
    fwrite(flags2,1,1,fp);
    fwrite(PES_header_data_length,1,1,fp);

    pack_pts(PTS_DTS_data,PTS);
    fwrite(PTS_DTS_data,5,1,fp);

    if (extension_flag)
    {
        PSTD_buffer_scalesize[0]=0x60|((PSTD&0x1f00)>>8);
        PSTD_buffer_scalesize[1]=PSTD&0xff;

        fwrite(PES_extension_flags,1,1,fp);
        fwrite(PSTD_buffer_scalesize,2,1,fp);
    }
}

ALWAYS_INLINE_GCC inline void write_lpcm_header(FILE* fp, int header_length,fileinfo_t* info, uint64_t pack_in_title, uint8_t counter)
{
    uint8_t sub_stream_id[1]={0xa0};
    uint8_t continuity_counter[1]={0x00};
    uint8_t LPCM_header_length[2];
    uint8_t first_access_unit_pointer[2];
    uint8_t unknown1[1]={0x10};   // e.g. 0x10 for stereo, 0x00 for surround
    uint8_t sample_size[1]={0x0f};  // 0x0f=16-bit, 0x1f=20-bit, 0x2f=24-bit
    uint8_t sample_rate[1]={0x0f};  // 0x0f=48KHz, 0x1f=96KHz, 0x2f=192KHz,0x8f=44.1KHz, 0x9f=88.2KHz, 0xaf=176.4KHz
    uint8_t unknown2[1]={0x00};
    uint8_t channel_assignment;  // The channel assignment - 0=C; 1=L,R; 17=L,R,C,lfe,Ls,Rs
    uint8_t unknown3[1]={0x80};

    uint8_t zero[16]={0};

    int frame_offset;
    uint64_t bytes_written;
    uint64_t frames_written;

    continuity_counter[0]=counter;
    LPCM_header_length[0]=(header_length&0xff00)>>8;
    LPCM_header_length[1]=header_length&0xff;

    if (info->channels < 3)
    {
        unknown1[0]=0x10;
        switch (info->bitspersample)
        {
        case 16:
            sample_size[0]=0x0f;
            break;
        case 20:
            sample_size[0]=0x1f;
            break;
        case 24:
            sample_size[0]=0x2f;
            break;
        default:
            break;
        }
        switch (info->samplerate)
        {
        case 48000:
            sample_rate[0]=0x0f;
            break;
        case 96000:
            sample_rate[0]=0x1f;
            break;
        case 192000:
            sample_rate[0]=0x2f;
            break;
        case 44100:
            sample_rate[0]=0x8f;
            break;
        case 88200:
            sample_rate[0]=0x9f;
            break;
        case 176400:
            sample_rate[0]=0xaf;
            break;
        default:
            break;
        }
    }
    else
    {
        unknown1[0]=0x00;
        switch (info->bitspersample)
        {
        case 16:
            sample_size[0]=0x00;
            break;
        case 20:
            sample_size[0]=0x12;
            break;
        case 24:
            sample_size[0]=0x22;
            break;
        default:
            break;
        }
        switch (info->samplerate)
        {
        case 48000:
            sample_rate[0]=0x00;
            break;
        case 96000:
            sample_rate[0]=0x11;
            break;
        case 192000:
            sample_rate[0]=0x22;
            break;
        case 44100:
            sample_rate[0]=0x88;
            break;
        case 88200:
            sample_rate[0]=0x99;
            break;
        case 176400:
            sample_rate[0]=0xaa;
            break;
        default:
            break;
        }
    }
    channel_assignment = info->cga;

    if (pack_in_title==0)
    {
        frames_written=0;
        bytes_written=0;
    }
    else
    {
        bytes_written=(pack_in_title*info->lpcm_payload)-info->firstpackdecrement;
        // e.g., for 4ch, First pack is 1984, rest are 2000
        frames_written=bytes_written/info->bytesperframe;
        if (frames_written*info->bytesperframe < bytes_written)
        {
            frames_written++;
        }
    }

    frame_offset=(frames_written*info->bytesperframe)-bytes_written+header_length-1;
    first_access_unit_pointer[0]=(frame_offset&0xff00)>>8;
    first_access_unit_pointer[1]=frame_offset&0xff;

    fwrite(sub_stream_id,1,1,fp);
    fwrite(continuity_counter,1,1,fp);
    fwrite(LPCM_header_length,2,1,fp);
    fwrite(first_access_unit_pointer,2,1,fp);
    fwrite(unknown1,1,1,fp);
    fwrite(sample_size,1,1,fp);
    fwrite(sample_rate,1,1,fp);
    fwrite(unknown2,1,1,fp);
    fwrite(&channel_assignment,1,1,fp);
    fwrite(unknown3,1,1,fp);
    fwrite(zero,header_length-8,1,fp);
}


ALWAYS_INLINE_GCC inline uint64_t calc_PTS_start(fileinfo_t* info, uint64_t pack_in_title)
{
    double PTS;
    uint64_t PTSint;
    uint64_t bytes_written;

    if (pack_in_title==0)
    {
        PTS=585.0;
    }
    else
    {
        bytes_written=(pack_in_title*info->lpcm_payload)-info->firstpackdecrement;
        // e.g., for 4ch, First pack is 1984, rest are 2000
        PTS=((bytes_written*90000.0)/(info->bytespersecond*1.0))+585.0;
    }

    PTSint=floor(PTS);
    return(PTSint);
}



ALWAYS_INLINE_GCC inline uint64_t calc_SCR(fileinfo_t* info, uint64_t pack_in_title)
{
    double SCR;
    uint64_t SCRint;


    if (info->bytespersecond == 0)
    {
        foutput("[WAR]  file %s has bytes per second=0\n", info->filename);
        return 0;
    }


    SCR=(pack_in_title <= 4 ? pack_in_title : 4)*(2048.0*8.0*90000.0*300.0)/10080000.0;

    if (pack_in_title>=4)
    {
        SCR+=((info->SCRquantity*300.0*90000.0)/info->bytespersecond)-42.85;
    }
    if (pack_in_title>=5)
    {
        SCR+=(pack_in_title-4.0)*((info->lpcm_payload*300.0*90000.0)/info->bytespersecond);
    }

    SCRint=floor(SCR);

    return(SCRint);
}


ALWAYS_INLINE_GCC inline uint64_t calc_PTS(fileinfo_t* info, uint64_t pack_in_title)
{
    double PTS;
    uint64_t PTSint;
    uint64_t bytes_written;
    uint64_t frames_written;


    if (pack_in_title==0)
    {
        PTS=585.0;
    }
    else
    {
        bytes_written=(pack_in_title*info->lpcm_payload)-info->firstpackdecrement;
        // e.g., for 4ch, First pack is 1984, rest are 2000
        frames_written=bytes_written/info->bytesperframe;
        if (frames_written*info->bytesperframe < bytes_written)
        {
            frames_written++;
        }
        // 1 48Khz-based frame is 1200Hz, 1 44.1KHz frame is 1102.5Hz
        PTS=((frames_written*info->bytesperframe*90000.0)/(info->bytespersecond*1.0))+585.0;
    }

    PTSint=floor(PTS);
    return(PTSint);
}


ALWAYS_INLINE_GCC inline static int write_pes_packet(FILE* fp, fileinfo_t* info, uint8_t* audio_buf, int bytesinbuffer, uint64_t pack_in_title, int pack_in_file, int last_pack)
{
    uint64_t PTS;
    uint64_t SCR;
    int audio_bytes;
    static int cc;  // Continuity counter - reset to 0 when pack_in_title=0


    PTS=calc_PTS(info,pack_in_title);
    SCR=calc_SCR(info,pack_in_title);



    if (pack_in_title==0)
    {

        cc=0;            // First packet in title
        foutput("[INF]  Writing first packet - pack=%"PRIu64", bytesinbuffer=%d\n",pack_in_title,bytesinbuffer);
        write_pack_header(fp,SCR);
        write_system_header(fp);

        write_audio_pes_header(fp,info->firstpack_audiopesheaderquantity,1,PTS);
        audio_bytes = info->lpcm_payload - info->firstpackdecrement;
        write_lpcm_header(fp,info->firstpack_lpcm_headerquantity,info,pack_in_title,cc);
        fwrite(audio_buf,1,audio_bytes,fp);

        if (info->firstpack_pes_padding > 0)
        {

            write_pes_padding(fp,info->firstpack_pes_padding);
        }

    }
    else if (bytesinbuffer < info->lpcm_payload)   // Last packet in title
    {

        foutput("[INF]  Writing last packet - pack=%lld, bytesinbuffer=%d\n",pack_in_title,bytesinbuffer);
        audio_bytes=bytesinbuffer;
        write_pack_header(fp,SCR);
        write_audio_pes_header(fp,info->midpack_audiopesheaderquantity,0,PTS);
        write_lpcm_header(fp,info->midpack_lpcm_headerquantity,info,pack_in_title,cc);


        fwrite(audio_buf,1,audio_bytes,fp);
        write_pes_padding(fp,2048-28-info->midpack_lpcm_headerquantity-4-audio_bytes);

    }
    else   			// A middle packet in the title.
    {

        audio_bytes=info->lpcm_payload;
        write_pack_header(fp,SCR);

        write_audio_pes_header(fp,info->midpack_audiopesheaderquantity,0,PTS);
        write_lpcm_header(fp,info->midpack_lpcm_headerquantity,info,pack_in_title,cc);

        fwrite(audio_buf,1,audio_bytes,fp);
        if (info->midpack_pes_padding > 0) write_pes_padding(fp,info->midpack_pes_padding);

    }

    if (cc == 0x1f)
    {
        cc=0;
    }
    else
    {
        cc++;
    }

    return(audio_bytes);
}

int create_ats(char* audiotsdir,int titleset,fileinfo_t* files, int ntracks)
{

    FILE* fpout;
    char outfile[CHAR_BUFSIZ+13+1];
    int i=0,n,bytesinbuf=0, pack=0, pack_in_file=0, lpcm_payload, fileno=1;
    uint8_t audio_buf[65536];
    uint64_t pack_in_title=0;


    STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/ATS_%02d_%d.AOB",audiotsdir,titleset,fileno)
    fpout=fopen(outfile,"wb+");



    /* Open the first file and initialise the input audio buffer */
    if (audio_open(&files[i])!=0)
    {
        foutput("[ERR] Could not open %s\n", files[i].filename);
        EXIT_ON_RUNTIME_ERROR
    }

    n=audio_read(&files[i],audio_buf,sizeof(audio_buf)-bytesinbuf);
    bytesinbuf=n;

    lpcm_payload = files[i].lpcm_payload;

    files[i].first_sector=0;
    files[i].first_PTS=calc_PTS_start(&files[i],pack_in_title);

    foutput("[INF]  Processing %s\n",files[i].filename);

    while (bytesinbuf)
    {
        if (bytesinbuf >= lpcm_payload)
        {
            n=write_pes_packet(fpout,&files[i],audio_buf,bytesinbuf,pack_in_title,pack_in_file,0);

            memmove(audio_buf,&audio_buf[n],bytesinbuf-n);
            bytesinbuf -= n;

            pack++;
            pack_in_title++;
            pack_in_file++;
        }

        if ((pack > 0) && ((pack%(512*1024))==0))
        {
            fclose(fpout);
            fileno++;
            STRING_WRITE_CHAR_BUFSIZ(outfile, "%s/ATS_%02d_%d.AOB",audiotsdir,titleset,fileno)
            fpout=fopen(outfile,"wb+");
        }

        if (bytesinbuf < lpcm_payload)
        {
            n=audio_read(&files[i],&audio_buf[bytesinbuf],sizeof(audio_buf)-bytesinbuf);
            bytesinbuf+=n;
            if (n==0)   /* We have reached the end of the input file */
            {
                files[i].last_sector=pack;
                audio_close(&files[i]);
                i++;
                pack_in_file=-1;

                if (i<ntracks)
                {
                    /* If the current track is a different audio format, we must start a new title. */
                    if ((files[i].samplerate!=files[i-1].samplerate) || (files[i].channels!=files[i-1].channels) || (files[i].bitspersample!=files[i-1].bitspersample))
                    {
                        n=write_pes_packet(fpout,&files[i-1],audio_buf,bytesinbuf,pack_in_title,pack_in_file,1); // Empty audio buffer.
                        pack++;
                        pack_in_title=0;
                        pack_in_file=0;
                        bytesinbuf=0;


                        files[i].first_PTS=calc_PTS_start(&files[i],pack_in_title);
                    }
                    else
                    {
                        files[i].first_PTS=calc_PTS_start(&files[i],pack_in_title+1);
                    }

                    files[i].first_sector=files[i-1].last_sector+1;
                    if (audio_open(&files[i])!=0)
                    {
                        foutput("[ERR] Could not open %s\n",files[i].filename);
                        EXIT_ON_RUNTIME_ERROR
                    }

                    n=audio_read(&files[i],&audio_buf[bytesinbuf],sizeof(audio_buf)-bytesinbuf);
                    bytesinbuf+=n;
                    foutput("[INF]  Processing %s\n",files[i].filename);
                }
                else
                {
                    /* We have reached the last packet of the last file */
                    if (bytesinbuf==0)
                    {
                        files[i-1].last_sector=pack-1;
                    }
                    else
                    {
                        n=write_pes_packet(fpout,&files[i-1],audio_buf,bytesinbuf,pack_in_title,pack_in_file,1); // Empty audio buffer.
                        bytesinbuf=0;
                        pack++;
                        pack_in_title++;
                    }
                }
            }
        }
    }

    return(1-fileno);
}
