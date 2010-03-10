/*****************************************************************
*   readHeader.c
*   Copyright Fabrice Nicol 2008
*   Description: reads headers.
*   Rewrite of Pigiron's 2007 originalwork to accommodate
*   big-endian platforms.
*
*******************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <inttypes.h>
#include "fixwav.h"
#include "fixwav_auxiliary.h"
#include "readHeader.h"
#include "fixwav_manager.h"
#include "c_utils.h"


extern globals_fixwav globals_f;

int readHeader(FILE * infile, WaveHeader *header)
{
    size_t        count;

    /* read in the HEADER_SIZE byte RIFF header from file */


    uint8_t *p;
    uint8_t temp[HEADER_SIZE]={0};
    p=temp;
    /* Patch against Pigiron's original work: code was not portable across compilers (structure header was
     * not necessarily packed, unless using gcc's __attribute((packed))__ or similar. Also, using code
     * was not portable to big-endian machines, considering wav headers are packed in little-endian order.
     * This version  fixes both issues */

	rewind(infile);
    count=fread(temp, HEADER_SIZE, 1, infile ) ;
        /* Total is 44 bytes */

    if ( count != 1)
    {
        fprintf( stderr, "%s\n", "[ERR]  Failed to read header from input file" );
        fprintf( stderr, "%s\n", "[INF]  Fixwav will skip this file.\n");
        return(FAIL);
    }


    #define READ_4_bytes uint32_read(p), p+=4;
    #define READ_2_bytes uint16_read(p), p+=2;
  
	/* RIFF chunk */
	/* 0-3 */   header->chunk_id    =READ_4_bytes
	/* 4-7 */   header->chunk_size  =READ_4_bytes
	/* 8-11 */  header->chunk_format=READ_4_bytes

    /* FORMAT chunk */
    /* 12-15 */ header->sub_chunk= READ_4_bytes
	/* 16-19 */ header->sc_size  = READ_4_bytes
    /* 20-21 */ header->sc_format= READ_2_bytes
	/* 22-23 */ header->channels = READ_2_bytes
	/* 24-27 */ header->sample_fq= READ_4_bytes
    /* 28-31 */ header->byte_p_sec=READ_4_bytes
    /* 32-33 */ header->byte_p_spl=READ_2_bytes
    /* 34-35 */ header->bit_p_spl =READ_2_bytes

	/* DATA chunk */
	/* 36-39 */ header->data_chunk=READ_4_bytes
	/* 40-43 */ header->data_size= uint32_read(p);


    /* point to beginning of file */
    rewind(infile);

    /* and dump the header */
    foutput_f( "\n%s\n", "[MSG]  Existing header data.\n[INF]  Looking for the words 'RIFF', 'WAVE', 'fmt'," );
    foutput_f( "%s\n\n", "       or 'data' to see if this is even a somewhat valid WAVE header:" );
    hexdump_header(infile);
    foutput_f( "%c", '\n' );


return 1;
}




