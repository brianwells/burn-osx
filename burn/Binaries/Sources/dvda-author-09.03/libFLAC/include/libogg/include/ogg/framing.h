#ifndef FRAMING_H_INCLUDED
#define FRAMING_H_INCLUDED

/********************************************************************
 *                                                                  *
 * THIS FILE IS PART OF THE OggVorbis SOFTWARE CODEC SOURCE CODE.   *
 * USE, DISTRIBUTION AND REPRODUCTION OF THIS LIBRARY SOURCE IS     *
 * GOVERNED BY A BSD-STYLE SOURCE LICENSE INCLUDED WITH THIS SOURCE *
 * IN 'COPYING'. PLEASE READ THESE TERMS BEFORE DISTRIBUTING.       *
 *                                                                  *
 * THE OggVorbis SOURCE CODE IS (C) COPYRIGHT 1994-2002             *
 * by the Xiph.Org Foundation http://www.xiph.org/                  *
 *                                                                  *
 ********************************************************************

 function: toplevel libogg include
 last mod: $Id: ogg.h 7188 2004-07-20 07:26:04Z xiphmont $

 ********************************************************************/
#include    <stdint.h>
#include    <inttypes.h>
#include    "ogg/os_types.h"
#define EXCLUDE_EXTERN_FUNCTIONS_IN_OGG_H
#include    "ogg/ogg.h"
#define FRAMING_INCLUDED_BY_CB

int ogg_page_version(ogg_page *og);
int ogg_page_continued(ogg_page *og);
int ogg_page_bos(ogg_page *og);
int ogg_page_eos(ogg_page *og);
ogg_int64_t ogg_page_granulepos(ogg_page *og);
int ogg_page_serialno(ogg_page *og);
long ogg_page_pageno(ogg_page *og);
int ogg_page_packets(ogg_page *og);
int ogg_stream_init(ogg_stream_state *os,int serialno);
int ogg_stream_clear(ogg_stream_state *os);
int ogg_stream_destroy(ogg_stream_state *os);
static void _os_body_expand(ogg_stream_state *os,int needed);
static void _os_lacing_expand(ogg_stream_state *os,int needed);
void ogg_page_checksum_set(ogg_page *og);
int ogg_stream_packetin(ogg_stream_state *os,ogg_packet *op);
int ogg_stream_flush(ogg_stream_state *os,ogg_page *og);
int ogg_stream_pageout(ogg_stream_state *os, ogg_page *og);
int ogg_stream_eos(ogg_stream_state *os);
int ogg_sync_init(ogg_sync_state *oy);
int ogg_sync_clear(ogg_sync_state *oy);
int ogg_sync_destroy(ogg_sync_state *oy);
char *ogg_sync_buffer(ogg_sync_state *oy, long size);
int ogg_sync_wrote(ogg_sync_state *oy, long bytes);
long ogg_sync_pageseek(ogg_sync_state *oy,ogg_page *og);
int ogg_sync_pageout(ogg_sync_state *oy, ogg_page *og);
int ogg_sync_reset(ogg_sync_state *oy);
int ogg_stream_reset(ogg_stream_state *os);
int ogg_stream_reset_serialno(ogg_stream_state *os,int serialno);
static int _packetout(ogg_stream_state *os,ogg_packet *op,int adv);
int ogg_stream_packetout(ogg_stream_state *os,ogg_packet *op);
int ogg_stream_packetpeek(ogg_stream_state *os,ogg_packet *op);
void ogg_packet_clear(ogg_packet *op);
void checkpacket(ogg_packet *op,int len, int no, int pos);
void check_page(unsigned char *data,const int *header,ogg_page *og);
void print_header(ogg_page *og);
void copy_page(ogg_page *og);
void free_page(ogg_page *og);
void error(void);
void test_pack(const int *pl, const int **headers, int byteskip,
               int pageskip, int packetskip);

//PATCH added:
int ogg_stream_pagein(ogg_stream_state *os, ogg_page *og);



#endif // FRAMING_H_INCLUDED
