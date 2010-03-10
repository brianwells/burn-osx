/*****************************************************************
*   manager.c
*   Copyright Fabrice Nicol 2008
*   Description: launches subprocesses and manages output.
*
*******************************************************************/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

#include <dirent.h>
#include <stdint.h>
#include <inttypes.h>

#include "fixwav.h"
#include "fixwav_auxiliary.h"
#include "repair.h"
#include "readHeader.h"
#include "checkData.h"
#include "fixwav_manager.h"
#include "c_utils.h"

globals_fixwav globals_f;

void initialise_globals_fixwav(_Bool silence, _Bool logfile, FILE* journal)
{
    globals_f.silence=silence;
    globals_f.logfile=logfile;
    globals_f.journal=journal;
}


WaveHeader  *fixwav(WaveData *info, WaveHeader *header)
    {

    struct stat file_stat;
    FILE* infile=NULL, *outfile=NULL;
    int length=0;
    uint64_t size=0;
    static int section;
    section++;

   // get the file statistics
   errno=0;

   stat( info->infile, &file_stat );


    // display the total file size for convenience
    // Patch on version 0.1.1: -int +uint64_t (int is not enough for files > 2GB)

    if ((!errno) && (S_ISREG(file_stat.st_mode)))
    {
      foutput_f( "\n\n--FIXWAV section %d--\n\n[MSG]  File size is %"PRIu64" bytes\n", section, (uint64_t)  (size=file_stat.st_size) );
    }
    else
    {
    	perror("[ERR]  Could not stat regular file");
       	info->repair=FAIL;
       	goto getout;
    }

    if (size == 0)
    {
      foutput_f( "%s\n", "[WAR]  File size is null; skipping ..." );
      info->repair=FAIL;
      goto getout;
    }

    errno=0;

	/* verify that the filename ends with 'wav' */

    if ( ((length=strlen(info->infile) - 3) <= 0) || ( strncmp( info->infile + length, "wav", 3 ) ))
    {
	    foutput_f("%s\n", "[WAR]  The filename must end in 'wav'.\n[INT]  Press Y to exit, N to continue...\n" );
	    if (isok())
		    {
			    info->repair=FAIL;
			    goto getout;
		    }
    }

        /* checks incompatible options */

    int adjust=0;

    if ((info->prepend) && (info->in_place))
    {
        foutput_f( "%s\n",   "[ERR]  fixwav cannot prepend new header to raw data file in in-place mode.");
        foutput_f( "%s\n\n", "       use -o option instead. Press Y to exit...");
		if (isok())
			{
				info->repair=FAIL;
				goto getout;
			}
		adjust=1;
    }

/* 	  constraints are ordered according to the following hierarchy
 *
 * 		virtual > padding > prune > prepend/in-place
 */


     if (info->virtual)
     {
     	adjust=(info->prepend)+(info->in_place)+(info->prune)+(info->padding);
     	info->prepend=info->in_place=info->prune=info->padding=0;
     }

	if (info->padding)
	{
		adjust=(info->prune);
		info->prune=0;
    }


	if (adjust)
	   foutput_f("[MSG]  Adjusted options are: \ninfo->prepend=%d\ninfo->in_place=%d\ninfo->prune=%d\ninfo->padding=%d\ninfo->virtual=%d\n",
	            info->prepend, info->in_place, info->prune, info->padding, info->virtual);


	if ((globals_f.silence) && ((header->sample_fq)*(header->bit_p_spl)*(header->channels) == 0))
		{
			fprintf(stderr, "%s", "\n[ERR]  In silent mode, bit rate, sample rate and channels must be set\n[INF]  Correcting options...\n\n");
			globals_f.silence=0;
		}


       /* open the existing file */

    if (info->virtual)
        infile=secure_open(info->infile, "rb+");
    else
    {

		if (!info->in_place)
		{
			if (strcmp(info->infile, info->outfile))
			{
				infile=secure_open(info->infile, "rb");
				outfile=secure_open(info->outfile, "wb");
			}
			else
			{
				foutput_f( "%s\n", "[ERR]  input and output paths are identical. Press Y to exit...");
				if (isok())
				{
					info->repair=FAIL;
					goto getout;
				}
			}
		}
		else
		{
			foutput_f("\n%s\n", "[WAR]  in-place mode will change original file.\n");
			foutput_f("%s\n",   "[INT]  Enter Y to continue, otherwise press any key + return to exit.");

			if (!isok())
			{
				info->repair=FAIL;
				goto getout;
			}
			foutput_f("[INF]  Opening %s\n", info->outfile);
			info->outfile=info->infile;
			outfile=infile=secure_open(info->infile, "rb+");

		}
    }



    /* reads header */

    if (readHeader(infile, header) == FAIL)
    {
      info->repair=FAIL;
      goto getout;
    }



    /* diagnosis stage: check and possibly repair header data */

    info->repair = repair_wav( &file_stat, info, header );

    switch(info->repair)
    {
		case	GOOD_HEADER:
    	            foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 1:\n       WAVE header is correct. No changes made to existing header." );
					break;

		case	BAD_HEADER :
                    foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 1:\n       WAVE header corrupt." );

                    launch_repair(outfile, info, header);

                    if (copy_fixwav_files(info, infile, outfile) == FAIL)
                       info->repair=FAIL;
                    break;

		case	FAIL       :
		            foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 1:\n       Failure at repair stage." );
					goto getout;
    }




	/****************************************************
	*	Now checking whole number of samples
	*****************************************************/

    if (!info->padding) goto Pruning;

    int result_sample_count=check_sample_count(outfile, info, header);

    switch(result_sample_count)
    {
    	case GOOD_HEADER:
    	         foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 2:\n       Sample count is correct. No changes made to existing file." );
					break;

        case BAD_DATA   :
                 foutput_f("\n%s\n\n",  "[MSG]  Fixwav status 2:\n       Sample count is corrupt." );

                 if (info->padding) foutput_f( "\n%s\n\n", "       File was padded for sample count." );

                 info->repair=BAD_DATA;
					break;

		case FAIL       :
		        foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 2:\n       Failure at sample count stage." );
		        info->repair=FAIL;
		        goto getout;
    }


	/****************************************************
	*	Now checking evenness of sample count
	*****************************************************/

    if (!info->padding) goto Pruning;

	int result_evenness=check_evenness(outfile, info, header);

	switch(result_evenness)
		{
			case GOOD_HEADER:
					 foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 3:\n       Even count of bytes." );
						break;

			case BAD_DATA   :
					 foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 3:\n       Byte count is odd." );
					 if (info->padding) foutput_f( "%s\n\n", "[MSG]  File was padded." );
					 info->repair=BAD_DATA;
						break;

			case FAIL       :
			        foutput_f( "\n%s\n\n", "[MSG]  Fixwav status 3:\n       Failure at even count check stage." );
					info->repair=FAIL;
					goto getout;
		}



	/****************************************************
	*   Pruning	if requested
	*****************************************************/


Pruning:

    if  (info->prune)
    {

    foutput_f("%s\n", "[INF]  Pruning stage: copying file first...");


	switch(prune(infile, outfile, info, header))
		{
			case NO_PRUNE:
					foutput_f( "\n%s\n\n", "[INF]  Fixwav status 4:\n       File was not pruned (no ending zeros)." );

						break;

			case BAD_DATA   :
					foutput_f( "\n%s\n\n", "[INF]  Fixwav status 4:\n       File was pruned." );
                                        info->prune=PRUNED;
						break;

			case FAIL       :
			        foutput_f( "\n%s\n\n", "[INF]  Fixwav status 4:\n       Pruning failed." );
					info->repair=FAIL;
					goto getout;
		}
    }


// end of program

getout:

    if  (info->repair == BAD_HEADER)
        foutput_f( "%s\n\n", "[INF]  Fixwav status--summary:\n       HEADER chunk corrupt: fixed." );

    if  (info->repair == BAD_DATA)
    {
        if (info->prune == PRUNED)
        foutput_f( "%s\n\n", "[INF]  Fixwav status--summary:\n       DATA chunk was adjusted after pruning." );
        else
        foutput_f( "%s\n\n", "[INF]  Fixwav status--summary:\n       DATA chunk was corrupt: fixed." );
    }


	foutput_f( "\n--FIXWAV End of section %d --\n\n", section );




	if ((info->repair == FAIL)  || (size == 0)  || ( (info->repair == GOOD_HEADER) && (!info->in_place) && (!info->virtual) ))
    {
    	// getting rid of empty files and useless work copies
		errno=0;
		unlink(info->outfile);
		if (errno)
		  foutput_f("%s%s\n", "[ERR]  unlink: ", strerror(errno));
    }


	if (!info->virtual)
	{
		if ((infile == NULL) || (outfile == NULL) )
		{
			fprintf(stderr, "\n%s\n", "[WAR]  File pointer is NULL.");
			return(NULL);
		}

		if ((fclose(infile) == EOF) || ((!info->in_place)  && (fclose(outfile) == EOF)) )
		{

			fprintf(stderr, "\n%s\n", "[WAR]  fclose error: issues may arise.");
			return(NULL);
		}
	}
	else
	{
		if (infile == NULL)
		{
			fprintf(stderr, "\n%s\n", "[WAR]  File pointer is NULL.");
			return(NULL);
		}

		if (fclose(infile) == EOF)
		{

			fprintf(stderr, "\n%s\n", "[WAR]  fclose error: issues may arise.");
			return(NULL);
		}
	}


    if (info->repair != FAIL)
     {
    	errno=0;
    	return(header);
     }

    else return NULL;
}


