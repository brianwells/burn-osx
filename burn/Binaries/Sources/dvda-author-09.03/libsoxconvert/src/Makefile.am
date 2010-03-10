SOX=${top_srcdir}/libsox
SOXBUILD=${top_builddir}/libsox

lib_LIBRARIES= libsoxconvert.a
libsoxconvert_a_CPPFLAGS=-I${SOX} -I${rootdir}/libutils/include -I${rootdir}/src/include -I${top_srcdir}/libgsm -I${top_srcdir}/libpc10 -I${rootdir}

libsoxconvert_a_LDFLAGS=-s
libsoxconvert_a_SOURCES=libsoxconvert.c ${SOX}/util.c ${SOX}/effects.c
libsoxconvert_a_LIBADD=${SOXBUILD}/libsox.a ${top_builddir}/libgsm/libgsm.a ${top_builddir}/lpc10/liblpc10.a ${SOXBUILD}/libsfx.a ${rootdir}/libutils/libc_utils.a



