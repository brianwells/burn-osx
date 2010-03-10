/*

File:   c_utils.h
Purpose: utility library header

libc_utils.a utility library

Copyright Fabrice Nicol <fabnicol@users.sourceforge.net>, 2008

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



#ifndef C_UTILS_H_INCLUDED
#define C_UTILS_H_INCLUDED

#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <stdint.h>
#ifndef __MINGW32__
#include <sys/resource.h>
#endif



/* Structures */


typedef struct
 {
    struct rusage *nothing;
    struct rusage *start;
}compute_t;


/* Prototypes */

void initialise_c_utils(_Bool a, _Bool b, _Bool c,  FILE* f);
void clean_exit(int message, const char* default_directory);
void help();
void starter(compute_t *timer);
char* print_time(int);
int rm_empty_backup_dir(const char * rep);
int secure_mkdir ( const char *path, mode_t mode, const char* default_directory);
void print_commandline(int argc_count, char * const argv[]);
void change_directory(const char * filename);
int copy_file(const char *existing_file, const char *new_file);
int copy_file_p(FILE *infile, FILE *outfile);
int copy_directory(const char* src, const char* dest, mode_t mode);
void pause_dos_type();
int get_endianness();


/* sets the size of character-type buffers (command-line parsing etc). */

// if CHAR_BUSFIZ not defined at compile time, then is 512
#ifndef CHAR_BUFSIZ
#define CHAR_BUFSIZ    512
#endif


#ifndef LITTLE_ENDIAN
#define LITTLE_ENDIAN  1
#define BIG_ENDIAN  0
#endif

#define ERR_STRING_LENGTH   "ERR: string was truncated, maximum length is %d"


#ifndef foutput
#define foutput(X, ...)   do { if (!globals.silence) printf(X, __VA_ARGS__);\
							   if (!globals.logfile) break;\
							   fprintf(globals.journal, X, __VA_ARGS__);} while(0)
#endif


#define Min(X ,Y)    (((X) <= (Y))  ? (X):(Y))
#define MAX(X ,Y)    (((X) <= (Y))  ? (Y):(X))

/* STRING_WRITE is devised for strings allocated by arrays */

#define STRING_WRITE(X,Z,...)	 do { int chres, Y;\
                                      Y=sizeof(X); \
                                      if    ( ( chres = snprintf(X, Y , Z, __VA_ARGS__) ) >=  Y )  \
									  foutput("\n"ERR_STRING_LENGTH"\n", Y);\
                                      else   if (chres < 0 ) foutput( "\n[ERR] Error message:  %s\nCheck source code %s, line %d",  strerror(errno), __FILE__, __LINE__); } while(0);


#define STRING_WRITE_CHAR_BUFSIZ(X,Z,...)	 do { int chres;\
													 if    ( ( chres = snprintf(X, CHAR_BUFSIZ*sizeof(char) , Z, __VA_ARGS__) ) >=  CHAR_BUFSIZ )  \
														   foutput("\n"ERR_STRING_LENGTH"\n", CHAR_BUFSIZ);\
														   else   if (chres < 0 ) foutput( "\n[ERR] Error message:  %s\nCheck source code %s, line %d",  strerror(errno), __FILE__, __LINE__); } while(0);
/* ERROR MANAGEMENT

    Error management conventions:
       EXIT_SUCCESS is returned on errors caused by ill-formed user input.
       EXIT_FAILURE is reserved for internal errors (segfaults, etc.)
	EXIT_ON_ERROR is a macro for uncommented EXIT_FAILURE
	EXIT_ON_ERROR_VERBOSE  is a macro for commented EXIT_FAILURE (one argument string)
	in other contexts (EXIT_SUCCESS, complex EXIT_FAILURE... )  clean_exit is used, see auxiliaray.c
*/



#define EXIT_ON_ERROR(Y)  if (errno) do {   foutput( "\n%s\n       ::%d, %s\n", strerror(errno), __LINE__, __FILE__);\
															clean_exit(EXIT_FAILURE, Y); } while(0);

#define EXIT_ON_ERROR_VERBOSE(X, Y)  if (errno) do {   foutput( "\n%s\n%s\n       ::%d, %s\n", X, strerror(errno), __LINE__, __FILE__);\
																			  clean_exit(EXIT_FAILURE, Y);  } while(0);

#ifdef ALWAYS_INLINE
#define ALWAYS_INLINE_GCC __attribute__((always_inline))
#else 
#define ALWAYS_INLINE_GCC   
#endif



// These functions should be inlined hence in a header file

ALWAYS_INLINE_GCC inline static void  uint32_copy(uint8_t* buf, uint32_t x)
{
    buf[0]=(x>>24)&0xff;
    buf[1]=(x>>16)&0xff;
    buf[2]=(x>>8)&0xff;
    buf[3]=x&0xff;
}

ALWAYS_INLINE_GCC inline static void uint32_copy_reverse(uint8_t* buf, uint32_t x)
{
    buf[0]=x&0xff;
    buf[1]=(x&0xff00)>>8;
    buf[2]=(x&0xff0000)>>16;
    buf[3]=(x&0xff000000)>>24;
}


ALWAYS_INLINE_GCC inline static void uint16_copy(uint8_t* buf, uint16_t x)
{
    buf[0]=(x>>8)&0xff;
    buf[1]=x&0xff;
}

ALWAYS_INLINE_GCC inline static uint32_t uint32_read(uint8_t* buf)
{
	return( buf[0] << 24 | buf[1] << 16 | buf[2] << 8 | buf[3] );
}

ALWAYS_INLINE_GCC inline static uint16_t uint16_read(uint8_t* buf)
{
	return( buf[0] << 8 | buf[1] );
}





#endif // C_UTILS_H_INCLUDED
