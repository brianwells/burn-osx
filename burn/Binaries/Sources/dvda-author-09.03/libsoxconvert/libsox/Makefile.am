## Process this file with automake to produce Makefile.in

AM_CPPFLAGS = -DLADSPA_PATH="\"@LADSPA_PATH@\"" -DPKGLIBDIR="\"$(pkglibdir)\"" 


lib_LIBRARIES = libsox.a libsfx.a
noinst_HEADERS = sox.h soxstdint.h sox_i.h fft4g.h effects.h

#############################################
# libsox Dynamic Libraries for File Formats #
#############################################


# Format modules; listed first so optional ones can be added later

############################
# libsfx - effects library #
############################

libsfx_a_SOURCES = input.c  output.c effects_i.c fft4g.c  
if HAVE_PNG
    libsfx_a_SOURCES += spectrogram.c
endif

libsfx_a_CFLAGS = @SAMPLERATE_CFLAGS@
libsfx_a_LIBADD = libsox.a 
linsfx_a_LDFLAGS= @PNG_LIBS@ @SAMPLERATE_LIBS@ -s

############################################
# libsox - file format and utility library #
############################################

libsox_a_SOURCES = adpcms.c adpcms.h aiff.c aiff.h cvsd.c cvsd.h cvsdfilt.h \
	  g711.c g711.h g721.c g723_24.c g723_40.c g72x.c g72x.h vox.c vox.h \
	  raw.c raw.h formats.c formats.h formats_i.c sox_i.h skelform.c \
	  xmalloc.c xmalloc.h getopt.c getopt1.c getopt.h \
	  soxconfig.h util.c util.h libsox.c libsox_i.c
libsox_a_CFLAGS = 

libsox_a_SOURCES += raw-fmt.c s1-fmt.c s2-fmt.c s3-fmt.c \
    s4-fmt.c u1-fmt.c u2-fmt.c u3-fmt.c u4-fmt.c al-fmt.c la-fmt.c ul-fmt.c \
    lu-fmt.c 8svx.c aiff-fmt.c aifc-fmt.c au.c avr.c cdr.c cvsd-fmt.c \
    dvms-fmt.c dat.c gsm.c hcom.c htk.c lpc10.c maud.c prc.c sf.c smp.c \
    sounder.c soundtool.c sphere.c tx16w.c voc.c vox-fmt.c ima-fmt.c adpcm.c adpcm.h \
    ima_rw.c ima_rw.h wav.c wve.c xa.c nulfile.c f4-fmt.c f8-fmt.c
libsox_a_LDFLAGS = @GSM_LIBS@ @LIBGSM_LIBADD@ -s


if HAVE_FFMPEG
    libsox_a_SOURCES += ffmpeg.c
    libsox_a_LDFLAGS += @FFMPEG_LIBS@
    
endif
if HAVE_SNDFILE
    libsox_a_SOURCES += sndfile.c caf.c mat4.c mat5.c paf.c fap.c w64.c xi.c pvf.c sd2.c
    libsox_a_CFLAGS += @SNDFILE_CFLAGS@
    libsox_a_LDFLAGS += @SNDFILE_LIBS@
    
endif
if HAVE_AMRWB
    libsox_a_SOURCES += amr-wb.c amr.h amr1.h amr2.h
    libsox_a_LDFLAGS += @AMR_WB_LIBS@
    
endif
if HAVE_AMRNB
    libsox_a_SOURCES += amr-nb.c amr.h amr1.h amr2.h
    libsox_a_LDFLAGS += @AMR_NB_LIBS@
    
endif
if HAVE_WAVPACK
    libsox_a_SOURCES += wavpack.c
    libsox_a_LDFLAGS += @WAVPACK_LIBS@
    
endif
if HAVE_ALSA
    libsox_a_SOURCES += alsa.c
    libsox_a_LDFLAGS += @ALSA_LIBS@
    
endif
if HAVE_LIBAO
    libsox_a_SOURCES += ao.c
    libsox_a_LDFLAGS += @AO_LIBS@
    
endif
if HAVE_OSS
    libsox_a_SOURCES += oss.c
    libsox_a_LDFLAGS += @OSS_LIBS@
    
endif
if HAVE_SUN_AUDIO
    libsox_a_SOURCES += sunaudio.c
endif




