#ifndef STRNLEN_H
#define STRNLEN_H

/* Get strnlen declaration, if available.  */
#ifdef strnlen
#undef strnlen
#endif
#include <stdlib.h>

size_t strnlen(const char *string, size_t maxlen);


#endif /* STRNLEN_H */
