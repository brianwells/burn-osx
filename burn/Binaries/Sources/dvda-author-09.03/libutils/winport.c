/*

File:   winport.c
Purpose: windows port function

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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif


#include <sys/types.h>
#include <stdio.h>
#include <sys/stat.h>
#include <stdint.h>
#include "winport.h"
#include "private_c_utils.h"
#include "c_utils.h"

extern global_utils globals_c;



#ifndef __WIN32__
#include <unistd.h>

uint64_t read_file_size(FILE * fp, const char* filename)
{
    uint64_t size = 0;

    if (fp)
    {
        /* get size */
        struct stat buf;
        if (stat(filename, &buf) != 0) return(0);
        size=(uint64_t) buf.st_size;
        
    }
    return size;
}

int truncate_from_end(char* filename, off_t offset)
{
    return truncate(filename, offset);
}

#else

#include <windows.h>
#include <winbase.h>

#include <tchar.h>


uint64_t read_file_size(FILE* fp, TCHAR* filename)
{

     if (fclose(fp) == EOF)
     {
         foutput_c("[ERR]  Could not close file %s", filename);
         exit(EXIT_FAILURE);
     }

     HANDLE hFile;

     hFile = CreateFile(filename,                // name of the write
                       GENERIC_WRITE,          // open for writing
                       0,                      // do not share
                       NULL,                   // default security
                       OPEN_EXISTING,         // existing file only
                       FILE_ATTRIBUTE_NORMAL,  // normal file
                       NULL);                  // no attr. template
    if (hFile == INVALID_HANDLE_VALUE)
    {
        foutput_c("[WAR]  Could not open file (error %d)\n", (int) GetLastError());
        CloseHandle(hFile);
        exit(EXIT_FAILURE);
    }

    BOOL result=0;

    LARGE_INTEGER move, distance;
    PLARGE_INTEGER Distance=&distance;  // signed 64-bit type (*int64_t)

    move.QuadPart=0;
    result=SetFilePointerEx(hFile, move, Distance, FILE_END );

    CloseHandle(hFile);
    if (!result)
    {
        foutput_c("%s%s\n", "[ERR]  Could not get size of %s ", (char *) filename);
        exit(EXIT_FAILURE);
    }

    if ((fp=fopen((char *) filename, "rb")) == NULL)
    {
        foutput_c("%s%s\n", "[ERR]  Could not open ", (char *) filename);
        exit(EXIT_FAILURE);
    }

    return ((uint64_t) distance.QuadPart  );
}

int truncate_from_end(TCHAR*filename, off_t cut){


     HANDLE hFile;
     BOOL result=0;
     hFile = CreateFile(filename,                // name of the write
                       GENERIC_WRITE,          // open for writing
                       0,                      // do not share
                       NULL,                   // default security
                       OPEN_EXISTING,         // existing file only
                       FILE_ATTRIBUTE_NORMAL,  // normal file
                       NULL);                  // no attr. template

    if (hFile == INVALID_HANDLE_VALUE)
    {
        fprintf(stderr, "[WAR]  Could not open file (error %d)\n", (int) GetLastError());
        CloseHandle(hFile);
        return -1;
    }

    if (SetFilePointer(hFile, cut, NULL, FILE_END) > 0)
         result=SetEndOfFile(hFile);

    if (result == FALSE)
     {
        fprintf(stderr, "[WAR]  Could not open set of file (error %d)\n", (int) GetLastError());
        CloseHandle(hFile);
        return -1;
    }
    CloseHandle(hFile);
    return 1;
}


#endif



