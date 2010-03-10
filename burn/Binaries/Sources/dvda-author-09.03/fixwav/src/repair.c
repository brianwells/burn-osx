/* ==========================================================================
*
*   repair.c
*   Original code: Pigiron 2007,
*   Revision: Fabrice Nicol 2008 <fabnicol@users.sourceforge.net>
*
*   Description: Performs repairs on header and file.
*========================================================================== */

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>
#include <inttypes.h>
#include "fixwav.h"
#include "repair.h"
#include "checkParameters.h"
#include "fixwav_auxiliary.h"
#include "fixwav_manager.h"
#include "c_utils.h"
#include "winport.h"


/* global data */

extern globals_fixwav globals_f;


/*********************************************************************
* Function: repair_wav
*
* Purpose:  This function will analyze and repair the header
*********************************************************************/
int
repair_wav(struct stat *file_stat, WaveData *info, WaveHeader *header )
{

    int repair=GOOD_HEADER;
    uint32_t file_size=file_stat->st_size;

    /*********************************************************************
    * The RIFF Chunk
    *********************************************************************/

    /* the first 4 bytes should be "RIFF" */
    if ( header->chunk_id == RIFF )
    {
        foutput_f( "%s", "[MSG]  Found correct Chunk ID at offset 0\n" );
    }
    else
    {
		foutput_f( "%s", "[INF]  Repairing Chunk ID at offset 0\n" );
        if (memmove( &(header->chunk_id), "RIFF", 4*sizeof(char) ) == NULL) return(FAIL);
        repair = BAD_HEADER;
    }

    /* The ChunkSize is the entire file size - 8 */
    if ( header->chunk_size ==  (file_size  - 8 ) )
    {
        foutput_f( "[MSG]  Found correct Chunk Size of %"PRIu32" bytes at offset 4\n",
                header->chunk_size );
    }
    else
    {
        foutput_f( "[MSG]  Chunk Size of %"PRIu32" at offset 4 is incorrect: should be %"PRIu32" bytes\n[INF]  ... repairing\n", header->chunk_size, file_size-8 );
        header->chunk_size = file_size - 8;
        repair = BAD_HEADER;
    }

    /* The Chunk Format should be the letters "WAVE" */
    if ( header->chunk_format == WAVE )
    {
        foutput_f("%s\n",  "[MSG]  Found correct Chunk Format at offset 8\n" );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Chunk Format at offset 8 is incorrect\n[INF]  ... repairing\n" );
        if (memmove( &(header->chunk_format), "WAVE", 4*sizeof(char)) == NULL) return(FAIL);
        repair = BAD_HEADER;
    }

    /*********************************************************************/

    /* The "fmt " Subchunk                                                */
    /*********************************************************************/

    /* The Subchunk1 ID should contain the letters "fmt " */
    if ( header->sub_chunk == FMT )
    {
        foutput_f("%s\n",  "[MSG]  Found correct Subchunk1 ID at offset 12\n" );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Subchunk1 ID at offset 12 is incorrect\n[INF]  ... repairing\n" );
        // "fmt " ends in a space
        if (memmove( &(header->sub_chunk), "fmt ", 4*sizeof(char) ) == NULL) return(FAIL);
        repair = BAD_HEADER;
    }

    /* The Subchunk1 Size is 16 for PCM */
    if ( header->sc_size == 16 )
    {
        foutput_f("[MSG]  Found correct Subchunk1 Size of %"PRIu32" bytes at offset 16\n", header->sc_size );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Subchunk1 Size at offset 16 is incorrect\n[INF]  ... repairing\n" );
        header->sc_size = 16;
        repair = BAD_HEADER;
    }

    /* The Subchunk1 Audio Format is 1 for PCM */
    if ( header->sc_format == 1 )
    {
        foutput_f("%s\n",  "[MSG]  Found correct Subchunk1 Format at offset 20\n" );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Subchunk1 Format at offset 20 is incorrect\n[INF]  ... repairing\n" );
        header->sc_format = 1;
        repair = BAD_HEADER;
    }

    /****************************************
    *  On to core audio parameters
    *****************************************/

    if (info->automatic)
    {
		repair= (auto_control(info, header) == BAD_HEADER)? BAD_HEADER: ((repair == BAD_HEADER)? BAD_HEADER : GOOD_HEADER) ;
		foutput_f("[MSG]  Audio characteristics found by automatic mode:\n       bits/s=%"PRIu16", sample rate=%"PRIu32", channels=%"PRIu16"\n\n",
				header->bit_p_spl, header->sample_fq, header->channels);
		if (repair == BAD_HEADER)
        {
		   if (info->interactive)
			{
				foutput_f("%s\n", "[INT]  Please confirm [y/n] ");
				if (!isok())
				{
				   foutput_f("%s\n", "[INF]  Exiting automatic mode: user mode\n");
				   repair=user_control(info, header);
				}
			}
          else
          foutput_f("%s\n", "[INT]  Non-interactive mode: assuming correct repair.");
		}
    }
    else

     repair= (user_control(info, header) == BAD_HEADER)? BAD_HEADER: (repair == BAD_HEADER)? BAD_HEADER : GOOD_HEADER ;


	foutput_f("\n%s\n", "[INF]  Core audio characteristics were checked.\n       Now processing data subchunk");

    /*********************************************************************/
    /* The "data" Subchunk                                               */
    /*********************************************************************/

    /* The Subchunk2 ID is the ASCII characters "data" */
    if ( header->data_chunk == DATA )
    {
        foutput_f("%s\n",  "[MSG]  Found correct Subchunk2 ID at offset 36\n" );
    }
    else
    {
        foutput_f("%s\n",  "[MSG]  Subchunk2 ID at offset 36 is incorrect\n[INF]  ... repairing\n" );
        if (memmove( &(header->data_chunk),"data", 4*sizeof(char) ) == NULL) return(FAIL);
        repair = BAD_HEADER;
    }

    /* The Subchunk2 Size = NumSample * NumChannels * BitsPerSample/8 */
    if ( header->data_size == (file_size - 44) )
    {
        foutput_f(  "[MSG]  Found correct Subchunk2 Size of %"PRIu32" bytes at offset 40\n", header->data_size );
    }
    else
    {
        foutput_f("[MSG]  Subchunk2 Size at offset 40 is incorrect: found %"PRIu32" bytes instead of %"PRIu32"\n[INF]  ... repairing\n",header->data_size, file_size -44  );
        header->data_size = file_size - 44;
        repair = BAD_HEADER;
    }

    return(repair);

}

int copy_fixwav_files(WaveData *info, FILE* infile, FILE* outfile)
{

end_seek(outfile);

if ((info->prepend) && (fseek(infile, 0, SEEK_SET) == -1))
    info->repair=FAIL;

errno=0;
if ((!info->in_place) && (!info->virtual))
        {
            foutput_f( "\n%s", "[INF]  Creating new audio file, please wait...\n" );

            // Using libutils.a

            if (copy_file_p(infile, outfile) !=0) info->repair=FAIL;
            end_seek(outfile);
            
            foutput_f( "\n[MSG]  %"PRIu64" bytes were copied.\n\n", read_file_size(outfile, info->outfile));
 
            

 }

if (errno) return(FAIL);
else return(COPY_SUCCESS);

}

// rewrite of original code to accommodate big-endian platforms

int launch_repair(FILE* outfile, WaveData *info, WaveHeader *header)
{


    foutput_f( "%s", "\n[INF]  Writing new header...\n" );

    /* if -o option is not used, fixwav will overwrite existing data; confirmation dialog */

    if (info->in_place)
    {
        foutput_f( "\n%s", "[INT]  Overwrite the existing file? [y/n] " );
		if (!isok())

		{   /* user's bailing */
			if ( info->repair == BAD_DATA )
				foutput_f( "%s","[WAR]  Header may still be corrupt.\n\n" );
			else
				foutput_f( "%s", "[INF]  No changes made to existing file\n\n" );
			return(info->repair) ;
		}
    }

    /* if OK */

        /* write the new header at the beginning of the file */


        uint8_t temp[HEADER_SIZE]={0};
        uint8_t *p=temp;

		/* again, copying manually rather than invoking fread to ensure cross-compiler/platform portability */


		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->chunk_id);
		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->chunk_size);
		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->chunk_format);
		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->sub_chunk);
		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->sc_size);

		_LITTLE_ENDIAN_WRITE_2_bytes(p, header->sc_format);
		_LITTLE_ENDIAN_WRITE_2_bytes(p, header->channels);
		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->sample_fq);
		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->byte_p_sec);
		_LITTLE_ENDIAN_WRITE_2_bytes(p, header->byte_p_spl);
		_LITTLE_ENDIAN_WRITE_2_bytes(p, header->bit_p_spl);

		_LITTLE_ENDIAN_WRITE_4_bytes(p, header->data_chunk);
		 LITTLE_ENDIAN_WRITE_4_bytes(p, header->data_size);





	if (write_header(temp, outfile, info) == FAIL) info->repair=FAIL;
    else
    {
    	 foutput_f("%s\n", "[INF]  Header copy successful. Dumping new header:\n\n");

    	 if (fclose(outfile) != 0) return(FAIL);
    	 outfile=secure_open(info->outfile, "rb+");
    	 hexdump_header(outfile);


    }

    return(info->repair) ;
}


int write_header(uint8_t *newheader, FILE* outfile, WaveData *info)
{

        // Only repairing headers virtually to cut down computing times (--fixwav-virtual)

        if (info->virtual) return(info->repair);

        int count=0;

        //closing and opening again for security/sync, may be a non-op//

        if ((!info->virtual) && ( (outfile == NULL) || (fclose(outfile) != 0) || ((outfile=fopen(info->outfile, "rb+")) == NULL) ))
        {
           foutput_f("%s\n", "[ERR]  Failed to close/open file");
           return(FAIL);
        }


        // in manager.c a sanity check ensures that if (info->prepend) then !(info->in_place)
        // Otherwise copying fixed header to new file or in place, depending on option

        /* try to seek right offset depending on type of file */


        if (info->in_place)
        {
            foutput_f("%s\n", "[INF]  Overwriting header...");
        }

		count=fwrite(newheader, HEADER_SIZE, 1, outfile ) ;


        if (count != 1)
        {
            fprintf( stderr, "\n%s\n", "[ERR]  Error updating wav file.");
            return(FAIL);
        }



    if (errno)
    {
    	perror("[ERR]  Error in launch repair module");
    	return(FAIL);
    }

    return(COPY_SUCCESS);
}
