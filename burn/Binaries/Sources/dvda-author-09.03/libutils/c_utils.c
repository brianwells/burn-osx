/*

File:   c_utils.c
Purpose: utility library

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

#if HAVE_CONFIG_H
#include <config.h>
#endif

#include <stdlib.h>
#include <stdio.h>
#ifdef __WIN32__
#include <io.h>
#endif
#include <dirent.h>
#include <stdarg.h>
#include <sys/time.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* foutput is a public macro
 * foutput_c is a private one
 * using both public and private macros */
//#include "ports.h"
#include "c_utils.h"
#include "private_c_utils.h"

#undef foutput
#define foutput  foutput_c
#undef globals
#define globals  globals_c


/* global parameters in libc_utils may be independently set par initialise_c_utils */

global_utils globals_c;


void initialise_c_utils(_Bool a, _Bool b, _Bool c,  FILE* f)
{
	globals_c.silence=a;

	globals_c.logfile=b;
	globals_c.debugging=c;
	globals_c.journal=f;
}


void pause_dos_type()
{
char reply;
  do
    {
      fprintf(stderr, "\n%s\n", "Press Enter to continue...");
      scanf("%c", &reply);
      fflush(stdin);
    }
  while (0);
}


/*********************************************************************************************************
 * function: rm_empty_backup_dir
 *   securely removes empty backup directories, doing security tests.
 **********************************************************************************************************/


int rm_empty_backup_dir(const char * rep)
{
  DIR *dir;
  if (((dir=opendir(rep)) != NULL) &&   (rmdir(rep) == -1))
    return(0);
  else
    return(1);

  closedir(dir) ;
  errno=0 ;
  return(0);
}

/*********************************************************************************************************
 * function: clean_exit
 *   logs time; flushes all streams;  erase empty backup dirs; closes log;
 *   pauses before exiting, with different behaviour on Linux and Windows.
 **********************************************************************************************************/

void clean_exit(int message, const char *default_directory)
{

  fflush(stdout);

  rm_empty_backup_dir(default_directory);

  if (globals_c.logfile)
    {
      fflush(globals_c.journal);
      fclose(globals_c.journal);
    }

  pause_dos_type();
  exit(message);
}

/****************************************************************
* function: secure_mkdir
*   Creates directories.
****************************************************************/

int secure_mkdir (const char *path, mode_t mode, const char* default_directory)
{

  int i=0, len;
  len = strlen (path);

  // requires std=c99


  if  ((len<=1) && (globals_c.debugging))
  {
  foutput_c("%s\n","[ERR]  Path length could not be allocated by secure_mkdir:\n       Your compiler may not be C99-compliant");
  foutput_c("       path=%s, length=%d\n",path,len);
  clean_exit(EXIT_FAILURE,default_directory);
  }

  char d[len+1];
  memset(d, 0, len+1);

  memmove(d, path, len+1);

  if (d == NULL)
    {
      perror("[MSG] Error: could not allocate directory path string");
      pause_dos_type();
      clean_exit(EXIT_FAILURE, default_directory);
    }


  for (i = 1; i < len; i++)
    {
      if (('/' == d[i]) || ('\\' == d[i]))
        {
          #if defined __WIN32__ || defined __CYGWIN__
           if (d[i-1] == ':') continue;
          #endif
          d[i] = '\0';

          if ((MKDIR(d, mode) == -1) && (EEXIST != errno))

           {
              foutput_c( "Impossible to create directory '%s'\n", d);
              foutput_c("%s", "Backup directories will be used.\n " );
              pause_dos_type();
              exit(EXIT_FAILURE);

            }
          d[i] = '/';


        }

    }
  // loop stops before end of string as dirpaths can optionally end in '/' under *nix

  if  (MKDIR(path, mode) == -1)
    {
      if (EEXIST == errno)
        {
          errno=0;
          foutput_c("[MSG]  Output directory '%s' already created\n", path);
          return(0);
        }
      foutput_c("[ERR]  Impossible to create directory '%s'\n", path);
      foutput_c("       permission was: %d\n       %s\n", mode, strerror(errno));
      foutput_c( "%s", "       Backup directories will be used.\n");
      errno=0;
      pause_dos_type();
      exit(EXIT_FAILURE);
    }

  return(errno);
}


void starter(compute_t *timer)
{
// The Mingw compiler does not support getrusage
#ifndef __MINGW32__
  getrusage(RUSAGE_SELF, timer->start);
  getrusage(RUSAGE_SELF, timer->nothing);
  timer->nothing->ru_utime.tv_sec -= timer->start->ru_utime.tv_sec;
  timer->nothing->ru_stime.tv_sec -= timer->start->ru_stime.tv_sec;

#endif

}

void print_commandline(int argc, char * const argv[])
{
  int i=0;

  foutput_c("%s \n", "[INF]  Running:");

  for (i=0; i < argc ; i++)
    foutput_c(" %s  ",  argv[i]);
  foutput_c("%s", "\n\n");

}

char* print_time(int verbose)
{
  char outstr[200];
  time_t t;
  struct tm *tmp;

  t = time(NULL);
  tmp = localtime(&t);
  if (tmp == NULL)
    {
      perror("localtime");
      exit(EXIT_FAILURE);
    }

  if (strftime(outstr, sizeof(outstr), "%d-%H-%M-%S", tmp) == 0)
    {
      if (verbose) foutput_c("%s\n", "strftime returned 0");
      exit(EXIT_FAILURE);
    }

  if (verbose)
  {
  	foutput_c("\nCurrent time is: %s", outstr);
  	return NULL;
  }
  else
  return(strdup(outstr));
}

void change_directory(const char * filename)
{
  if (chdir(filename) == -1)
    {
      if (errno == ENOTDIR)
        foutput_c("[ERR]  %s is not a directory\n", filename);
      foutput_c("[ERR]  input file %s does not comply with chdir  specifications\n.", filename);
      pause_dos_type();
      exit(EXIT_FAILURE);
    }
}

int copy_directory(const char* src, const char* dest, mode_t mode)
{

  DIR *dir_src;

  struct stat buf;
  struct dirent *f;
  char path[BUFSIZ];

  if (stat(dest, &buf) == -1)
  {
  	perror("[ERR]  copy_directory could not stat file");
    exit(EXIT_FAILURE);
  }


  foutput_c("%c", '\n');

  if (globals_c.debugging)  foutput_c("%s%s\n", "[INF]  Creating dir=", dest);

  secure_mkdir(dest, mode, "./");

  if (globals_c.debugging)   foutput_c("[INF]  Copying in %s ...\n", src);
  change_directory(src);

  dir_src=opendir(".");

  while ((f=readdir(dir_src)) != NULL)
    {
      if (f->d_name[0] == '.') continue;
      STRING_WRITE(path, "%s%c%s", dest, '/', f->d_name)
      if (stat(f->d_name, &buf) == -1)
        {
          perror("[ERR] stat ");
          exit(EXIT_FAILURE);
        }

      /*  Note: on my implementation of Linux (Ubuntu), S_ISDIR and S_ISREG(buf.st_mode) are seemingly buggy
       *  Resorting to masks S_ISDIR and S_IFREG as a way out */

      if (S_IFDIR & buf.st_mode)
        {

          if (globals_c.debugging) foutput_c("%s %s %s %s\n", "[INF]  Copying dir=", f->d_name, " to=", path);

          errno=copy_directory(f->d_name, path, mode);
          continue;
        }
      if (S_IFREG & buf.st_mode)
        {
          if (globals_c.debugging) foutput_c("%s%s to= %s\n", "[INF]  Copying file=", f->d_name, path);
          errno=copy_file(f->d_name, path);
        }
      /* does not copy other types of files(symlink, sockets etc). */

      else continue;
    }
  change_directory("../");
  if (globals_c.debugging)   foutput_c("%s", "[INF]  Done. Backtracking... \n\n");
  closedir(dir_src);
  return(errno);
}

// Adapted from Yve Mettier's O'Reilly "C en action" book, chapter 10.

int copy_file(const char *existing_file, const char *new_file)
{

  FILE *fn, *fe;
  int errorlevel;

  if (NULL == (fe = fopen(existing_file, "rb")))
    {
      fprintf(stderr, "[ERR]  Impossible to open file '%s' \n in read mode ", existing_file);
      return(-1);
    }
  if (NULL == (fn = fopen(new_file, "wb")))
    {
      fprintf(stderr, "[ERR]  Impossible to open file '%s' in write mode\n", new_file);
      fclose(fe);
      return(-1);
    }


  errorlevel=copy_file_p(fe, fn);
  fclose(fe);
  fclose(fn);

  return(errorlevel);

}

int copy_file_p(FILE *infile, FILE *outfile)
{


  char buf[BUFSIZ];
  clearerr(infile);
  clearerr(outfile);
  size_t chunk;

  while (!feof(infile))
    {


      chunk=fread(buf, sizeof(char), BUFSIZ, infile);

      if (ferror(infile))
        {
          fprintf(stderr, "Read error\n");
          return(-1);
        }

      fwrite(buf, chunk* sizeof(char), 1 , outfile);

      if (ferror(outfile))
        {
          fprintf(stderr, "Write error\n");
          return(-1);
        }
    }
  return(0);
}



int get_endianness()
{
  long i=1;
  const char *p=(const char *) &i;
  if (p[0] == 1) return LITTLE_ENDIAN;
  return BIG_ENDIAN;
}


