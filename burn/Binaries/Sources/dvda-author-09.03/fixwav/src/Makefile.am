SUBDIRS=include
noinst_LIBRARIES=libfixwav13.a
bin_PROGRAMS=fixwav

libfixwav13_a_SOURCES=auxiliary.c  checkData.c  checkParameters.c   readHeader.c  repair.c  manager.c launch_fixwav.c 
libfixwav13_a_CPPFLAGS=-Wall  -std=c99 -O3 -I${top_srcdir}/fixwav/src/include -I${top_srcdir}/libutils/include
libfixwav13_a_LDFLAGS=-s  -lm
libfixwav13_a_LIBADD=${top_builddir}/libutils/libc_utils.a 

fixwav_CPPFLAGS=-Wall -std=c99 -O3 -I${top_srcdir}/fixwav/src/include  -I${top_srcdir}/libutils/include
fixwav_LDFLAGS=-s   -lm 
fixwav_LDADD=libfixwav13.a  ${top_builddir}/libutils/libc_utils.a 
fixwav_SOURCES=main.c


