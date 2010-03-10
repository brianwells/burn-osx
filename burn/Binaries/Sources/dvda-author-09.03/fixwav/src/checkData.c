/* ==========================================================================
*
*   checkData.c
*   Original author Pigiron,2007. Revised and expanded by Fabrice Nicol,copyright
*   2008.
*
*   Description
*       Checks evenness of data byte count and pads with 0s otherwise
*       Copies data to new file (if option -o is selected)
========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/stat.h>

// Requested by truncate()
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <unistd.h>
#include <sys/types.h>
#include <inttypes.h>

#include "fixwav.h"
#include "fixwav_auxiliary.h"
#include "checkData.h"
#include "fixwav_manager.h"
#include "c_utils.h"
#include "repair.h"
#include "winport.h"

extern globals_fixwav globals_f;


/*********************************************************************
 Function: check_sample_count

 Purpose:  checks whether the number of samples is a whole number

*********************************************************************/

int check_sample_count(FILE* outfile, WaveData *info, WaveHeader *header) {

    char	buf;
    int r=0;

    if ((r=header->data_size % header->byte_p_spl) 	== 0)
        return(GOOD_HEADER);

	/* go to the end of the file */

    if (end_seek(outfile) ==   FAIL) return FAIL;

	/*
	 * fwrite is used to count padding zeros
	 */
	info->repair = BAD_DATA;

	buf=0;

	short int  complement=0, count=0;

	complement=header->byte_p_spl - r;
	foutput_f( "[INF]  Writing %d pad bytes to have multiple number of samples\n\n", complement);
	count = fwrite( &buf, sizeof(char) , complement , outfile );

	if   (count  != complement)
	{
		foutput_f( "%s\n", "[ERR] Error appending data to end of existing file\n" );
		foutput_f( "%s\n", "     FILE MAY BE CORRUPT\n" );
		foutput_f( "[INF]  %d characters were written out of %d\n", count, complement);
		foutput_f( "%s\n", "[ERR]  Error appending data to end of existing file\n" );
		if (fclose(outfile) == 0);
		if (isok()) return(FAIL);
	}
	/* now we need to readjust the header data */


	info->repair=readjust_sizes(outfile, info, header);

    return( info->repair );
}

/*********************************************************************
 Function: readjust_sizes

 Purpose:  This function updates the header 'size' fields with
           updated information.
*********************************************************************/

int readjust_sizes(FILE* outfile, WaveData *info, WaveHeader *header)
{
    struct stat newstats;

    /* looks like we have to reopen the file to refresh the stats */
	foutput_f("\n%s\n", "[INF]  Readjusting header data...");

    if (!info->virtual)
    {
		if (fclose(outfile ) == EOF) return FAIL;

		outfile=secure_open(info->outfile, "rb");

		if (outfile == NULL) return(FAIL);
    }
    /* get the new file statistics */

    if (stat(info->outfile, &newstats )) return FAIL;

    /* adjust the Chunk Size */
    header->chunk_size = (uint32_t) newstats.st_size - 8;

    /* adjust the Subchunk2 Size */
    header->data_size = (uint32_t) newstats.st_size - HEADER_SIZE;

    if (launch_repair(outfile, info, header) == FAIL) return(FAIL);

    return(BAD_DATA);
}


/****************************************************************************
 Function: check_envenness

 Purpose:  This function adds one padding byte to the end of the data chunk
		   should the byte count be odd.
***************************************************************************/


/* all RIFF chunks (including WAVE "data" chunks) must be word aligned.
* If the sample data uses an odd number of bytes, a padding byte with a value of zero
* must be placed at the end of the sample data. The "data" chunk header's size should not include this byte.*/


int check_evenness(FILE* outfile, WaveData *info, WaveHeader *header)
{

uint8_t pad=0x00;


if (header->data_size %2)
{

   if (end_seek(outfile) ==  FAIL) return(FAIL);
   foutput_f("%s\n", "[INF]  Readjusting output file to even byte count...");
   if (fwrite(&pad, 1, 1, outfile) !=1) return(FAIL);


   header->data_size++;
   header->chunk_size++;

   info->repair=readjust_sizes(outfile, info, header);

   return(BAD_DATA);
}



return GOOD_HEADER;

}

int prune(FILE* infile, FILE* outfile, WaveData *info, WaveHeader *header)
{

uint8_t p=0;
uint32_t count=-1;

// Count ending zeros to be pruned
if (end_seek(infile) == FAIL) return(FAIL);
do
{
     if (fseek(infile, -1, SEEK_CUR) == -1) return(FAIL);
     if (fread(&p, 1, 1, infile) != 1) return(FAIL);
     #ifndef __WIN32__
     foutput_f("  Offset %"PRIu64"  : %"PRIu8" \n", (uint64_t) ftello(infile), p );
     #endif
     if (fseek(infile, -1, SEEK_CUR) == -1) return(FAIL);
     count++;

} while (p == 0);

if (count > 0)
{

  rewind(infile);
  rewind(outfile);
  if ((! info->in_place) && (copy_fixwav_files(info, infile, outfile) == FAIL))
    	   return(info->repair=FAIL);

  if ( (outfile == NULL) || (fclose(outfile) != 0) || ((outfile=fopen(info->outfile, "rb+")) == NULL) )
     {
       foutput_f("%s\n", "[ERR]  Error: failed to close/open file");
       return(info->repair=FAIL);
     }


  foutput_f("[INF]  Pruning file: -%"PRIu32" bytes at: %"PRIu32"\n", count, header->chunk_size + 8 -count );
   off_t offset;

//  Under Windows API, pruning from end of file
//  otherwise truncate takes full size as an argument

   #ifdef __WIN32__
    fclose(outfile);
    offset=-count;
   #else
    offset=header->chunk_size + 8 -count;

   #endif

   if (truncate_from_end(info->outfile, offset) == -1)
   {
   perror("[ERR]  truncate error");
   return(info->repair=FAIL);
   }

   #ifdef __WIN32__
     outfile=fopen(info->outfile, "rb+");
   #endif

   foutput_f("%s\n", "[INF]  Readjusting byte count...");
   readjust_sizes(outfile, info, header);
   return(info->repair=BAD_DATA);
}

return(NO_PRUNE);
}





