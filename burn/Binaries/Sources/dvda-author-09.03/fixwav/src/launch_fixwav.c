#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <inttypes.h>

#include "structures.h"
#include "fixwav_manager.h"
#include "fixwav.h"
#include "fixwav_auxiliary.h"
#include "c_utils.h"
#include "audio.h"
#include "launch_fixwav.h"



extern globalData globals;



void create_output_filename(char* filename, char** buffer)
{


    int count;
    int filelength=strlen(filename);
    size_t bufsize;


    if (secure_mkdir(globals.fixwav_output_dir, 0777, "../fixwav_output") == -1)
       foutput("[WAR]  Did not create directory %s\n", globals.fixwav_output_dir);

    // Truncating filenames to dir paths

    for (count=0; count <= filelength && filename[filelength-count] != '/' && filename[filelength-count] != '\\'; count++);

    //  Truncating filenames

    char temp[count-4];
    memcpy(temp, filename+filelength-count+1, count-5);
    temp[count-5]='\0';


   if (globals.fixwav_autorename)
   {

    char *outstring=print_time(0);

    bufsize=strlen(globals.fixwav_output_dir) +  strlen(globals.fixwav_suffix) + strlen(outstring)+ count + 1 + 1;

    *buffer=malloc(bufsize*sizeof(char));

    if (*buffer == NULL)
     {
       perror("[ERR] malloc");
       exit(EXIT_FAILURE);
     }

    if (bufsize > BUFSIZ)
    {
     foutput("[WAR]  Shortening -o filename (exceeds %d bytes)", BUFSIZ);
     bufsize=BUFSIZ;
    }
    snprintf(*buffer, bufsize, "%s/%s%s%s%s", globals.fixwav_output_dir, temp, globals.fixwav_suffix, outstring, ".wav");

   }
   else
   {
    bufsize=strlen(globals.fixwav_output_dir) + count + 1 + 1;
    if (bufsize > BUFSIZ)
    {
     foutput("[WAR]  Shortening -o filename (exceeds %d bytes)", BUFSIZ);
     bufsize=BUFSIZ;
    }
    *buffer=malloc(bufsize*sizeof(char));

    if (*buffer == NULL)
     {
       perror("[ERR] malloc");
       exit(EXIT_FAILURE);
     }

    if (bufsize > BUFSIZ)
    {
     foutput("[WAR]  Shortening -o filename (exceeds %d bytes)", BUFSIZ);
     bufsize=BUFSIZ;
    }
    snprintf(*buffer, bufsize,  "%s/%s%s", globals.fixwav_output_dir, temp, ".wav");

   }

return;
}



int launch_fixwav_library(char* filename)
{
WaveHeader  waveheader;
char* output_filename=NULL;

if (!globals.fixwav_in_place)
    create_output_filename(filename, &output_filename);

WaveData wavedata={
        filename,
        (globals.fixwav_in_place)? filename : output_filename,
        globals.fixwav_automatic, /* automatic behaviour */
        globals.fixwav_prepend, /* do not prepend a header */
        globals.fixwav_in_place, /* do not correct in place */
        globals.fixwav_interactive, /* not interactive */
        globals.fixwav_padding, /* padding */
        globals.fixwav_prune, /* prune */
        globals.fixwav_virtual_enable, /* whether header should be fixed virtually */
        0  /* repair status */
        };



// When user sets audio characteristics with -b,-s,-c flags
//  on command line (not interactive mode)

if (!globals.fixwav_interactive)
{
    waveheader.channels=globals.fixwav_channels;
    waveheader.sample_fq=globals.fixwav_sample_fq;
    waveheader.bit_p_spl=globals.fixwav_bit_p_spl;
}

foutput("[INF]  Fixwav diagnosis for: %s\n\n", filename);

SINGLE_DOTS

// Launching libfixwav.a

if (fixwav(&wavedata, &waveheader) == NULL )
    {
        SINGLE_DOTS
        foutput("\n\n%s\n", "[INF]  Fixwav repair was unsuccessful; file will be skipped.");
        return(NO_AFMT_FOUND);
    }


else
    {
        SINGLE_DOTS

        if (wavedata.repair == GOOD_HEADER)
        {
            foutput("%s", "[MSG]  Proceed with same file...\n");

            return(AFMT_WAVE_GOOD_HEADER);
        }
        else
        {
            if (!globals.fixwav_virtual_enable)
               foutput("[MSG]  Proceed with fixed file %s:\n", wavedata.outfile );

            else
                foutput("[MSG]  Proceeding with virtual header and same file %s:\n", wavedata.outfile );

            foutput("       Bits per sample=%"PRIu16", Sample frequency: %"PRIu32", Channels:%"PRIu16"\n", waveheader.bit_p_spl, waveheader.sample_fq,  waveheader.channels );
            return(AFMT_WAVE_FIXED);
        }

    }

if (output_filename != NULL) free(output_filename);

}



int wav_getinfo(char* filename)
{
    unsigned char header[44]; // Assume 44-byte canonical headers for now...
    FILE* fp;
    int type;

    fp=fopen(filename,"rb");
    if (fp == NULL)
        foutput("%s\n", "[ERR]  Could not open audio file: pointer is null");

    fread(header,44,1,fp);
    fclose(fp);

    if ((memcmp(header,"RIFF",4)!=0) || (memcmp(&header[8],"WAVEfmt",7)!=0))
    {
        /* Other formats than WAV: parsing headers */

      foutput("%s\n", "[WAR]  No WAV-compliant header was found");
      type=NO_AFMT_FOUND;
    }

    type=AFMT_WAVE;

       /* parsing header again with FIXWAV utility */

   type=launch_fixwav_library(filename);

    return(type);
}

