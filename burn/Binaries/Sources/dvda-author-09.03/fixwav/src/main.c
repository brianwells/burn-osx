#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#include <string.h>
#include <unistd.h>
#include <getopt.h>
#include <math.h>
#include <inttypes.h>
#include <errno.h>
#include <locale.h>

#include "structures.h"
#include "fixwav_manager.h"
#include "fixwav.h"
#include "fixwav_auxiliary.h"
#include "c_utils.h"
#include "audio.h"
#include "launch_fixwav.h"

#define ALLOWED_FIXWAV_OPTIONS "VhaApo:b:s:c:l:qdkSI"
#ifndef FIXWAV_SUFFIX
#define FIXWAV_SUFFIX "_fix_"
#endif


globalData globals;



int main(int argc, char* const argv[])
{

    extern char* optarg;
    extern int optind;

    int        k, option=0;

    /* Initializing stage */

    //to avoid issues with 44,1 versus 44.1 depending on locales
    setlocale(LC_ALL, "en_US");

    // by default, fixwav file_name changes input file in place


    globalData globals0={  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, FIXWAV_SUFFIX,  NULL,  NULL,  0,  0,  0,  NULL  };

    globals=globals0;

   	#ifdef LONG_OPTIONS
    int longindex=0;

	static struct option  longopts[]=
	{

	{"automatic", no_argument, NULL, 'a'},
	{"dry", no_argument, NULL, 'd'},
	{"help", no_argument, NULL, 'h'},
	{"log", required_argument, NULL, 'l'},
	{"prepend", no_argument, NULL, 'p'},
	{"outdir", required_argument, NULL, 'o'},
    {"autorename", no_argument, NULL, 'A'},
	{"quiet", no_argument, NULL, 'q'},
	{"version", no_argument, NULL, 'V'},
	{"bit-rate", required_argument, NULL, 'b'},
	{"sample-rate", required_argument, NULL, 's'},
	{"channels", required_argument, NULL, 'c'},
	{"prune", no_argument, NULL, 'k'},
	{"interactive", no_argument, NULL, 'I'},
	{"suffix", required_argument, NULL, 'S'},
	{NULL, 0, NULL, 0}
	};


	#endif

   // Avoiding using getopt twice, as there may be reordering issues;

    char* logpath=NULL;

    for (k=1; k < argc; k++)

    {
        if  (strcmp(argv[k], "--quiet") * strcmp(argv[k], "-q") == 0) globals.silence=1;
        if  (strcmp(argv[k], "--log")    * strcmp(argv[k], "-l") == 0)
        {
            globals.logfile=1;
            if (k++ == argc)
            {
                fprintf(stderr, "%s\n", "[ERR]  option -l, --log must have an argument");
                exit(EXIT_FAILURE);
            }

            globals.journal=secure_open(argv[k], "ab");
            logpath=argv[k];

        }
    }

    FIXWAV_HEADER

    #ifdef LONG_OPTIONS

    while ((option=getopt_long(argc, argv, ALLOWED_FIXWAV_OPTIONS, longopts, &longindex)) != -1)

    #else

    while ((option=getopt(argc, argv, ALLOWED_FIXWAV_OPTIONS)) != -1)
    #endif
   {
        switch (option)
        {

        case  'V':
            // prints out version
            foutput("\n\n%s\nPress Y to exit...\n", FW_VERSION);
            if (isok()) exit(EXIT_SUCCESS);
            break;

        case  'h':
            // prints out help
            print_fixwav_help( argv[0] );
            if (isok()) exit(EXIT_SUCCESS);
            break;

        case  'a' :
            // automatic processing mode: tries to guess parameters
            globals.fixwav_automatic=1;
            foutput("\n%s\n", "[PAR]  Automatic mode will be used.");
            break;

        case 'p' :
            // prepends header data to raw soundfile
            globals.fixwav_prepend=1;
            foutput("\n%s\n", "[PAR]  Header will be prepended to raw data file.");
            break;

        case 'A':
            // output filename is different from input

            globals.fixwav_in_place=0;
            globals.fixwav_autorename=1;
            break;

        case 'I':
            globals.fixwav_interactive=1;
            foutput("\n%s\n", "[PAR]  Interactive mode.");
            break;

        case 'o':
            // output directory
            globals.fixwav_in_place=0;
            globals.fixwav_output_dir=optarg;
            foutput("\n[PAR]  Path to output directory is: %s.\n", optarg);
            break;

        case 'b':
            // bit rate
            globals.fixwav_interactive=0;
            globals.fixwav_bit_p_spl=(uint16_t) atoi(optarg);
            foutput("\n[PAR]  Bits per sample: %"PRIu16"\n", globals.fixwav_bit_p_spl );
            break;

        case 's':
            // sample rate
            globals.fixwav_interactive=0;
            globals.fixwav_sample_fq=(uint32_t) floor(1000*atof(optarg));
            foutput("\n[PAR]  Sample rate (in Hz): %"PRIu32"\n", globals.fixwav_sample_fq);
            break;

        case 'c':
            // number of channels
            globals.fixwav_interactive=0;
            globals.fixwav_channels=(uint16_t) atoi(optarg);
            foutput("\n[PAR]  Number of channels: %"PRIu16"\n", globals.fixwav_channels );
            break;


        case 'd':
            // "dry" mode
            foutput("%s", "\n[PAR]  Dry mode\n");
            globals.fixwav_virtual_enable=1;
            break;

        case 'k':
            // pruning files
            foutput("%s", "\n[PAR]  Pruning mode\n");
            globals.fixwav_prune=1;
            break;

        case 'S':
            foutput("\n[PAR]  Fixwav suffix: %s\n", optarg);
            globals.fixwav_suffix=optarg;
            break;

      case 'q': break;

      case 'l' :
            foutput("\n[PAR]  Path to log: %s\n", optarg );
            break;

        default:
            foutput( "%s\n\n", "[ERR]  Option unknown, see help below");
            print_fixwav_help();

        }
    }


    /* requests an obligatory argument */


    if (optind >= argc)
    {
        foutput( "%s", "[ERR]  Expected argument after options\n");
        exit(EXIT_FAILURE);
    }

    int i, type=1000;


    for (i=0; i < argc-optind; i++)
    {
        foutput("[INF]  Processing argument %s\n", argv[optind+i]);
        initialise_globals_fixwav(globals.silence, globals.logfile, globals.journal);
        wav_getinfo(argv[optind+i]);
    }

    if (errno) perror("[ERR]  Found error");

    return type;

}
