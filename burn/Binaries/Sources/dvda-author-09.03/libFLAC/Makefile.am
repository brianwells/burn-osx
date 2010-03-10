DISTCHECK_CONFIGURE_FLAGS=--enable-ogg-build
ACLOCAL_AMFLAGS=-I m4

SUBDIRS=${MAYBE_OGG} private protected share FLAC 
DIST_SUBDIRS=include private protected share FLAC config 

## This is unfortunate but configure.ac is not automatically included in nested packages
## so adding it as extra is necessary.
EXTRA_DIST=configure.ac 
noinst_LIBRARIES=libFLAC121.a

AM_CPPFLAGS=-Iprivate -Iprotected -Ishare -IFLAC -I${top_srcdir}/include/libogg/include
AM_LDFLAGS=-s

libFLAC121_a_LIBADD=${OGG_LIB}

libFLAC121_a_SOURCES=bitmath.c bitreader.c bitwriter.c cpu.c crc.c fixed.c float.c format.c lpc.c md5.c memory.c  ogg_decoder_aspect.c ogg_encoder_aspect.c ogg_helper.c ogg_mapping.c stream_decoder.c stream_encoder.c stream_encoder_framing.c window.c 
