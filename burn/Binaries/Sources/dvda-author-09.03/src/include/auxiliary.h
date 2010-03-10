/*
File:    auxiliary.h
Purpose: auxiliary functions and macros

dvda-author  - Author a DVD-Audio DVD

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
#ifndef  AUXILIARY_H_INCLUDED
#define AUXILIARY_H_INCLUDED
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <errno.h>

#include "audio2.h"
#include "c_utils.h"
#include "commonvars.h"
#include "structures.h"

/* All macros are below except for OS-specific macros in ports.h*/

// Binary-coded digital numbers are hex numbers that should be read as their decimal values

#define BCD(X)   ((X)/16*10 + (X)%16)

#define EXIT_ON_RUNTIME_ERROR_VERBOSE(X)  EXIT_ON_ERROR_VERBOSE(X, DEFAULT)
#define EXIT_ON_RUNTIME_ERROR  EXIT_ON_ERROR(DEFAULT)


#define HEADER(X, Y)      do{ \
						  DOUBLE_DOTS \
                          foutput("\n%s\n",     "    -----------------   "X" "Y"   -----------------");\
                          print_time(1);\
                          DOUBLE_DOTS \
                          foutput("\n%s\n\n", INFO_GNU);}while(0);


#define FREE(X)  if (X != NULL) free(X);

/* end of macros */

void help();
void version();
char* print_time();
_Bool increment_ngroups_check_ceiling(int *ngroups, void *nvideolinking_groups );
fileinfo_t** dynamic_memory_allocate(fileinfo_t **  files, int* ntracks,  int  ngroups, int n_g_groups, int nvideolinking_groups);
void free_memory(command_t *command);

#endif // AUXILIARY_H_INCLUDED
