/*
 * Simple config lexer
 *
 * Copyright (c) 2008 fabnicol@users.sourceforge.net
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, write to the Free Software Foundation, Fifth
 * Floor, 51 Franklin Street, Boston, MA 02111-1301, USA.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include "structures.h"
#include "lexer.h"
#include "dvda-author.h"
#include "auxiliary.h"
#include "c_utils.h"

extern globalData globals;



lexer_t *config_lexer(const char* path, lexer_t *lexer)
{

    int i=0,j=1, scan=0;

    char T[2][MAX_OPTION_LENGTH]={{0}};
    // leaving MAX_OPTION_LENGTH as maximal white space between switch and option
    char  init[3*MAX_OPTION_LENGTH]={0};
    char  *chain=init, *spec_index=NULL;
#ifdef LONG_OPTIONS
    char *spec_index2=NULL;
    int scan2=0;
#endif


    FILE* defaults=fopen(path, "rb");

    if (defaults == NULL)
    {
        if (globals.debugging) foutput("[ERR]  fopen(%s, \"rb\") crashed\n", path);
        EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  Could not open default file dvda-author.conf")

    }

    do
    {

        if (feof(defaults)) break;

        if (NULL==fgets(chain, 2*MAX_OPTION_LENGTH+2, defaults))
            EXIT_ON_RUNTIME_ERROR_VERBOSE("[ERR]  dvd-audio.conf empty or could not be read")


            /* skipping white space : space or tab */

            while (isblank(chain[0]) && (chain[0] != '\n')) chain++;

        /* skipping empty lines and comments */

        if ((chain[0] == '\n') || (chain[0] == '#')) continue;

        sscanf(chain, "%s", T[0]);

        spec_index=strstr(ALLOWED_OPTIONS, T[0]);

#ifdef LONG_OPTIONS
        if (spec_index == NULL)
            spec_index2=strstr(ALLOWED_LONG_OPTIONS, T[0]);
#endif

        if (spec_index != NULL)
        {
            {
                lexer->commandline[j][0]='-';
                memmove(lexer->commandline[j]+1, T[0], strlen(T[0]) +1);
            }
        }
#ifdef LONG_OPTIONS
        else   if (spec_index2 != NULL)

        {
            lexer->commandline[j][0]=lexer->commandline[j][1]='-';
            memmove(lexer->commandline[j]+2, T[0], strlen(T[0]) +1);
        }
#endif


        errno=0;

        if (
            ((spec_index != NULL) && (spec_index[1] == ':') && (spec_index[2] != ':') && ((scan=sscanf(chain + strlen(T[0]) , "%s", T[1])) != EOF))

#ifdef LONG_OPTIONS
            ||  ((spec_index2 != NULL) && (spec_index2[strlen(T[0])] == ':') && ((scan2=sscanf(chain + strlen(T[0]) , "%s", T[1])) != EOF))
#endif
        )
        {
            j++;
            memmove(lexer->commandline[j], T[1], strlen(T[1])+1);
        }
        else
        {

            if  ((spec_index == NULL)
#ifdef LONG_OPTIONS
                    && (spec_index2 == NULL)
#endif
                )

                foutput("[ERR]  Did not find option:%s\n", T[0]);

            else

                if  (((spec_index != NULL) && (spec_index[1] == ':') && (spec_index[2] != ':') && (scan == EOF) && (!errno))
#ifdef LONG_OPTIONS
                        ||((spec_index2 != NULL) && (spec_index2[strlen(T[0])] == ':') && (spec_index2[2] != ':') && (scan2 == EOF) && (!errno) )
#endif
                    )

                    foutput("[ERR]  Option %s must be followed by argument in configuration file.\n", T[0]);
        }

        i++, j++;

    }
    while (i < N_OPTIONS);

    clearerr(defaults);

    fclose(defaults);

    lexer->nlines=j+1;

    return lexer;
}


