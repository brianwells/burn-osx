#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include "structures.h"
#include "commonvars.h"
#include "audio2.h"
#include "ats.h"
#include "atsi.h"
#include "amg.h"
#include "samg.h"
#include "videoimport.h"
#include "c_utils.h"
#include "ports.h"
#include "auxiliary.h"


/* Remark on data structures:
 *   - command-line data belong to 'command' structures
 *   - software-level global variables are packed in 'globals' structures */
extern globalData globals;
extern unsigned int startsector;



command_t *assign_audio_characteristics(int* I, command_t *command)
{

    short int i, j, l, delta=0, error=0;
    i=I[0];
    j=I[1];
    extern globalData globals;



    // retrieving information as to sound file format

    error=wav_getinfo(&command->files[i][j]);

    // dealing with format information

    switch (error)
    {
    case AFMT_WAVE:
        if (globals.debugging) foutput("[MSG]  Found WAVE format for %s\n", command->files[i][j].filename);
        command->files[i][j].type=AFMT_WAVE;
        j++;
        break;
    case AFMT_WAVE_FIXED:
        if (globals.debugging) foutput("[MSG]  Found WAVE format (fixed) for %s\n", command->files[i][j].filename);
        command->files[i][j].type=AFMT_WAVE;
        j++;
        break;
    case AFMT_WAVE_GOOD_HEADER:
        if (globals.debugging) foutput("[MSG]  Found WAVE format (original) for %s\n", command->files[i][j].filename);
        command->files[i][j].type=AFMT_WAVE;
        j++;
        break;

#ifndef WITHOUT_FLAC
    case AFMT_FLAC:
        if (globals.debugging) foutput("[MSG]  Found FLAC format for %s\n", command->files[i][j].filename);
        error=flac_getinfo(&command->files[i][j]);
        j++;
        break;
    case AFMT_OGG_FLAC:
        if (globals.debugging) foutput("[MSG]  Found Ogg FLAC format for %s\n", command->files[i][j].filename);
        error=flac_getinfo(&command->files[i][j]);
        j++;
        break;
#endif

    case NO_AFMT_FOUND:
        if (globals.debugging) foutput("[ERR]  No compatible format was found for %s\n       Skippping file...\n", command->files[i][j].filename);

        // House-cleaning rules: getting rid of files with unknown format

        // taking off one track;

        command->ntracks[i]--;

        // group demotion: if there is no track left in groups, taking off one group

        if (command->ntracks[i] == 0)
        {
            // taking off one group

            command->ngroups--;
            // getting out of both loops, check end on inner=end of outer
            if (i == command->ngroups-command->nvideolinking_groups) return(command);

            // shifting indices for ntracks: all groups have indices decremented, so ntracks[g+1] is now ntracks[g]


            for (l=i; l < command->ngroups-command->nvideolinking_groups; l++)
            {
                command->ntracks[l]=command->ntracks[l+1];
                if (globals.debugging)
                    foutput("[INF]  Shifting track count for group=%d->%d\n", l+1, l+2);

            }
            // delta is a flag for group demotion
            delta=1;


        }
        // shifting indices for files (two cases: delta=0 for same group track-shifting, delta=1 for group demotion

        for (l=j; l < command->ntracks[i+delta]; l++)
        {

            // a recursion is in unavoidable save for j=last track in group
            int i_shift=i+delta;
            int l_shift=l+1-delta;
            if (globals.debugging)
                foutput("[INF]  Shifting indices for group=%d->%d, track=%d->%d\n", i+1, i_shift+1, l+1, l_shift+1);

            command->files[i][l]=command->files[i_shift][l_shift];

        }



        break;

    }


// assigning channel





// if AFMT was found, j will have been incremented earlier
// otherwise i is necessary to reparse again command->files[i][j] as indices have been shifted

    I[0]=i, I[1]=j;

    _Bool increment_group=(I[1] == command->ntracks[I[0]]);

    I[1] *= 1-increment_group;
    I[0] += increment_group;


    if (I[0] == command->ngroups-command->nvideolinking_groups)

        return command;

// recursion
    assign_audio_characteristics(I, command);

    return(command);
}


int launch_manager(command_t *command)

{
    errno=0;
    char audiotsdir[CHAR_BUFSIZ+9];
    char videotsdir[CHAR_BUFSIZ+9];
    int i, j, error, atsi_sectors[9]={0}, indices[2]={0};
    uint32_t  last_sector;
    uint64_t totalsize=0;
    uint64_t sector_pointer_VIDEO_TS=0;
    short int cgadef[] = {0, 1, 2, 3, 6, 20};

    /* sanity check */
    if (command == NULL)
    {
        free_memory(command);
        return(EXIT_SUCCESS);
    }


    secure_mkdir(globals.settings.outdir, command->access_rights, DEFAULT);

    if ((audiotsdir == NULL) || (videotsdir == NULL))
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Could not allocate filepaths to _TS directory");

    STRING_WRITE_CHAR_BUFSIZ(audiotsdir, "%s/AUDIO_TS", globals.settings.outdir)

    secure_mkdir(audiotsdir, command->access_rights, DEFAULT);
    errno=0;

    if (globals.videozone)
    {
        STRING_WRITE_CHAR_BUFSIZ(videotsdir, "%s/VIDEO_TS", globals.settings.outdir)
        secure_mkdir(videotsdir, command->access_rights, DEFAULT);
        errno=0;
    }

    /* Step 1 - parse all audio files and store the file formats, lengths etc */

    SINGLE_DOTS

    assign_audio_characteristics(indices, command);


    foutput("\n\n%s\n", "DVD Layout:\n\n");
    foutput("%s\n", "Group  Track    Rate Bits  Ch        Length  Filename\n");

    int naudio_groups=command->ngroups-command->nvideolinking_groups;

    for (i=0; i < naudio_groups; i++)
    {
        for (j=0; j < command->ntracks[i];  j++)
        {

            command->files[i][j].cga=cgadef[command->files[i][j].channels-1];
            command->files[i][j].PTS_length += command->Udo;

            foutput("    %d     %02d  %6"PRIu32"   %02d   %d   %10"PRIu64"   ",i+1, j+1, command->files[i][j].samplerate, command->files[i][j].bitspersample, command->files[i][j].channels, command->files[i][j].numsamples);
            foutput("%s\n",command->files[i][j].filename);
            totalsize+=command->files[i][j].numbytes;
        }
    }

    foutput("%c\n", '\n');

    foutput("[MSG]  Size of raw PCM data: %"PRIu64" bytes (%.2f  MB)\n\n",totalsize, (float) totalsize/(1024*1024));

    /* Audio zone system file  parameters  */

    unsigned int ppadd = 0, approximation;
	
    for (i=0; i < naudio_groups; i++)
    {
        error=create_ats(audiotsdir,i+1,&command->files[i][0],command->ntracks[i]);
        ppadd-=error;
        error=create_atsi(audiotsdir,i+1,&command->files[i][0],command->ntracks[i],&atsi_sectors[i]);
    }
    /* This approximation was contributed by Lee and Tim feldkamp */
    
     approximation=275+3*naudio_groups+ppadd;
    
    /* End of formula */
    
    switch (startsector)
    {
    
	  case  -1:
	 
		startsector=approximation; /* automatic computing of startsector (Lee and Tim Feldman) */
		foutput("[MSG]  Using start sector based on AOBs: %d\n",approximation);
		break;
	 
	  case  0:
	    startsector=STARTSECTOR; /* default value is 281 (Dave Chapman setting) */
	    foutput("%s", "[MSG]  Using default start sector 281\n");
	    break;
	  
	  default:
	  
        foutput("[MSG]  Using specified start sector %d instead of estimated %d\n",startsector,approximation);
    }
	

    /* Creating AUDIO_PP.IFO */

    last_sector=create_samg(
                    audiotsdir,
                    command->files,
                    command->ntracks,
                    command->ngroups,
                    command->nvideolinking_groups,
                    atsi_sectors);

    /*   sector_pointer_VIDEO_TS= number of sectors for AOBs + 2* SIZE_AMG + 2* SIZE_ATS*command->ngroups   */

    sector_pointer_VIDEO_TS= 2*SIZE_AMG;

    for (i=0; i < naudio_groups; i++)
    {
        for (j=0; j < command->ntracks[i]; j++)
        {
            sector_pointer_VIDEO_TS+=command->files[i][j].last_sector - command->files[i][j].first_sector+1;
        }
        sector_pointer_VIDEO_TS +=2*atsi_sectors[i];
    }

    if (globals.debugging)
    {
        foutput( "       Sector pointer to VIDEO_TS from AUDIO_TS= %"PRIu64" sectors\n", sector_pointer_VIDEO_TS);
        foutput( "\n%s", "[INF]  Checking coherence of pointers...");

        if (SIZE_SAMG + startsector + sector_pointer_VIDEO_TS != last_sector+1+atsi_sectors[naudio_groups-1])

            foutput("\n[WAR]  Pointers to VIDEO_TS are not coherent %"PRIu64" , %"PRIu32"\n",
                    SIZE_SAMG + startsector + sector_pointer_VIDEO_TS, (uint32_t) last_sector+1+atsi_sectors[naudio_groups-1]);
        else
            foutput("%s\n", " OK");
    }

    foutput( "\n[MSG]  Total size of AUDIO_TS: %"PRIu64" sectors\n", sector_pointer_VIDEO_TS + SIZE_SAMG);

    foutput( "[MSG]  Start offset of  VIDEO_TS in ISO file: %"PRIu64" sectors,  offset %"PRIu64"\n\n", sector_pointer_VIDEO_TS + SIZE_SAMG + startsector,
             (sector_pointer_VIDEO_TS + SIZE_SAMG + startsector)*2048);

    /* Creating AUDIO_TS.IFO */

    uint32_t  relative_sector_pointer_VTSI[command->nvideolinking_groups];
    uint32_t  videotitlelength[command->nvideolinking_groups];

    memset(relative_sector_pointer_VTSI, 0, command->nvideolinking_groups*4);
    memset(videotitlelength, 0, command->nvideolinking_groups*4);

//  relative_sector_pointer_VTSI=absolute_se+relative_sector_pointer_in_VTS

    /*
    *   Version 200806: added to function create_amg:
    *
    *   int VTSI_rank[N]
    *								VTSI_rank[k]	= rang of k-th video titleset linked to in video zone (< 10)
    *
    *   uint32_t  relative_sector_pointer_VTSI[N]
    *								relative_sector_pointer_VTSI[k] = & VTS_XX_0.IFO -&AUDIO_TS.IFO, expressed in sectors, in which XX=VTSI_rank[k]
    *
    *   uint32_t  videotitlelength[[N]
    *							   videotitlelength[k] = length of title linked to in PTS ticks
    *
    *   N= number of video linking groups in audio zone ( + number of audio groups < 10)
    *
    *
    */

// returns relative_sector_pointer_VTSI and videotitlelength

    if (globals.videolinking)
    {

        get_video_system_file_size(globals.settings.linkdir, command->maximum_VTSI_rank, sector_pointer_VIDEO_TS, relative_sector_pointer_VTSI);
        get_video_PTS_ticks(globals.settings.linkdir, videotitlelength, command->nvideolinking_groups, command->VTSI_rank);

        char    newpath[CHAR_BUFSIZ];
        STRING_WRITE_CHAR_BUFSIZ(newpath, "%s%s", globals.settings.outdir, "/VIDEO_TS")
        if (globals.videozone)
            copy_directory(globals.settings.linkdir, newpath, command->access_rights);
    }

    errno=create_amg(
              audiotsdir,
              command->files,
              command->ntracks,
              command->ngroups,
              command->nvideolinking_groups,
              atsi_sectors,
              videotitlelength,
              command->VTSI_rank,
              relative_sector_pointer_VTSI);

    EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Audio zone system files could not be created.")

    errno=0;

    foutput("%c\n", '\n');
    foutput("%s\n" , "Group  Track    First Sect   Last Sect  First PTS   PTS length\n");

    for (i=0; i < command->ngroups; i++)
    {
        for (j=0; j < command->ntracks[i]; j++)
        {
            foutput("    %d     %02d  %10"PRIu32"  %10"PRIu32"  %10"PRIu64"  ",i+1,j+1,command->files[i][j].first_sector,command->files[i][j].last_sector,command->files[i][j].first_PTS);
            foutput("%10"PRIu64"\n",command->files[i][j].PTS_length);
        }
    }

    /* freeing */

    foutput("%c", '\n');

    // freeing command->files and heap-allocated globals

    free_memory(command);

    return (errno);
}
