/* ==========================================================================
*
*   auxiliary.c
*   originally designed by Pigiron, 2007.
*   current rewrite: Copyright Fabrice Nicol, 2008.
*
*   Description
*        Auxiliary input-output subs
* ========================================================================== */


#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "fixwav.h"
#include "fixwav_manager.h"
#include "fixwav_auxiliary.h"
#include "c_utils.h"


extern globals_fixwav globals_f;

/*********************************************************************
* Function: isok
*
* Purpose:  This function displays a yes/no prompt
*********************************************************************/

_Bool isok()
{

    if (globals_f.silence) return 1;
    char buf[FIXBUF_LEN]={0};

    get_input(buf);

    foutput_f("%c", '\n');

    // With silent mode, replies are implicitly OK.
    switch(toupper(buf[0]))
    {
    case 'Y':
        return 1;
        break;
    case 'N' :
        return 0;
        break;

	default  :
	    fprintf(stderr, "%s\n", "[WAR]  Unknown--Enter reply again");
	    return(isok());
    }
}

/*********************************************************************/
/* Function: get_input                                               */
/*                                                                   */
/* Purpose:  This function performs a "safe" read of the user's      */
/*           input and puts the results in the caller's buffer       */
/*********************************************************************/
void get_input( char* buf )
{
    if (fgets(buf, FIXBUF_LEN, stdin) == NULL)
       foutput_f("%s\n", "[ERR]  fgets crash");
    return;
}

/*********************************************************************/
/* Function: print_help                                              */
/*                                                                   */
/* Purpose:  This function displays a help message                   */
/*********************************************************************/


void print_fixwav_help()
{

foutput_f( "\n%s,", "Usage:  fixwav [-h|-V] [-a][-p][-d][-k][-q]\n\
               [-b bit rate] [-s sample rate][-c number of channels]\n");
foutput_f("%s",  "              [-o output_file_name][-l log_path] input_files\n");

foutput_f("%s", "Options\n");
foutput_f("%s", "-------\n\n\
-q|--quiet\n\n  silent mode: no dialog or screen output. Options -b, -s, -c must be set.\n\
  Warning: write operations will be enabled. -q should preferably be used first.\n\n\
-h|--help\n\n  prints this help\n\n\
-V|--version\n\n  prints version\n\n\
-a|--automatic\n\n  automatic mode\n\n\
  it is advised to use -o in conjunction with -a.\n\
  DO NOT use this mode if file has one of the following characteristics:\n\
   - three channels;\n\
   - bit rate is not 16 or 24 bits per sample.\n\n");

foutput_f("%s\n", "\
-p|--prepend\n\n  prepends new header to sound file. Input file must be raw (header-less).\n\n\
-k|--prune\n\n  prune file if terminated by zeros and adjust header.\n\n\
-d|--dry\n\n  corrects header and checks coherence without writing files.\n\n\
-b|--bit-rate\n\n  bit rate (number of bits per sample, e.g. 16 or 24)\n\n\
-s|--sample-rate\n\n  sample rate in kHz (number of samples per second, e.g. 44.1 or 96)\n\n\
-c|--channels\n\n  number of channels (1 to 6)\n\n");
foutput_f("%s\n", "\
-o|--output\n\n  followed by the filename (+path) of output file as argument.\n\n\
-l|--log\n\n  log filename (+path)\n\n\
Input filename (+path) is an obligatory argument.\n\n");
foutput_f("%s\n\n",  FW_VERSION );
foutput_f("%s\n",   "\
This utility will attempt to fix an invalid audio WAVE header.\n\
While it should function correctly for any valid number of channels,\n\
bits per sample, and samples per second, it will only work correctly\n\
on 'normal' WAVE files that contain a single data 'chunk'. Meaning\n\
that if the file has extra subchunks or any junk at the end of the\n\
file, it will create an incorrect WAVE header.\n\n\
Two processing modes are available: automatic mode and manual mode\n\n");
foutput_f("%s\n", "\
Manual mode\n\
-----------\n\
You must have some knowledge of how the WAVE file was recorded:\n\
\t* the number of bits per sample\n\
\t* the number of samples per second\n\
\t* the number of channels\n\n\
It will allways prompt before making any modifications to your\n\
existing file.\n\
if options -b, -s or -c are not used, a dialog will request values.\n\n\
Automatic mode\n\
--------------\n\
fixwav will try to automatically guess how the WAVE file was recorded\n\
and will perform repairs automatically.\n");
foutput_f("%s\n", "\
Please do not use in-place editing mode (see below) as erroneous\n\
guesses could damage your file.\n\n");
foutput_f("%s\n", "\
Examples\n\
--------\n\
Options which do not take arguments can be combined as in:\n\n\
fixwav  oldfile.wav  -ap -o newfile.wav\n\n\
or, alternatively:\n\nfixwav -o newfile.wav -a -p oldfile.wav\n\n\
Options can be placed in any order.\n\
Legacy syntax is still available and corresponds to in-place manual mode:\n\n\
fixwav oldfile.wav\n" );

foutput_f("%s\n", "Press Y to exit... ");
    return;
}



/*********************************************************************
* Function: hexdump_header
*
* Purpose:  This function displays the first HEADER_SIZE bytes of the file
*           in both hexadecimal and ASCII
*********************************************************************/


void hexdump_header(FILE* infile)
{
    unsigned char data[ HEX_COLUMNS ];
    size_t i, size=0, count=0, input=0;

    do
    {

        memset(data, 0, HEX_COLUMNS);

		/* Print the base address. */
		foutput_f("%08lX:  ", (long unsigned)count);


        input= Min(HEADER_SIZE-count, HEX_COLUMNS);
        count+=HEX_COLUMNS;


        size = fread(data, 1, input, infile);

        if ( size ==  input)
        {

                /* Print the hex values. */
            for ( i = 0; i < HEX_COLUMNS; i++ )
                    foutput_f("%02X ", data[i]);

               /* Print the characters. */
            for ( i = 0; i < HEX_COLUMNS; i++ )
                    foutput_f("%c", (i < input)? (isprint(data[i]) ? data[i] : '.') : ' ');

            foutput_f("%c", '\n');
        }
        else
        {
            foutput_f("%s\n", "[ERR]  Header was not properly read by hexdump_header()");
            foutput_f("%s\n\n", "[INT]  Press Y to exit");
            if (isok()) exit(EXIT_FAILURE);
        }

        /* break on partial buffer */
    } while ( count < HEADER_SIZE );

}


FILE * secure_open(char *path, char *context)
{
    FILE *f;

    if ( (f=fopen( path, context ))  == NULL )
    {
        foutput_f("[ERR]  Could not open '%s'\n", path);
        foutput_f("%s\n", "       FILE MAY BE CORRUPTED, press Y to exit..." );
        if (isok())
		exit(EXIT_FAILURE);
    }
    return f;

}


int end_seek(FILE *outfile)
{
	if( fseek(outfile, 0, SEEK_END) == -1)
	{
		foutput_f( "\n%s\n", "[ERR]  Error seeking to end of output file" );
		foutput_f( "%s\n", "     File was not changed\n" );
		if (isok())
			return(FAIL);
	}
   return(0);
}





