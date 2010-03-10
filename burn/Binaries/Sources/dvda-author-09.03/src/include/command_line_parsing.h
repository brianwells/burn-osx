#ifndef COMMAND_LINE_PARSING_H
#define COMMAND_LINE_PARSING_H

#include "structures.h"
#include "commonvars.h"
 

command_t *command_line_parsing(int , char* const argv[], fileinfo_t **files, command_t *command);

#ifndef WITHOUT_FIXWAV
#include "fixwav_manager.h"
void fixwav_parsing(char *ssopt);
#endif


void ats2wav_parsing(const char * arg, int* ntracks, int access_rights);

#endif
