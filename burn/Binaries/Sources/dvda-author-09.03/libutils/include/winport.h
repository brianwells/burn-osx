#ifndef WINPORT_H_INCLUDED
#define WINPORT_H_INCLUDED


#include <sys/types.h>
#include <stdint.h>
#include <stdio.h>
#ifdef __WIN32__
#include <tchar.h>
#include <windows.h>


int truncate_from_end(TCHAR*filename, off_t offset);
uint64_t read_file_size(FILE* fp, TCHAR* filename);

#else

uint64_t read_file_size(FILE * fp, const char* filename);
int truncate_from_end(char* filename, off_t offset);
#endif
#endif // WINPORT_H_INCLUDED
