/*
File:    dvda-author.h
Purpose: initializing macros/structures

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

#ifndef  DVDA_AUTHOR
#define  DVDA_AUTHOR

// Always end the lists of options with an option that has :: (to ensure space for spec_index(2)[2]) */
#include "commonvars.h"

#define ALLOWED_OPTIONS  "0ghi:l:T:no:p:P::qV:U:w:d-:x:S::f::F::"

#ifdef LONG_OPTIONS

// Use same conventions as for short options wrt : and ::
#define ALLOWED_LONG_OPTIONS  "no-padding" "debug" "help" "input:" "log:" "no-videozone" "output:"\
                              "startsector:" "pause" "quiet" "videolink:" "PTS-factor:" \
                               "version" "videodir:" "rights:" "extract:" "sox::" "fixwav-virtual::" "fixwav::" 
#endif


#endif // DVDA-AUTHOR_H_INCLUDED
