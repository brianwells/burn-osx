#ifndef PRIVATE_C_UTILS_H_INCLUDED
#define PRIVATE_C_UTILS_H_INCLUDED


typedef struct
  {
    _Bool silence;
    _Bool logfile;
    _Bool debugging;
    FILE *journal;

  } global_utils ;


/* MACROS*/

#define foutput_c(X, ...)   do { if (!globals_c.silence) printf(X, __VA_ARGS__);\
							   if (!globals_c.logfile) break;\
							   fprintf(globals_c.journal, X, __VA_ARGS__);} while(0)

#ifdef __WIN32__
#define	MKDIR(X, Y) mkdir(X)
#else
#define MKDIR(X, Y) mkdir(X, Y)
#endif




#endif // PRIVATE_C_UTILS_H_INCLUDED
