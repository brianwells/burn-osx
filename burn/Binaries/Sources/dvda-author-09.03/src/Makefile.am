SUBDIRS=include

## src/ output executable will be 'dvda'

bin_PROGRAMS=dvda


## canonical names cannot contain hyphens, so using program_transform_name
## remark: AC_ARG_PROGRAM was tested useless here

program_transform_name='s/dvda/dvda-author/g'


AM_CPPFLAGS=-I${top_srcdir}/libutils/include -I${top_srcdir}/src/include -I${top_srcdir}/fixwav/src/include  -I${top_srcdir}/glibc -I${top_srcdir}/libats2wav -I${top_srcdir}/libsoxconvert/libsox   -I${top_srcdir}   ${DEBUG_FLAGS}

## libc_utils is always rebuilt, libFLAC and libfixwav are shipped with package for i386*-*[cygwin linux] distributions

AM_LDFLAGS=-s -lm ${LIBIBERTY}  -L/usr/local/lib ${FLAC_LINK} ${OGG_LINK} ${SOX_LINK} ${ALSA_LIBS}

#enabling $(LIBOBJS) outside /glibc
AUTOMAKE_OPTIONS = subdir-objects

LDADD=${top_builddir}/libutils/libc_utils.a  \
  ${top_builddir}/libats2wav/libats2wav.a \
 ${FIXWAV_LIB}  ${FLAC_LIB} ${OGG_LIB}  ${SOX_LIB} ${GLIBC} $(LIBOBJS) 

dvda_SOURCES=amg2.c ats.c atsi2.c audio.c auxiliary.c dvda-author2.c  \
             file_input_parsing.c samg2.c videoimport.c launch_manager.c command_line_parsing.c endianness.c \
             lexer.c
