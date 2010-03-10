#include    <stdio.h>
#include    <inttypes.h>
#include    "commonvars.h"
#include    "c_utils.h"
#include "structures.h"



void fread_endian(uint32_t * p, int t, FILE *f)
{

    /*  CPU_IS_LITTLE_ENDIAN or CPU_IS_BIG_ENDIAN are defined by  configure script */

#if !defined    CPU_IS_LITTLE_ENDIAN    &&  !defined    CPU_IS_BIG_ENDIAN

    /* it is necessary to test endianness here */
    static char u;
    static _Bool little;

    /* testing just on first entry */

    if  (!u)   little=(get_endianness() == LITTLE_ENDIAN) ;

    /* fread fills in MSB first so shift one byte for each  one-byte scan  */

    if (little)
    {
        fread(p+t, 4 ,1,  f) ;
        p[t]= (p[t] << 8  &  0xFF0000)  |   (p[t]<<16 & 0xFF00)  |   (p[t]<<24 & 0xFF) |  (p[t] & 0xFF000000);
    }
    else
        /*Big endian  case*/
        fread(p+t, 1 ,4,  f) ;
    fflush(f);

#elif   defined CPU_IS_BIG_ENDIAN
    fread(p+t, 1 ,4,  f) ;

#elif   defined CPU_IS_LITTLE_ENDIAN
    fread(p+t, 4 ,1,  f) ;
    p[t]= (p[t] << 8  &  0xFF0000)  |   (p[t]<<16 & 0xFF00)  |   (p[t]<<24 & 0xFF) |  (p[t] & 0xFF000000);
#endif

    return;

}
