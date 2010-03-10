/*
File:    ports.h
Purpose: ports to Windows Mingw compiler

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

#ifndef PORTS_INCLUDED
#define PORTS_INCLUDED

#if HAVE_CONFIG_H
#include <config.h>
#endif

/* The debian Mingwin compiler ignores access rights */

#ifdef __MINGW32__

#include <io.h>
#define COMPUTE_EXECTIME

#else

#include <sys/resource.h>

/* a compute_t *timer pointer must be included equally */

#define COMPUTE_EXECTIME    do{ \
	struct rusage end;\
	getrusage(RUSAGE_SELF, &end);\
	unsigned int SEC1=end.ru_utime.tv_sec - timer.start->ru_utime.tv_sec - timer.nothing->ru_utime.tv_sec, SEC2=end.ru_stime.tv_sec- timer.start->ru_stime.tv_sec - timer.nothing->ru_stime.tv_sec;\
				foutput(INFO_EXECTIME1, SEC1/60, SEC1%60 );\
				foutput(INFO_EXECTIME2, SEC2/60, SEC2%60 );\
				} while(0);



#endif

#if ! HAVE_STRNDUP || defined __CB__ ||  GLIBC_REPLACEMENT
#include "glibc/strndup.h"
#endif
#if ! HAVE_GETSUBOPT || defined __CB__ || GLIBC_REPLACEMENT
#include "glibc/getsubopt.h"
#endif
// Replace strdup even if present (notably on FreeBSD)
#if defined __CB__ || GLIBC_REPLACEMENT
#include "glibc/strdup.h"
#endif





#endif // PORTS_INCLUDED
