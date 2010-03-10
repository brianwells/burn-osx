#ifndef LAUNCH_FIXWAV_H_INCLUDED
#define LAUNCH_FIXWAV_H_INCLUDED
#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

void create_output_filename(char* filename, char** buffer);
int launch_fixwav_library(char* filename);
int wav_getinfo(char* filename);

#ifdef SINGLE_DOTS
#undef SINGLE_DOTS
#endif

// Undefining VERSION config.h if lying around and working with IDE
#if defined VERSION && defined __CB__
#undef VERSION
#endif
#ifndef VERSION
#define VERSION  "0.2"
#endif

#define FIXWAV_HEADER    foutput("\n\n%s%s%s\n\n", "__________________________  FIXWAV ",VERSION," __________________________");


#define SINGLE_DOTS   foutput("\n\n%s\n\n",         "-----------------------------------------------------------------");

#endif // LAUNCH_FIXWAV_H_INCLUDED
