#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <getopt.h>
#include <sys/time.h>
#include "structures.h"
#include "c_utils.h"
#include "audio2.h"
#include "auxiliary.h"
#include "commonvars.h"
#include "ports.h"
#include "file_input_parsing.h"
#include "launch_manager.h"
#include "dvda-author.h"
#include "fixwav_auxiliary.h"
#include "fixwav_manager.h"
#include "command_line_parsing.h"


/*  #define _GNU_SOURCE must appear before <string.h> and <getopt.h> for strndup  and getopt_long*/


globalData globals;
unsigned int startsector;



command_t *command_line_parsing(int argc, char* const argv[], fileinfo_t **files, command_t *command)
{


    /* command_t member initialisation: static typing ensures 0-initialisation and
     * preservation of values set at configuration stage */

    static int user_command_line;
    static int access_rights=0777;
    static int ngroups;
    static int n_g_groups;
    static int nvideolinking_groups;
    static int maximum_VTSI_rank;
    static int Udo;
  
    static int VTSI_rank[MAXIMUM_LINKED_VTS];
    static int ntracks[9]={0};
    extern char *optarg;
    extern int optind, opterr;
    int k, c;
    int errmsg, reset=0;
    _Bool allocate_files=0;
    DIR *dir;
    parse_t  audiodir;

    char **argv_scan=calloc(argc, sizeof(char*));
    
    startsector=-1; /* triggers automatic computing of startsector (Lee and Tim Feldman) */
    

    /* Initialisation: default group values are overridden if and only if groups are added on command line
     * Other values are left statically determined by first launch of this function                          */

    if (user_command_line) SINGLE_DOTS
        foutput("%s", "\n\n");

    // By default, videozone is generated ; use -n to deactivate.

    globals.videozone=1;

    /* crucial: initialise before any call to getopt */
    optind=0;
    opterr=1;

#ifdef LONG_OPTIONS
    int longindex=0;

    static struct option  longopts[]=
    {

        {"debug", no_argument, NULL, 'd'},
        {"fixwav", optional_argument, NULL, 'F'},
        {"fixwav-virtual", optional_argument, NULL, 'f'},
        {"help", no_argument, NULL, 'h'},
        {"input", required_argument, NULL, 'i'},
        {"log", required_argument, NULL, 'l'},
        {"no-videozone", no_argument, NULL, 'n'},
        {"output", required_argument, NULL, 'o'},
        {"startsector", required_argument, NULL, 'p'},
        {"pause", optional_argument, NULL, 'P'},
        {"quiet", no_argument, NULL, 'q'},
        {"sox", optional_argument, NULL, 'S'},
        {"videolink", required_argument, NULL, 'T'},
        {"PTS-factor", required_argument, NULL, 'U'},
        {"version", no_argument, NULL, 'v'},
        {"videodir", required_argument, NULL, 'V'},
        {"rights", required_argument, NULL, 'w'},
        {"no-padding", no_argument, NULL, '0'},
        {"extract", required_argument, NULL, 'x'},
        {NULL, 0, NULL, 0}
    };
#endif



    /* getopt is now used for command line parsing. To ensure compatibility with prior "Dave" versions, the easier way out
     *  is to duplicate the command line. Otherwise getopt reorders options/non-options and multiple arguments of -g ...
     *  are consequently misplaced */

    /* 0-reset only on command-line parsing in case groups have been defined in config file */

    for (k=0; k<argc; k++)
        if ((argv_scan[k]=strdup(argv[k])) == NULL)
            EXIT_ON_RUNTIME_ERROR

            if (user_command_line)
            {
#ifdef LONG_OPTIONS
                while (((c=getopt_long(argc, argv_scan, ALLOWED_OPTIONS, longopts, &longindex)) != -1) && (!reset))
#else
                while (((c=getopt(argc, argv_scan, ALLOWED_OPTIONS)) != -1) && (!reset))
#endif
                {
                    switch (c)
                    {
                    case 'g':
                    case 'T':
                    case 'i':
                        memset(ntracks, 0, 9);
                        ngroups=nvideolinking_groups=n_g_groups=0;
                        if (globals.debugging)
                            foutput("%s\n", "[INF]  Overriding configuration file specifications for audio input");
                        // Useless to continue parsing
                        reset=1;

                    }
                }
                optind=0;
            }

    /* COMMAND-LINE  PARSING: first pass for global behaviour option: log, help, version, verbosity */


#ifdef LONG_OPTIONS
    while ((c=getopt_long(argc, argv_scan, ALLOWED_OPTIONS, longopts, &longindex)) != -1)
#else
    while ((c=getopt(argc, argv_scan, ALLOWED_OPTIONS)) != -1)
#endif

    {
        switch (c)
        {
            /* On modern *nix platform this trick ensures long --help and --version options even if LONG_OPTIONS
             * is not defined. Not operational with Mingw to date 	*/


#ifndef LONG_OPTIONS
        case '-' :
            if  (strcmp(optarg, "version") == 0)
            {
                version();
                break;
            }

            if  (strcmp(optarg, "help") == 0)
#endif

            case 'h' :
            globals.silence=0;
            help();
            clean_exit(EXIT_SUCCESS, DEFAULT);
            break;

        case 'v' :
            globals.silence=0;
            version();
            clean_exit(EXIT_SUCCESS, DEFAULT);
            break;

        case 'q' :
            globals.silence=1;
            globals.debugging=0;
            break;

        case 'd':
            globals.debugging=1;
            globals.silence=0;
            break;

        case 'l' :

            globals.logfile=1;
            globals.settings.logfile=strndup(optarg, MAX_OPTION_LENGTH);
            if ((globals.journal=fopen(globals.settings.logfile, "ab")) == NULL)
                fprintf(stderr, "[ERR]  Logfile %s could not be opened", globals.settings.logfile);
            break;


        }
    }

    /* The c_utils library has independent global parameters which should be adjusted now */

    initialise_c_utils(globals.silence, globals.logfile, globals.debugging, globals.journal);

#ifndef WITHOUT_FIXWAV
    initialise_globals_fixwav(globals.silence, globals.logfile, globals.journal);
#endif

    if (!user_command_line)
        HEADER(PROGRAM, VERSION)

        SINGLE_DOTS

        if (globals.debugging)
        {
            if (user_command_line) foutput("%s\n", "[INF]  Parsing user command line");
            else foutput("%s\n", "[INF]  Parsing default command line");

            print_commandline(argc, argv);
            foutput("%c", '\n');
        }

    if (globals.logfile) foutput("%s%s\n", "[PAR]  Log file is: ", globals.settings.logfile);


    /* COMMAND-LINE PARSING: second pass to determine memory allocation (thereby avoiding heap loss)
     * We give up getopt here to allow for legacy "Dave" syntax with multiple tracks as -g arguments
     * (not compatible with getopt or heavy to implement with it.  */

    if (globals.debugging) foutput("%s\n", "[INF]  First scan of track list for memory allocation...");

    for (k=0; k < argc; k++)
    {
        if (argv[k][0] != '-') continue;
        if (argv[k][1] == 'g')
        {
            k++;
            for (; (k < argc)&&(argv[k][0] !='-'); k++)
                ntracks[n_g_groups]++;

            increment_ngroups_check_ceiling(&n_g_groups, NULL);
            k--;
        }
    }


    ngroups += n_g_groups;

    optind=0;
    opterr=1;

    fileinfo_t **files_dummy=NULL;

    /* COMMAND-LINE PARSING: third pass  to determine memory allocation with non-g options and getopt */


#ifdef LONG_OPTIONS
    while ((c=getopt_long(argc, argv_scan, ALLOWED_OPTIONS, longopts, &longindex)) != -1)
#else
    while ((c=getopt(argc, argv_scan, ALLOWED_OPTIONS)) != -1)
#endif

    {
        switch (c)
        {
        case 'w':
            /* input must be in octal form */
            access_rights=(mode_t) strtol(optarg, NULL, 8);
            foutput("[PAR]  Access rights (octal mode)=%o\n", access_rights);
            break;


        case 'g' :
            allocate_files=1;
            break;

        case 'i' :

            allocate_files=1;
            globals.settings.indir=strndup(optarg, MAX_OPTION_LENGTH);

            foutput("%s%s\n", "[PAR]  Input directory is: ", 	optarg);
            DIR *dir;

            if ((dir=opendir(optarg)) == NULL)
                EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Input directory could not be opened")

                change_directory(globals.settings.indir);
            audiodir=parse_directory(dir, ntracks, n_g_groups, 0, files_dummy);

            ngroups=audiodir.ngroups;

            memmove(ntracks, audiodir.ntracks, 9*sizeof(int));

            if (closedir(dir) == -1)
                foutput( "%s\n", "[ERR]  Impossible to close dir");

            break;

        case 'o' :

            globals.settings.outdir=strndup(optarg, MAX_OPTION_LENGTH);
            foutput("%s%s\n", "[PAR]  Output directory is: ", optarg);

            break;


        case 'T':

            allocate_files=1;

            if (nvideolinking_groups == MAXIMUM_LINKED_VTS)
            {
                foutput("[ERR]  Error: there must be a maximum of %d video linking groups\n      Ignoring additional links...\n\n", MAXIMUM_LINKED_VTS);
                break;
            }

            // VTSI_rank is the rank of the VTS that is linked to in VIDEO_TS directory
            VTSI_rank[nvideolinking_groups]=atoi(optarg);

            if   (VTSI_rank[nvideolinking_groups] > 99)
                EXIT_ON_RUNTIME_ERROR_VERBOSE( "[ERR]  There must be a maximum of 99 video titlesets in video zone. Try again...\n\n")

                if (nvideolinking_groups == 0)
                    maximum_VTSI_rank=VTSI_rank[nvideolinking_groups];
                else
                    maximum_VTSI_rank=MAX(VTSI_rank[nvideolinking_groups], maximum_VTSI_rank);

            globals.videozone=1;
            globals.videolinking=1;

            increment_ngroups_check_ceiling(&ngroups, &nvideolinking_groups);

            break;

            // Should be done as early as main globals are set, could be done a bit earlier (adding an extra parse)
#ifndef WITHOUT_FIXWAV

        case 'F' :
        case 'f' :


            /* adjusting fixwav library globals to current ones
             * use local variables to initialise */

            //initialise_fixwav(0, 0, NULL); to be initialised when fixwav comes back to lib status !

            if ((optarg != NULL) && (strstr(optarg, "help")))
            {
                print_fixwav_help();
                clean_exit(EXIT_SUCCESS, DEFAULT);
            }
            break;

#endif


        }
    }

    /* Here the group parameters are known: ngroups (total),  n_g_groups (legacy -g syntax), nvideolinking_groups */

    /* command line copy is now useless: freeing space */

    for (k=0; k<argc; k++)
        FREE(argv_scan[k])
        FREE(argv_scan)

        /* Performing memory allocation (calloc)
        *
        *  Ordering
        *  -----------
        *  Groups are ordered according to the following order : g-type groups < directory groups < video-linking groups
        *
        *  Allocation
        *  ------------
        *  g-type groups are granted "for free" as they are allocated by command-line argv parsing
        *  Directory groups are costly as they must bee allocated freshly
        *  Video-linking groups have just one track and are reordered with highest ranks */


        /* Allocate memory if and only if groups are to be (re)created on command line */

        if (allocate_files)
            files=dynamic_memory_allocate(files, ntracks, ngroups, n_g_groups, nvideolinking_groups);

    /* COMMAND-LINE PARSING: fourth pass to assign filenames without allocating new memory (pointing to argv) */


    int m, ngroups_scan=0;

    if ((n_g_groups)&&(globals.debugging)) foutput("%s", "[INF]  Assigning g-type filenames...\n");

    for (k=0; k < argc; k++)
    {
        if (argv[k][0] != '-') continue;
        if (argv[k][1] == 'g')
        {
            k++;

            for (m=0; (m+k < argc)&&(argv[m+k][0] !='-'); m++)
            {
                if (globals.debugging) foutput("       files[%d][%d].filename=%s\n", ngroups_scan, m, argv[m+k]);
                files[ngroups_scan][m].filename=argv[m+k];

            }
            k+=m-1;
            ngroups_scan++;

        }
    }


    foutput("%s", "\n\n");

    /* COMMAND-LINE  PARSING: fourth pass for main arguments and non-g filename assignment */


    // Changing scanning variable names for ngroups_scan and nvideolinking_groups_scan

    ngroups_scan=0;
    int nvideolinking_groups_scan=0;

    optind=0;
    opterr=1;


#ifdef LONG_OPTIONS
    while ((c=getopt_long(argc, argv, ALLOWED_OPTIONS, longopts, &longindex)) != -1)
#else
    while ((c=getopt(argc, argv, ALLOWED_OPTIONS)) != -1)
#endif


    {

        switch (c)
        {
            //  'x' Must come AFTER 'o' and 'w'

        case 'x' :


            ats2wav_parsing(optarg, ntracks, access_rights);
            return NULL;

        case 'T':

            ngroups_scan++;
            nvideolinking_groups_scan++;

            // allowing for a single title in video-linking group
            //  videolinkg groups are allocated in last position whatever the form of the command line
            ntracks[ngroups-nvideolinking_groups+nvideolinking_groups_scan-1]=0;

            files[ngroups-nvideolinking_groups+nvideolinking_groups_scan-1][0].first_PTS=0x249;
            // all other characteristics of videolinking titles ar null (handled by memset)

            break;

        case 'V' :
            //  video-linking directory to VIDEO_TS structure

            globals.videozone=1;
            globals.settings.linkdir=strndup(optarg, MAX_OPTION_LENGTH);
            foutput("%s%s\n", "[PAR]  VIDEO_TS input directory is: ", optarg);

            break;

        case 'n' :
            // There is no videozone in this case

            if (globals.videolinking)
            {
                foutput("%s\n", "[WAR]  You cannot delete video zone with -n if -V is activated too.\n      Ignoring -n...");
                break;
            }
            globals.videozone=0;
            foutput("%s\n", "[PAR]  No video zone");
            break;

        case 'i' :


            if ((dir=opendir(optarg)) == NULL)
                EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Input directory could not be opened")

			change_directory(globals.settings.indir);
			
            parse_directory(dir, ntracks, n_g_groups, READTRACKS, files);

            if (closedir(dir) == -1)
                foutput( "%s\n", "[ERR]  Impossible to close dir");

            /* all-important, otherwise irrelevant EXIT_ON_RUNTIME_ERROR will be generated*/

            errno=0;

            break;


        case 'p' :
        
            startsector=(int32_t) strtol(optarg, NULL, 10);
            errmsg=errno;
            switch (errmsg)
            {
            case   EINVAL :
                foutput( "%s\n",  "[ERR]  Incorrect offset value");
                clean_exit(EXIT_SUCCESS, DEFAULT);
                break;
            case   ERANGE :
                EXIT_ON_RUNTIME_ERROR_VERBOSE( "[ERR]  Offset range--overflowing LONG INT.");
                break;
            }
            errno=0;
            
            if (startsector) 
               foutput("[MSG]  Using start sector: %"PRId32"\n", startsector);
			else
			{
               foutput("[ERR]  Illegal negative start sector of %"PRId32"...falling back on automatic start sector\n", startsector);
               startsector=-1;
			}
               
            break;

        case 'P':
            if ((optarg != NULL) && (strcmp(optarg, "off") != 0))
            {
                globals.end_pause=0;
                foutput("%s\n", "[PAR]  End pause will be suppressed.");
            }
            else
            {
                globals.end_pause=1;
                foutput("%s\n", "[PAR]  Adding end pause.");
            }
            break;


        case 'U':

            /* Udo switch: -U x, where x is expressed in 10E-2 second;
            * e.g: -U -60 takes off 60/100 second out of PTS ticks; -U 60 adds it. */

            Udo=atoi(optarg)*900;  // expressed in PTS ticks
            foutput("[PAR]  Special Udo switch=%+d PTS ticks\n", Udo);
            break;

#ifndef WITHOUT_FIXWAV
        case 'f':
            globals.fixwav_virtual_enable=1;

            foutput("%s\n", "[PAR]  Virtual fixwav enabled.");
            // case 'F' must follow breakless

        case 'F':

            /* Uses fixwav to fix bad headers*/

            globals.fixwav_enable=1;
            globals.fixwav_parameters=optarg;
            foutput("%s\n", "[PAR]  Bad wav headers will be fixed by fixwav");
            if (optarg != NULL)
            {
                foutput("%s%s\n", "[PAR]  fixwav command line: ", optarg);

                /* sub-option analysis */

                fixwav_parsing(globals.fixwav_parameters);
            }


            break;
#endif

#ifndef WITHOUT_SOX

        case 'S':

            /* Uses sox to convert different input formats */
            globals.sox_enable=1;
            foutput("%s\n", "[PAR]  Audio formats other than WAV and FLAC will be converted by sox tool.");

            break;
#endif

        case '0' :
            globals.padding=0;
            foutput("%s\n", "[PAR]  No audio padding will be performed by core dvda-processes.");
            break;

        }
    }


    command_t command0=
    {
        access_rights,
        ngroups,
        n_g_groups,
        nvideolinking_groups,
        maximum_VTSI_rank,
        Udo,
        VTSI_rank,
        ntracks,
        files
    };

    errno=0;

    memcpy(command, &command0, sizeof(command0));

    user_command_line++;

    return(command);
}

#ifndef WITHOUT_FIXWAV
void fixwav_parsing(char *ssopt)
{
    int subopt;
    char * chain=ssopt;
    char* value=NULL;
    char* tokens[]=
        { "simple-mode","prepend","in-place","interactive","padding","prune","output",NULL};

    while ((subopt = getsubopt(&chain, tokens, &value)) != -1)
    {
        switch (subopt)
        {
        case 0:
            foutput("%s\n", "[PAR]  Fixwav: simple mode activated, advanced features deactivated.");
            globals.fixwav_automatic=0;
            break;

        case 1:
            foutput("%s\n", "[PAR]  Fixwav: prepending header to raw file.");
            globals.fixwav_prepend=1;
            break;

        case 2:
            foutput("%s\n", "[PAR]  Fixwav: file header will be repaired in place.");
            globals.fixwav_in_place=1;
            break;

        case 3:
            foutput("%s\n", "[PAR]  Fixwav: interactive mode activated.");
            globals.fixwav_interactive=1;
            break;

        case 4:
            foutput("%s\n", "[PAR]  Fixwav: padding activated.");
            globals.fixwav_padding=1;
            break;

        case 5:
            foutput("%s\n", "[PAR]  Fixwav: pruning silence at end of files.");
            globals.fixwav_prune=1;
            break;

        case 6:

            globals.fixwav_suffix=strndup(value, MAX_OPTION_LENGTH);
            foutput("[PAR]  Fixwav output suffix: %s\n", globals.fixwav_suffix);
            break;
        }
    }
    return;
}
#endif

void ats2wav_parsing(const char * arg, int* ntracks, int access_rights)
{

    char * chain, *subchunk, list[9]={0}, control=0;
    _Bool cut=0;
    DIR *dir;


    chain=strdup(arg);

    if (chain == NULL) EXIT_ON_RUNTIME_ERROR

        cut=(strchr(chain, ',') == NULL)? 0: 1 ;

    /* strtok modifies its first argument.
    * If ',' not found, returns all the string, otherwise cuts it */

    if (cut)
    {
        strtok(chain, ",");
        if (globals.debugging)
            foutput("%s\n", "[INF]  Analysing suboptions...");
    }

    globals.settings.indir=calloc(strlen(chain)+1+9, sizeof(char));

    if (globals.settings.indir == NULL) EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Could not allocate global settings")
        STRING_WRITE_CHAR_BUFSIZ(globals.settings.indir, "%s/AUDIO_TS", chain);

    change_directory(globals.settings.indir);
    if ((dir=opendir(globals.settings.indir)) == NULL)
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Could not open output directory")

        foutput("[INF]  Extracting audio from %s\n", globals.settings.indir);


    if (cut)
    {
        control=1;

        // Now strtok will return NULL is ',' not found, otherwise * to start of token

        while (((subchunk=strtok(NULL, ",")) != NULL) && (control < 9))
        {
            int index=(int) *subchunk-'0';
            if ((index > 8) || (index < 0))
            {
                index=0;
                foutput("%s\n", "[WAR]  Incorrect -x suboption, reset to 0.");
            }
            list[index]=*subchunk-'0';
            if (globals.debugging)
                foutput("[PAR]  ATS2WAV: titleset %d will be extracted.\n", list[index]);

            control++;
        }

        parse_disk(dir, ntracks, access_rights, OUTDIR, list);
    }
    else

        parse_disk(dir, ntracks, access_rights, OUTDIR, NULL);

    if (closedir(dir) == -1)
        foutput( "%s\n", "[ERR]  Impossible to close dir");

    /* all-important, otherwise irrelevant EXIT_ON_RUNTIME_ERROR will be generated*/


    errno=0;
    FREE(chain)
}
