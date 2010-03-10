/*
File:    auxiliary.c
Purpose: on-line help and auxiliary functions

dvda-author  - Author a DVD-Audio DVD

(C) Dave Chapman <dave@dchapman.com> 2005
(C) Revised version with zone-to-zone linking Fabrice Nicol <fabnicol@users.sourceforge.net> 2007, 2008

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

/* do not use code beautifiers/formatters for this file*/


#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>

#include <stdarg.h>
#include <sys/time.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>

#include <time.h>
#include "structures.h"
#include "ports.h"
#include "audio2.h"
#include "auxiliary.h"
#include "c_utils.h"
#include "file_input_parsing.h"
#include "commonvars.h"
#include "ports.h"


extern globalData globals;


void version()
{

    foutput("%s%s\n%s", "dvda-author version ", VERSION, "\nCopyright  2005 Dave Chapman; 2007, 2008 Fabrice Nicol; 2008 Lee and Tim Feldkamp\n\n");
    foutput("%s","Latest version available from http://dvd-audio.sourceforge.net/\n\n");
    foutput("%s","This is free software; see the source for copying conditions.\n\nWritten by Dave Chapman, Fabrice Nicol, Lee and Tim Feldkamp.\n\n");
    return;
}

void help()
{

#ifdef __WIN32__
    system("mode con cols=85 lines=50");
    system("title DVD-A author Help");
#endif

// Use double \n for help2man to work correctly between options

foutput("%s", "\n\ndvda-author "VERSION" creates high-resolution DVD-Audio discs from .wav, .flac and .oga audio files.\n\n");
foutput("%s","Usage: dvda-author [OPTION]...\n");
foutput("%s","\nOptions:\n\n");
foutput("%s","-h, --help               Diplay this help.\n\n");
foutput("%s","-v, --version            Diplay version.\n\n");
foutput("%s","-q, --quiet              Quiet mode.\n\n");
foutput("%s","-P, --pause              Insert a final pause before exiting.\n\n");
foutput("%s","-P0, --pause0            Suppress a final pause before exiting"J"if specified in configuration file.\n\n");
foutput("%s","-l, --log filepath       Ouput a log to filepath.\n\n");
foutput("%s","-p, --startsector NNN    Specify the number of the first sector"J"of the AUDIO_PP.IFO file in the output of mkisofs.\n\n");
foutput("%s","                         If NNN=0, falling back on 281 (default)."J"Without -p start sector will be computed automatically.\n\n");
foutput("%s","-g                       You may specify up to 9 groups of tracks."J"Minimum: one group.\n");
foutput("%s","                         Enter full path to files if input directory is not set"J"by [-i].\n\n");
foutput("%s","-i, --input directory    Input directory with audio files."J"Each subdirectory is a group.\n\n");
foutput("%s","-o, --output directory   Output directory.\n\n");
foutput("%s","-x, --extract disc[list] Extract DVD-Audio to directory -o."J"Groups are labelled g1, g2..."J"Optional comma-separated list of groups to be extracted"J"may be appended to disc path.\n\n");
foutput("%s","-V, --videodir directory Path to VIDEO_TS directory\n\n");
foutput("%s","-T, --videolink rank     Rank of video titleset linked to in video zone"J"(XX in VTS_XX_0.IFO)."J"In this case the path to the VIDEO_TS linked to"J"must be indicated.\n\n");
foutput("%s","-n, --no-videozone       Do not generate an empty VIDEO_TS directory.\n\n");
foutput("%s","-w, --rights             Access rights to directories created (octal values)\n\n");
foutput("%s","-d, --debug              Increased verbosity (debugging level)\n\n");
foutput("%s","-U, --PTS-factor (-)lag  Enter lag to be added/substracted (-) to title length,"J" in 10E-2 second.\n\n");
#ifndef WITHOUT_FIXWAV
foutput("%s","-F, --fixwav(options)    Bad wav headers will be fixed by fixwav\n\n");
foutput("%s","-f, --fixwav-virtual(options)  Use .wav header repair utility "J"without any write operation.\n\n");
#endif
#ifndef WITHOUT_SOX
foutput("%s","-S, --sox                Use SoX to convert files to .wav."J"By default, only flac, Ogg FLAC "J"and .wav files are accepted.\n\n");
#endif
foutput("%s","-0, --no-padding         Block padding of audio files by dvda-author.\n\n");


foutput("%s","\n\nSupported audio types: .wav\n");
#ifndef WITHOUT_FLAC
foutput("%s",    "                       .flac and .oga (Ogg FLAC, see below)\n");
#endif
#ifndef WITHOUT_SOX
foutput("%s","\n\n                       SoX-supported formats with -S enabled\n");

foutput("%s","                      except for lossy formats.\n");
#endif
foutput("%s","\n\nThere must be a maximum of 9 audio groups.\n\n");
foutput("%s","\nEach subdirectory of an audio input directory will contain titles\nfor a separate audio group.\n\
A number between 1 and 9 must be included as the second character of the subdirectory relative name.\n");
foutput("%s", "\nFull Input/Output paths must be specified unless default settings are set.\n");
foutput("\n%s", "By default, defaults are set in /full path to dvda-author folder/defaults\n");
foutput("%s", "\nExamples:\n");
foutput("%s", "\n\
-creates a 3-group DVD-Audio disc (legacy syntax):\n\n\
  dvda-author -g file1.wav file2.flac -g file3.flac -g file4.wav\n\n");
foutput("%s", "-creates a hybrid DVD disc with both AUDIO_TS mirroring audio_input_directory\n\
and VIDEO_TS imported from directory VID, outputs disc structure to directory\n");
foutput("%s", " DVD_HYBRID and links video titleset #2 of VIDEO_TS to AUDIO_TS:\n\n");
foutput("%s","  dvda-author -i ~/audio/audio_input_directory -o DVD_HYBRID -V ~/Video/VID -T 2 \n\n");
foutput("%s", "-creates an audio folder from an existing DVD-Audio disc:\n\n\
  dvda-author --extract /media/cdrom0,1,3,5,6,7 -o dir\n\n");
foutput("%s","will extract titlesets 1,3,5,6,7 of the disc to\n\
dir/g1, dir/g3, dir/g5, dir/g6, dir/g7 respectively.\n");

#ifndef WITHOUT_FIXWAV

foutput("%s", "\nfixwav options: \n\n\
  simple-mode\n\
   Deactivate default automatic mode and advanced options.\n\
   User will be asked for more information.\n\n\
  prepend\n\
   Prepend header to raw file\n\n\
  in-place\n\
   Correct header in the original file (not advised)\n\n\
  interactive\n\
   Request information from user.\n\n\
  padding\n\
   Pad files according to WAV standard (advised if prune not used)\n\n\
  prune\n\
   Cuts off silence at end of files\n\n\
  output=sf\n\
   Copy corrected file to new filepath with string suffix sf\n\n\
  Sub-options should be separated by commas and appended\n\
   to -f/-F or --fixwav(-virtual)\n\
   without any whitespace in between them.\n\n\
  Example: --fixwavsimple-mode,prepend,interactive,output=new\n\
");
#endif

foutput("%s", "\nRequired compile-time constants:\n_GNU_SOURCE, __CB__ if compiling with Code::Blocks or similar IDE.\n");

foutput("%s", "\nOptional compile-time constants:\nLONG_OPTIONS for the above long options (starting with --)\n\
SHORT_OPTIONS_ONLY to block all long options.\n\
LOCALE to recompile for another locale than the default \"C\".\n\
SETTINGSFILE to specify default filepath of the configuration file.\n\
FLAC__HAS_OGG to enable Ogg FLAC support.\n\
_LARGEFILE_SOURCE,_LARGE_FILES,_FILE_OFFSET_BITS=64\n\
enable large file support.\n\
ALWAYS_INLINE forces code inlining.\n\
WITHOUT_SOX to compile without SoX code\n\
WITHOUT_FLAC to compile without FLAC/OggFLAC code\n\
WITHOUT_FIXWAV to compile without fixwav code\n\n");

foutput("%s", "\nReport bugs to fabnicol@users.sourceforge.net\n");
return;
}



_Bool increment_ngroups_check_ceiling(int *ngroups, void * nvideolinking_groups)
{

    if (*ngroups < 9)
    {
        if (nvideolinking_groups != NULL)
        {
            if (*(int*) nvideolinking_groups + *ngroups < 9)
                ++*(int *)nvideolinking_groups;
            else
            {
                foutput("[ERR]  DVD-Audio only supports up to 9 groups; audio groups=%d; video-linking groups=%d\n", *ngroups, *(int *)nvideolinking_groups);
                clean_exit(EXIT_SUCCESS, DEFAULT);
            }
        }
        ++*ngroups;
    }
    else
    {
        if (nvideolinking_groups != NULL)
            foutput("[ERR]  DVD-Audio only supports up to 9 groups; audio groups=%d; video-linking groups=%d\n", *ngroups, *(int *)nvideolinking_groups);
        else
            foutput("[ERR]  DVD-Audio only supports up to 9 groups; audio groups=%d\n", *ngroups);
        clean_exit(EXIT_SUCCESS, DEFAULT);
    }
    return 1;
}

fileinfo_t** dynamic_memory_allocate(fileinfo_t **  files,int* ntracks,  int  ngroups, int n_g_groups, int nvideolinking_groups)
{

    float memory=0;
    int i, j;

    /*   n_g_groups: number of g-type audio groups ('Dave code usage')
     *   nvideolinking_groups: number of video-linking groups
     *   ngroups   : total number of groups
     *   ngroups = n_g_groups + nvideolinking_groups
     */


    if ((files= (fileinfo_t **) calloc(ngroups, sizeof(fileinfo_t *))) == NULL)
        EXIT_ON_RUNTIME_ERROR

        for (i=0 ; i < n_g_groups; i++)
        {
            if ((files[i]=(fileinfo_t *) calloc(ntracks[i], sizeof(fileinfo_t))) == NULL)
                EXIT_ON_RUNTIME_ERROR

                memory+=(float) (ntracks[i])*sizeof(fileinfo_t)/1024;

            if (globals.debugging)
                foutput("[MSG]  g-type  audio group  :  %d   Allocating:  %d  track(s)  (strings=%.1f kB)\n", i,  ntracks[i], memory);
        }
    for (i=n_g_groups ; i < ngroups-nvideolinking_groups; i++)
    {

        if ((files[i]=(fileinfo_t *) calloc(ntracks[i], sizeof(fileinfo_t)) )== NULL)
            EXIT_ON_RUNTIME_ERROR

            for (j=0; j < ntracks[i]; j++)
                if ((files[i][j].filename=calloc(CHAR_BUFSIZ, sizeof(char)) )== NULL)
                    EXIT_ON_RUNTIME_ERROR


                    memory+=(float) (ntracks[i])*(sizeof(fileinfo_t) + CHAR_BUFSIZ)/1024; // CHAR_BUFSIZ characters assigned later on by strdup
        if (globals.debugging)
            foutput("[MSG]  Directory audio group:  %d   Allocating:  %d  track(s)  (strings=%.1f kB)\n", i,  ntracks[i], memory);
    }
    for (i=ngroups-nvideolinking_groups ; i < ngroups; i++)
    {
        if ((files[i]=(fileinfo_t *) calloc(1, sizeof(fileinfo_t))) == NULL)
            EXIT_ON_RUNTIME_ERROR
            memory+=(float) sizeof(fileinfo_t)/1024;
        /* sanity check: 0 tracks should be allocated */
        if (globals.debugging)
            foutput("[MSG]  Video-linking group  :  %d   Allocating:  %d  track(s)  (strings=%.1f kB)\n", i, ntracks[i], memory);
    }

    return files;
}


void free_memory(command_t *command)
{
    int i, j;
    if (command)
    {
        for (i=command->n_g_groups; i < command->ngroups-command->nvideolinking_groups; i++)
            for (j=0; j < command->ntracks[i]; j++)
            {

                if (globals.debugging)
                    foutput("[INF]  Freeing i=%d  j=%d\n",i, j );
                FREE(command->files[i][j].filename)
            }

        for (i=0; i < command->ngroups; i++)
            FREE(command->files[i])
            FREE(command->files)
        }

    FREE(globals.settings.outdir)
    FREE(globals.settings.indir)
    FREE(globals.settings.linkdir)
    FREE(globals.settings.logfile)

}

