/*
File:    commonvars.h
Purpose: defines and macros

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

#ifndef COMMONVARS_H_INCLUDED
#define COMMONVARS_H_INCLUDED

#if HAVE_CONFIG_H && !defined __CB__
#include <config.h>
#else 
#define VERSION "09.03"
#endif



/* This sanity check macros forces LONG_OPTIONS when _GNU_SOURCE has been defined as a compile-time option
 * unless SHORT_OPTIONS_ONLY has been defined to block long options irrespective of the source version 
 * _GNU_SOURCE si independently requested by strndup  
 * GNU Autoconf scripts define _LONG_OPTIONS among others in config.h thanks to
 * macro AC_USE_SYSTEM_EXTENSIONS in the top configure.ac */


#ifndef _GNU_SOURCE
#error "[ERR]  This version uses GNU extensions to C: try to compile again with #define _GNU_SOURCE"
#else
#if !defined(LONG_OPTIONS) && !defined(SHORT_OPTIONS_ONLY)
#define LONG_OPTIONS
#endif
#endif


#define PROGRAM "DVD-A author"

/* filesystem constants expressed in sectors */

#define STARTSECTOR  281
#define SIZE_AMG  3
#define SIZE_SAMG 64

/* allowed options for lexer.h */

#define MAX_OPTION_LENGTH 200
#define N_OPTIONS 16

/* default backup directories */

#define DEFAULT  "./Audio"
#define DEFAULT_AOB_FOLDER   "./AOB"
#define DEFAULT_SYSTEM_FOLDER  "./SYSTEM"

/*  A DVD-compliant disc can have up to 99 video title sets.  */

#define MAXIMUM_LINKED_VTS  9
#define PLAYBACK_TIME_OFFSET 0x1014
/* For IDE builds, define SETTINGSFILE in IDE as the install path to dvda-author.conf */
#ifndef SETTINGSFILE
/* either define SETTINGSFILE at compile time or let configure find the right install dir */
#ifndef INSTALL_CONF_DIR
#define INSTALL_CONF_DIR "."
#endif
#define SETTINGSFILE   INSTALL_CONF_DIR "/dvda-author.conf"
#endif
#define LOGFILE  "../log.txt"
#define INDIR  "../audio"
#define OUTDIR  "../output"
#define LINKDIR "../VIDEO_TS"
#define STANDARD_FIXWAV_SUFFIX "_fix_"


#define INFO_EXECTIME1  "[MSG]  User execution time: %u minutes %u seconds\n"
#define INFO_EXECTIME2  "[MSG]  System execution time: %u minutes %u seconds\n"

#ifndef LOCALE
#define LOCALE "C"
#endif

#define READTRACKS 1

#define INFO_GNU   "Copyrigh Dave Chapman 2005-Fabrice Nicol 2007,2008   <fabnicol@users.sourceforge.net>-Lee and Tim Feldkamp 2008\n\
This file is part of dvda-author.\n\
dvda-author is free software: you can redistribute it and/or modify \
it under the terms of the GNU General Public License as published by \
the Free Software Foundation, either version 3 of the License, or \
(at your option) any later version.\n\
dvda-author is distributed in the hope that it will be useful,\
but WITHOUT ANY WARRANTY; without even the implied warranty of \
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the \
GNU General Public License for more details.\n\
You should have received a copy of the GNU General Public License \
along with dvda-author.  If not, see <http://www.gnu.org/licenses/>.\n\n"

#define SINGLE_DOTS   foutput("\n\n%s\n\n",         "-----------------------------------------------------------------");
#define DOUBLE_DOTS  foutput("\n%s\n",              "==================================================================");
#define J "\n                         "  //left-aligns definition strings


#endif
