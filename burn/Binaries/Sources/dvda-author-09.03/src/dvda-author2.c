/*

dvda-author2.c  - Author a DVD-Audio DVD

Copyright Fabrice Nicol <fabnicol@users.sourceforge.net> July 2008

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
#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <locale.h>
#include <errno.h>
#include <inttypes.h>
#include <string.h>

#include "structures.h"
#include "c_utils.h"
#include "audio2.h"
#include "auxiliary.h"
#include "commonvars.h"
#include "ports.h"
#include "file_input_parsing.h"
#include "launch_manager.h"
#include "command_line_parsing.h"
#include "lexer.h"

/*  Global  options */

globalData globals;

int main(int argc,  char* const argv[])
{

    int i=0;
    fileinfo_t **files=NULL;
    lexer_t   lexer_init;
    lexer_t   *lexer=&lexer_init;

#ifndef __MINGW32__
    struct rusage nothing, start;
    compute_t timer={&nothing, &start};
    starter(&timer);
#endif

    /*  DEFAULT   SETTINGS  */

    // Locale, time and log management

    setlocale(LC_ALL, "LOCALE");

    // Global settings are hard-code set by default as follows:

    globalData globals_init={ /*silence*/ 0,  // verbose by default
                                          /*logfile*/	 0,  // no log
                                          /*videozone*/  0,  // no video zone
                                          /*videolinking*/ 0,  // no video link
                                          /*end_pause*/  0,  // no end pause
                                          /*debugging*/  0,  // no debugging
                                          /*padding*/    1,  // always padding  by default
#ifndef WITHOUT_SOX
                                          /*sox_enable*/ 0,  // no use of SoX
#endif
#ifndef WITHOUT_FIXWAV
                                          /*fixwav_enable*/0,  // no use of fixwav
                                          /*fixwav_virtual_enable*/ 0,  // no use of fixwav (virtual headers)

                                          /* automatic behaviour */ 1,
                                          /* do not prepend a header */	  0,
                                          /* do not correct in place */   0,
                                          /* not interactive */           0,
                                          /* no padding */                0,
                                          /* prune */                     0,
                                          /* fixwav output suffix*/
                                          strdup(STANDARD_FIXWAV_SUFFIX),
                                          /*fixwav_parameters*/ NULL,
#endif
                                          /*journal (log)*/ NULL,
                                          /* it is necessary to use strdup as these settings may be overridden dynamically */

    {
        strdup(SETTINGSFILE),
        strdup(LOGFILE),  // logfile path
        strdup(INDIR), // input directory path
        strdup(OUTDIR),// output directory path
        strdup(LINKDIR)   // videolinked directory path
    }
                            };

    globals=globals_init;

    // If a default setting textfile exists, it overrides the above hard-coded defaults
    // Path to defaults settings file must be "Path/to/DVD-A author folder/dvda-author.conf"
    // or otherwise defined by symbolic variable SETTINGSFILE at compile time.
    // Default settings, either hard-code set or by defaults textfile, can be overridden by command-line.

    /* Lexer extracts default command line from dvda-author.conf and returns corresponding argc, argv
       yet this is useless if command line is just "--version" or "--help" or equivalents */

    if
    (strcmp(argv[1], "--version")*strcmp(argv[1], "--help")*strcmp(argv[1], "-v")*strcmp(argv[1], "-h") == 0)
    goto launch;


    lexer->nlines=N_OPTIONS;

    lexer->commandline=(char** ) calloc(2*N_OPTIONS, sizeof(char *));
    for (i=0; i < 2*N_OPTIONS; i++)
        lexer->commandline[i]=(char* ) calloc(MAX_OPTION_LENGTH+2, sizeof(char));

    config_lexer(SETTINGSFILE, lexer);

    /* create a static command_t structure
    *  in command_line_parsing.c from default command line created by lexer.
    *  Bufferize non-static files member values */

    command_t command0, *command=NULL;
    command=&command0;

    if (command == NULL)
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Could not allocate command-line structure")


	files=command_line_parsing(lexer->nlines, lexer->commandline, files, command)->files;

    for (i=0; i < 2*N_OPTIONS; i++)
        FREE(lexer->commandline[i])

    FREE(lexer->commandline)

        /* launch core processes after parsing user command-line, possibly overriding defaut values
         * Send back bufferized files values for command-line parsing */

launch:

        launch_manager(command_line_parsing(argc, argv, files, command));
    // allocated in command_line_parsing()

    /* Compute execution time and exit */

    SINGLE_DOTS
    COMPUTE_EXECTIME
    SINGLE_DOTS

    if (globals.end_pause) pause_dos_type();

    return(errno);

}

