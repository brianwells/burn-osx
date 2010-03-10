#ifndef FIXWAV_AUXILIARY_INCLUDED
#define FIXWAV_AUXILIARY_INCLUDED

#include "fixwav_manager.h"
#define foutput_f(X, ...)   do { if (!globals_f.silence) printf(X, __VA_ARGS__);\
							   if (!globals_f.logfile) break;\
							   fprintf(globals_f.journal, X, __VA_ARGS__);} while(0)

void initialise_globals_fixwav(_Bool silence, _Bool logfile, FILE* journal);
_Bool isok();
void get_input( char* buf );
void hexdump_header(FILE* infile);
FILE* secure_open(char *path, char *context);
int end_seek(FILE* outfile);



#endif // FIXWAV_AUXILIARY_INCLUDED
