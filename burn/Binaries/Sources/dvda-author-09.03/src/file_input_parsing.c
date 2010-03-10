/*
File:    file_input_parsing.c
Purpose: parses input directories

dvda-author  - Author a DVD-Audio DVD

Copyright Fabrice Nicol <fabnicol@users.sourceforge.net> 2007, 2008

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
#include <errno.h>
#include "structures.h"
#include "file_input_parsing.h"
#include "commonvars.h"
#include "c_utils.h"
#include "libats2wav.h"
#include "ports.h"

#define MAX_GROUPS     9
#define MAX_GROUP_ITEMS        99

static int check_ignored_extension(void *);


extern globalData globals;

int read_tracks(char  *full_path, int *ntracks, char * parent_directory, char* filename, int ngroups_scan)
{

    if (ntracks[ngroups_scan] < MAX_GROUP_ITEMS)
    {

        if (parent_directory != NULL)
        {

            snprintf(full_path, CHAR_BUFSIZ, "%s%c%s%c%s", globals.settings.indir, '/', parent_directory,'/', filename);
        }
        else
            STRING_WRITE_CHAR_BUFSIZ(full_path, "%s", filename)

        }
    else
    {
        foutput("[MSG] Error: Too many input files specified - group %d, track %d\n",ngroups_scan,ntracks[ngroups_scan]);
        clean_exit(EXIT_SUCCESS, DEFAULT);
    }

    return(ntracks[ngroups_scan]);
}


parse_t
parse_directory(DIR* dir,  int* ntracks, int n_g_groups, int action, fileinfo_t **files)
{

    int ngroups_scan=0, ngroups=0, control=0;
    struct dirent *rootdirent;

    parse_t audiodir;

    char gnames[MAX_GROUPS][CHAR_BUFSIZ];
    int totng;
    int ng = 0;

    if (globals.debugging) foutput("%s\n", "[INF]  Parsing audio input directory");

    while ((rootdirent=readdir(dir) )!= NULL)
    {
        if (rootdirent->d_name[0] == '.') continue;

        if (ng > (MAX_GROUPS-1))
          {
            foutput("%s\n", "[MSG]  Warning: Too many groups ( > 9 ) specified in directory, rest ignored.");
            break;
          }
        (void *)strcpy(gnames[ng], rootdirent->d_name);
        ng++;
    }
  
    if (ng > 1)
        qsort(gnames, (size_t) ng, (size_t) CHAR_BUFSIZ, 
              (int (*) (const void *, const void *)) strcmp);
  
    totng = ng;
    ng = 0;
  
    while (ng < totng)
    {
        /* ngroups_scan is the rank of the parsed group read from the user's index in the directory name */

        ngroups_scan= atoi(gnames[ng]+1);

        if ((ngroups_scan > MAX_GROUPS) || (ngroups_scan < 1))
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Subdirectories must be labelled ljm, with l, m any letters and j a number of 1 - 9")

            change_directory(gnames[ng]);

        DIR *subdir;
        if ((subdir=opendir(".")) == NULL)
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Input directory could not be opened")


            struct dirent * subdirent;
        control++;

        /* Memory allocation will be based on user input ngroups = Max {ngroups_scan}  */

        ngroups=MAX(ngroups_scan, ngroups);

        ntracks[n_g_groups+ngroups_scan-1]=0;

        char tnames[MAX_GROUP_ITEMS][CHAR_BUFSIZ];
        int totnt;
        int nt = 0;
  
        while ((subdirent=readdir(subdir) )!= NULL)
        {
            if (subdirent->d_name[0] == '.') continue;
/* filter extensions, which are known not to be processed in this context */
            if (check_ignored_extension(subdirent->d_name) == 1) continue;
 
            if (nt > (MAX_GROUP_ITEMS-1))
            {
                foutput("[MSG] Warning: Too many input files (>99) specified in group %d, rest ignored.\n",ngroups_scan);
                break;
            }
  
            (void *)strcpy(tnames[nt], subdirent->d_name);
            nt++;
        }
  
        if (nt > 1)
            qsort(tnames, (size_t) nt, (size_t) CHAR_BUFSIZ, 
                  (int (*) (const void *, const void *)) strcmp);
  
        totnt = nt - 1;
        nt = 0;
  
        do
        {
            if (nt > totnt)
            {
                closedir(subdir);
                change_directory(globals.settings.indir);
                break;
            }

            /* assignment of values is based on ngroups_scan */

            ntracks[n_g_groups+ngroups_scan-1]++;

            if (action == READTRACKS)
            {
                char buf[CHAR_BUFSIZ]={0};

                read_tracks(buf, ntracks, gnames[ng], tnames[nt], ngroups_scan);

                if (globals.debugging)
                    foutput("[INF]  Copying directory files[%d][%d]\n", n_g_groups+ngroups_scan-1, ntracks[n_g_groups+ngroups_scan-1]-1);

                memmove(files[n_g_groups+ngroups_scan-1][ntracks[n_g_groups+ngroups_scan-1]-1].filename, buf, CHAR_BUFSIZ);

            }

          nt++;
        }

        while (1);

        ng++;
    }

    if (action != READTRACKS) foutput("[MSG]  %d groups/subdirectories were parsed; ngroups=%d\n", control, ngroups);

    /* Controlling for contiguousness of ngroups_scan values; a crash may occur if not ensured; letting it go however */

/* with sort, the above comment and the next code could be removed. */
    if (ngroups != control) foutput("%s", "[WAR]  Critical -- Groups are not labelled contiguously (g1, ... ,gn).\n");

    audiodir.ngroups=ngroups+n_g_groups;
    audiodir.ntracks=ntracks;

    return audiodir;
}

static int check_ignored_extension(void *path)
{
  char *ign_extension[] = {
                           ".cdindex",
                           ".cddb",
                           ".inf",
                           ".asc",
                           ".txt"
                         };
#define NUMCHAR (sizeof(ign_extension[0]))
#define NUMEXT (sizeof ign_extension / NUMCHAR)

  void *dotloc;
  int num = NUMEXT;

/* if no extension, ignored ! */
  if ((dotloc =  strrchr(path, '.')) == NULL) return (1);

  while (num--)
    if (strncasecmp(dotloc,ign_extension[num],NUMCHAR) == 0) return (1);
  return (0);
}

int parse_disk(DIR* dir,  int* ntracks, mode_t mode, const char* default_directory, char  *list)
{

    char ngroups_scan=0, control=0;
    struct dirent *rootdirent;

    if (globals.debugging)
        foutput("[INF]  Extracting to %s\n", globals.settings.outdir);


    while ((rootdirent=readdir(dir) )!= NULL)
    {
        if (rootdirent->d_name[0] == '.') continue;

        char * d_name_duplicate=strdup(rootdirent->d_name);
        // duplicating is necessary as strtok alters its first argument

        if (d_name_duplicate == NULL)
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  strdup error while parsing disk")

            // filenames must end in "_0.IFO" and begin in "ATS_"
            if (strcmp(strtok(d_name_duplicate , "_"), "ATS")) continue;
        /* ngroups_scan is XX in ATS_XX_0.IFO  */

        char buffer[3]={0};

        memcpy(buffer, strtok(NULL , "_"), 3);
        ngroups_scan= (char) atoi(&buffer[0]);

        // does not extract when a list (!=NULL) is given and buffer != a list member.
        if (list != NULL)
            if ( (ngroups_scan-list[0])*(ngroups_scan-list[1])*(ngroups_scan-list[2])*(ngroups_scan-list[3])
                    *(ngroups_scan-list[4])*(ngroups_scan-list[5])*(ngroups_scan-list[6])*(ngroups_scan-list[7])
                    *(ngroups_scan-list[8]))
                continue;

        if (strcmp(strtok(NULL , "_"), "0.IFO")) continue;

        FREE(d_name_duplicate)



        if (globals.debugging)
            foutput("[INF]  Extracting titleset %s ...\n", rootdirent->d_name);

        char output_buf[strlen(globals.settings.outdir) + 3 + 1];
        STRING_WRITE_CHAR_BUFSIZ(output_buf, "%s%s%d", globals.settings.outdir, "/g", ngroups_scan)

        secure_mkdir(
            output_buf,
            mode,
            default_directory);

        if (globals.debugging)
            foutput("[INF]  Extracting to directory %s ...\n", output_buf);

        if (ats2wav(rootdirent->d_name, output_buf) == EXIT_SUCCESS)
        {
            control++;
            if  (globals.debugging)

                foutput("%s\n", "[INF]  Extraction completed.");
        }
        else
        {
            foutput("[INF]  Error extracting audio in titleset %d\n", ngroups_scan);
            continue;
        }


    }

    if  (globals.debugging)
        switch (control)
        {
        case 1:
            foutput("\n%s", "[MSG]  One group was extracted.\n");
            break;
        case 0:
            foutput("\n%s", "[MSG]  No group was extracted.\n");
            break;
        default:
            foutput("\n[MSG]  %d groups were extracted.\n", control);
        }


    return control;
}

