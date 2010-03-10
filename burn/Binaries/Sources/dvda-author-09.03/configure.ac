#                     -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.
#
# dvda-author executable script
#
# All autoconf and automake scripts Copyright Fabrice Nicol 2008 <fabnicol@users.sourceforge.net>
#
######################################################################################################


######################
# standard init macros
######################


AC_PREREQ(2.63)
AC_INIT([dvda-author],[09.03],[fabnicol@users.sourceforge.net])
AC_LANG([C])

# requested to define _GNU_SOURCE and check the availability of GNU extensions
# This should be called before any macros that run the C   compiler.

AC_USE_SYSTEM_EXTENSIONS


# Path to auxiliary configuration files
# AC_CONFIG must be called before AM_INIT_AUTOMAKE

AC_CONFIG_AUX_DIR([config])

AC_CONFIG_MACRO_DIR([m4])

# make dist produces both tar.bz2 and tar.gz packages

AM_INIT_AUTOMAKE([dist-bzip2 -Wall])

AC_CONFIG_SRCDIR([src/videoimport.c])
AC_CONFIG_HEADER([config.h])

AC_PREFIX_DEFAULT([/usr])

AC_CANONICAL_BUILD

AC_MSG_NOTICE([Build OS is...${build_os}])


LT_INIT([static])
LT_PREREQ([2.2.6])

###########################################
# enables optional configuring of FLAC libs
###########################################

#default configuration uses installed libFLAC and libogg libraries and enables Ogg FLAC
#same with SoX converter

FLAC_CONFIGURE=no
OGG_FLAC_SUPPORTED=yes
SOX_CONFIGURE=no
FLAC_LIB=
FLAC_LINK=
OGG_LIB=
OGG_LINK=
SOX_LINK=
SOX_LIB=
FIXWAV_LIB='${top_builddir}/fixwav/src/libfixwav13.a'
GLIBC=
MAYBE_FIXWAV=fixwav


AC_ARG_WITH(ogg, [AS_HELP_STRING([--with-ogg],[path to Ogg library])],
   [if test x$withval != xyes; then
    OGG_LIB=$withval
    fi
   ]
, [])

# This function tests for installed SoX libraries and triggers building of source files if not available

testsox() {
 
    # default behaviour: SoX libs configured with default path
    if test "x$SOX_LIB" = "x" ; then
     LDFLAGS="$LDFLAGS -L/usr/lib -L/usr/local/lib -L/usr/lib/sox -L/usr/local/lib/sox"
     SOX_LIB="sox"
    else
     LDADD="$SOX_LIB"
     SOX_LIB=`echo $SOX_LIB | sed "s/.*lib\(.*\)\(\.\).*/\1/"`
     AC_MSG_RESULT([Looking for $SOX_LIB...])
    fi
   
    AC_SEARCH_LIBS(sox_precision,$SOX_LIB, 
    [
     SOX_LINK="-lsox"
     SOX_LIB='${top_builddir}/libsoxconvert/src/libsoxconvert.a'
     AC_MSG_NOTICE([Using installed libsox library...])
    ],
    [
     # force build of dependencies

     AC_MSG_NOTICE([

Building SoX library from sources (not installed)...
Triggering --enable-sox-build...

     ])
     SOX_LIB='${top_builddir}/libsoxconvert/src/libsoxconvert.a ${top_builddir}/libsoxconvert/libsox/libsox.a ${top_builddir}/libsoxconvert/libgsm/libgsm.a ${top_builddir}/libsoxconvert/lpc10/liblpc10.a ${top_builddir}/libsoxconvert/libsox/libsfx.a' 
     SOX_CONFIGURE=yes
    ],
    [ -lgsm -llpc10 -lsfx -lm ])

}

testflac() {

if test "x$FLAC_LIB" = "x" ; then
 LDFLAGS="$LDFLAGS -L/usr/lib -L/usr/local/lib"
 FLAC_LIB="FLAC flac"
 OGG_LIB="ogg $OGG_LIB"
else
 LDADD="$FLAC_LIB $OGG_LIB"
 FLAC_LIB=`echo $FLAC_LIB | sed "s/.*lib\(.*\)\(\.\).*/\1/"`
 OGG_LIB=`echo $OGG_LIB  | sed "s/.*lib\(.*\)\(\.\).*/\1/"`
 AC_MSG_RESULT([Looking for $FLAC_LIB...])
fi

AC_SEARCH_LIBS(FLAC__stream_decoder_init_file, $FLAC_LIB $OGG_LIB, 

 [
   FLAC_LINK="-lFLAC"
   FLAC_LIB=
   AC_MSG_NOTICE([Using installed libFLAC library...])
 ],
 [
   # force build of dependencies

   AC_MSG_NOTICE([

Building FLAC library from sources (not installed)...
Triggering --enable-flac-build...

])

   FLAC_LIB='${top_builddir}/libFLAC/libFLAC121.a'
   FLAC_CONFIGURE=yes
 ])
}

AC_ARG_WITH(flac, [AS_HELP_STRING([--with-flac],[=path to FLAC library or --without-flac])],
   [if test x$withval != xyes; then
    FLAC_LIB=$withval
    fi
    if test x$withval = xno; then
    AC_DEFINE([WITHOUT_FLAC],[1],[Disables FLAC/Ogg support])
    FLAC_LIB=    
    fi
   ],
   [
   testflac
   ]  
)


if test "x$OGG_LIB" = "x" ; then
 LDFLAGS="$LDFLAGS -L/usr/lib -L/usr/local/lib"
 OGG_LIB=ogg
else
 LDADD="$LDADD $OGG_LIB"
 OGG_LIB=`echo $OGG_LIB | sed "s/.*lib\(.*\)\(\.\).*/\1/"`
 AC_MSG_RESULT([Looking for $OGG_LIB...])
fi

# This must come after the flac tests

AC_SEARCH_LIBS(ogg_stream_init , $OGG_LIB,
 [  
  if test x$FLAC_CONFIGURE = xno ; then
   OGG_LIB=
   OGG_LINK="-logg"
   AC_MSG_NOTICE([Using installed libogg library...])
  else
   # force build of dependencies

   AC_MSG_NOTICE([

Building ogg library from sources to satisfy libFLAC dependencies...
Triggering --enable-ogg-build...

   ])
   FLAC_CONFIGURE=yes
   OGG_LIB='${top_builddir}/libFLAC/include/libogg/src/libogg.a'
  fi
 ],
 [
   # force build of dependencies

   AC_MSG_NOTICE([

Building ogg library from sources (not installed)...
Triggering --enable-ogg-build...

   ])
   FLAC_CONFIGURE=yes
   OGG_LIB='${top_builddir}/libFLAC/include/libogg/src/libogg.a'
 ])


AC_ARG_WITH(sox, [AS_HELP_STRING([--without-sox],[build without SoX])],
   [
    if test x$withval = xno; then
     AC_DEFINE([WITHOUT_SOX],[1],[Disables SoX support])
     SOX_LIB=
    fi
    
   ],
   [
    testsox
   ])


AC_ARG_WITH(fixwav, [AS_HELP_STRING([--without-fixwav],[build without fixwav])],

   [
    if test x$withval != xyes; then
    FIXWAV_LIB=$withval
    fi
    if test x$withval = xno; then
    AC_DEFINE([WITHOUT_FIXWAV],[1],[Disables fixwav support])
    FIXWAV_LIB= 
    MAYBE_FIXWAV=
    fi
   ])



## Forces compiling of GNU glibc source code into an static library in glibc/
## Fallback option in case AC_LIBOBJ would not work.

glibc_replacement=no

AC_ARG_ENABLE(glibc,
    [AS_HELP_STRING([--enable-glibc],[Compiling glibc source files ])],
    [
     AC_DEFINE(GLIBC_REPLACEMENT, [1], [Compiling GNU libc sources])
     glibc_replacement=yes
     GLIBC='${top_builddir}/glibc/libglibc.a'
    ])


# forcing build of dependencies

AC_ARG_ENABLE(flac-build,
    [AS_HELP_STRING([--enable-flac-build],[Compiling flac library ])],
    [
      FLAC_LIB='${top_builddir}/libFLAC/libFLAC121.a'
      FLAC_CONFIGURE=yes
      FLAC_LINK=
    ])

AC_ARG_ENABLE(ogg-build,
    [AS_HELP_STRING([--enable-ogg-build],[Compiling ogg library ])],
    [
      OGG_LINK=
      OGG_LIB='${top_builddir}/libFLAC/include/libogg/src/libogg.a'
    ])

AC_ARG_ENABLE(sox-build,
    [AS_HELP_STRING([--enable-sox-build],[Compiling SoX library ])],
    [
      SOX_LIB='${top_builddir}/libsoxconvert/src/libsoxconvert.a ${top_builddir}/libsoxconvert/libsox/libsox.a ${top_builddir}/libsoxconvert/libgsm/libgsm.a ${top_builddir}/libsoxconvert/lpc10/liblpc10.a ${top_builddir}/libsoxconvert/libsox/libsfx.a'
      SOX_CONFIGURE="yes"
      SOX_LINK=
    ])



## All dependencies will be built

AC_ARG_ENABLE(all-builds,
    [AS_HELP_STRING([--enable-all-builds],[Compiling all libraries ])],
    [ 
      FLAC_CONFIGURE=yes
      SOX_CONFIGURE=yes
      SOX_LIB='${top_builddir}/libsoxconvert/src/libsoxconvert.a ${top_builddir}/libsoxconvert/libsox/libsox.a ${top_builddir}/libsoxconvert/libgsm/libgsm.a ${top_builddir}/libsoxconvert/lpc10/liblpc10.a ${top_builddir}/libsoxconvert/libsox/libsfx.a' 
      FLAC_LIB='${top_builddir}/libFLAC/libFLAC121.a'
      OGG_LIB='${top_builddir}/libFLAC/include/libogg/src/libogg.a'
      GLIBC='${top_builddir}/glibc/libglibc.a'
      glibc_replacement=yes
      FLAC_LINK=
      OGG_LINK=
      SOX_LINK=
      ])

#multichannel is enable by default, disable it with --disable-multichannel
#AC_ARG_ENABLE(multichannel,
#    [AS_HELP_STRING([--disable-multichannel],[Switches off multichannel support])],
#    [
#      if x$enableval != xno ; then
#       
#         AC_DEFINE([STEREO], [1], [Switches off multichannel support])
#      fi
#    ]
#    , [AC_DEFINE([EXTENDED], [1], [Switches on multichannel support])])

# on GNU/Linux, installed libc functions will be used.
# on other platforms, strdup will be recompiled from
# glibc/ source files ;
# further, strndup and getsubopt will be recompiled from glibc/
# if not available on platform.
# the following developper option forces this behavior even on GNU/Linux

#obsolescent function checks have been retrieved from autoscan output
#putting replacement objects in $(LIBOBJS)

AC_FUNC_MALLOC
AC_FUNC_STRNLEN
AC_FUNC_FSEEKO

#checks only
AC_CHECK_FUNCS([floor memmove memset mkdir rmdir setlocale strerror strtol snprintf fseek setlocale strchr strdup strndup strstr strnlen getsubopt memchr])

#if libglibc.a was not built, use either -liberty or $(LIBOBJS) in src/Makefile.am
#depending on platform and availability of libiberty.a

LIBIBERTY=

if test x$glibc_replacement = xno ; then

 AC_CONFIG_LIBOBJ_DIR([glibc])

 case "${build}" in

  *-*-freebsd*)
     LIBS=
     AC_SEARCH_LIBS(strndup, iberty, 
     [
      AC_MSG_RESULT([FreeBSD: Compiling with libiberty])
      LIBIBERTY=-liberty
     ], [
      AC_DEFINE([HAVE_NO_LIBERTY], [1], [Compiling without libiberty.a])
      AC_MSG_RESULT([FreeBSD: Compiling without libiberty, using LIBOBJ])
      AC_LIBOBJ([strdup])
      AC_LIBOBJ([strndup])
     ])
  ;;

  *-*-mingw32*)
    AC_DEFINE([HAVE_NO_LIBERTY], [1], [Compiling without libiberty.a])
    AC_MSG_RESULT([Mingw: Compiling without libiberty, using LIBOBJ])
    AC_LIBOBJ([strdup])
    AC_LIBOBJ([strndup])
    AC_LIBOBJ([strchrnul])
    AC_LIBOBJ([getsubopt]) 


  ;;
  *)
    AC_SEARCH_LIBS(strndup, iberty,
    [
     AC_MSG_RESULT([Compiling with libiberty])
     LIBIBERTY=-liberty
    ],
    [
     AC_DEFINE([HAVE_NO_LIBERTY], [1], [Compiling without libiberty.a])
     AC_MSG_RESULT([Other platforms: Compiling without libiberty, using LIBOBJ])
     AC_LIBOBJ([strdup])
     AC_LIBOBJ([strndup])
     AC_LIBOBJ([strchrnul])
     AC_LIBOBJ([getsubopt]) 
    ])
  ;;
 esac
fi
 

## Ogg FLAC needs explicit enable


AC_ARG_ENABLE(ogg-flac,
    [AS_HELP_STRING([--disable-ogg-flac],[Compiling FLAC without Ogg FLAC support ])],
    [
      if test x$enableval = xno ; then
        AC_MSG_RESULT([Disabling Ogg FLAC ... ])   
        OGG_FLAC_SUPPORTED=no
      fi
    ])

# if libFLAC.a is built then also build libogg.a because of dependenciesn in libFLAC
# -logg will not do in this case


if test x${FLAC_CONFIGURE} = xyes ; then
  MAYBE_FLAC=libFLAC
else
  MAYBE_FLAC=
fi

if test x${SOX_CONFIGURE} = xyes ; then
  MAYBE_SOX=libsoxconvert
else
  MAYBE_SOX=
fi


if test x$glibc_replacement = xyes ;  then
  MAYBE_GLIBC=glibc
else
  MAYBE_GLIBC=
fi

if test "x$LIBOBJS" != "x" ; then 
   MAYBE_GLIBC=glibc  
fi


# Check for ALSA
AC_MSG_CHECKING([whether to try building ALSA sound driver])
AC_ARG_ENABLE(alsa,
    AS_HELP_STRING([--disable-alsa],[Don't build ALSA sound driver.]),,enable_alsa=yes)
AC_MSG_RESULT($enable_alsa)
if test "$enable_alsa" = "yes"; then
    AC_CHECK_HEADERS(alsa/asoundlib.h,
        AC_CHECK_LIB(asound, snd_pcm_open, ALSA_LIBS="$ALSA_LIBS -lasound", enable_alsa=no),
        enable_alsa=no)
fi
if test x$enable_alsa = xyes; then
   AC_DEFINE(HAVE_ALSA, 1, [Define to 1 if you have ALSA.])
fi

AM_CONDITIONAL(HAVE_ALSA, test x$enable_alsa = xyes)
AC_SUBST(ALSA_LIBS)
AC_SUBST(LIBIBERTY)
AC_SUBST(FLAC_LIB)
AC_SUBST(SOX_LIB)
AC_SUBST(FIXWAV_LIB)
AC_SUBST(OGG_LIB)
AC_SUBST(FLAC_CONFIGURE)
AC_SUBST(SOX_CONFIGURE)
AC_SUBST(FLAC_LINK)
AC_SUBST(OGG_LINK)
AC_SUBST(SOX_LINK)
AC_SUBST(GLIBC)
AC_SUBST(MAYBE_FLAC)
AC_SUBST(MAYBE_GLIBC)
AC_SUBST(MAYBE_SOX)
AC_SUBST(MAYBE_FIXWAV)

##########################################################################
# if --enable-flac-build then configure dependency in libFLAC subdir
# if --enable-sox-build then configure dependency in libsoxconvert subdir
##########################################################################

if test "x$FLAC_CONFIGURE" = "xyes" ; then
    AC_CONFIG_SUBDIRS([libFLAC])
fi

if test "x$SOX_CONFIGURE" = "xyes" ; then
    AC_CONFIG_SUBDIRS([libsoxconvert])
fi

#####################
# Checks for programs
#####################

AC_PROG_INSTALL
AC_PROG_LN_S
AC_PROG_MAKE_SET
AM_PROG_CC_C_O
AC_PROG_CC_STDC

if test x$ac_cv_c_compiler_gnu = xyes ; then
GCC_MAJOR_VERSION=`$CC -dumpversion | sed "s/\..*//"`
AC_DEFINE([ALWAYS_INLINE], [1], [Always inline when ALWAYS_INLINE is set])
# using -liberty to bootstrap GNU libc usage
fi

#######################################
# optional debugging/optimization flags
#######################################


#preserving user CFLAGS input
cflags_save=$CFLAGS
CFLAGS=""

#redefine CFLAGS to avoid systematic -g -O2 introduced by AC_PROG_CC
#This should come after AC_PROG macros

DEBUG_FLAGS=""
LIBS=""
AC_ARG_WITH(debug,
    [AS_HELP_STRING([--with-debug],[ =full for debugging, =no for Release build ])],
    [
       if test "x$withval" = "xno"; then
          if test x$ac_cv_c_compiler_gnu = xyes ; then
        CFLAGS="-std=c99  -g0 -O3"
                #exceptionally erasing -g and -O2 from user CFLAGS input
                cflags_save=`echo $cflags_save | sed "s/-g \(.*\)-O2/ \1/g"`
        LIBS='-s'
             fi

     elif test "x$withval" = "xfull"; then
              if test x$ac_cv_c_compiler_gnu = xyes ; then
        CFLAGS="-g3 -O0"
                cflags_save=`echo $cflags_save | sed "s/-g \(.*\)-O2/ \1/g"`
        DEFS='-DDEBUG'
             fi
    else
        CFLAGS="-std=c99"
        fi
    ],
    [
            CFLAGS="$CFLAGS"
    ])

#adding user input
CFLAGS="$CFLAGS $cflags_save"

AC_ARG_WITH(debug-flags,
    [AS_HELP_STRING([--with-debug-flags],[Debug build flags])],
    [
         DEBUG_FLAGS=$withval
    ],
    [
     DEBUG_FLAGS=""
    ])

AC_SUBST(DEBUG_FLAGS)

####################################################
# checks whether the compiler is fully C99-compliant
####################################################

if test "x$ac_cv_prog_cc_stdc" = "xno" ; then
    AC_MSG_WARN([C compiler does not support ISO C99 standard])
fi

AC_C99_FLEXIBLE_ARRAY
AC_C99_SIZE_VARIABLE_STATIC_ARRAY
if test x$ac_cv_c99_flexible_array != xyes ; then

    AC_MSG_WARN([Compiler does not support feature known as the flexible array struct member])
fi
if test x$ac_cv_c99_size_variable_static_array != xyes ; then

        AC_MSG_WARN([Compiler does not support size-variable static arrays])
fi

AC_C_VARARRAYS
AC_C_CONST
AC_C_INLINE

##########################################
# checking endianness
##########################################

# Determine endian-ness of target processor.

AC_C_FIND_ENDIAN

AC_DEFINE_UNQUOTED(CPU_IS_BIG_ENDIAN, ${ac_cv_c_big_endian},
    [Target processor is big endian.])
AC_DEFINE_UNQUOTED(CPU_IS_LITTLE_ENDIAN, ${ac_cv_c_little_endian},
    [Target processor is little endian.])


if test x${ac_cv_c_big_endian} = xyes ; then
   CFLAGS="$CFLAGS   -DCPU_IS_BIG_ENDIAN    "
else
  CFLAGS="$CFLAGS  -DCPU_IS_LITTLE_ENDIAN"
fi

###########################################
# Checks for libraries and headers
###########################################a

# libtool version 2.2.6 requested
# AC_PROG_LIBTOOL is obsolete



# Checks for header files.
AC_HEADER_DIRENT
AC_HEADER_STDBOOL
AC_CHECK_HEADERS([errno.h sys/stat.h time.h inttypes.h locale.h stdint.h stdlib.h string.h sys/time.h unistd.h fnctl.h])

###############################################################
# Checks for typedefs, structures, and compiler characteristics
###############################################################

AC_C_CONST
AC_TYPE_INT16_T
AC_TYPE_INT32_T
AC_TYPE_INT64_T
AC_TYPE_MODE_T
AC_TYPE_OFF_T
AC_TYPE_SIZE_T
AC_STRUCT_TM
AC_TYPE_UINT16_T
AC_TYPE_UINT32_T
AC_TYPE_UINT64_T
AC_TYPE_UINT8_T
AC_CHECK_TYPES([fpos_t], [AC_MSG_RESULT([fpos_t exists on platform])],[AC_MSG_WARN([WARNING: fpos_t does not exists on platform])])
                

####################
# Large file support 
####################


AC_SYS_LARGEFILE
AC_DEFINE([_FILE_OFFSET_BITS], [64], [Large file support enabled])

##########################
# checks installation dirs
##########################

# For BSD-type packaging, it is preferable not to use /usr/local as a default prefix

if test $prefix = "NONE" ; then

   if ! test -d /usr/share/pixmaps; then
      mkdir /usr/share/pixmaps
   fi
   if ! test -d /usr/share/applications; then
      mkdir /usr/share/applications
   fi
   #circumvent default /usr/local<dir> install
   libdir=/usr/lib
   bindir=/usr/bin
   datarootdir=/usr/share
   PIXDIR=/usr/share/pixmaps
   SHORTLINKDIR=/usr/share/applications

else
   AC_MSG_RESULT([Using $prefix as installation prefix])
   if ! test -d "$prefix/share/pixmaps"; then
       mkdir "$prefix/share/pixmaps"
   fi
   if ! test -d "$prefix/share/applications"; then
       mkdir "$prefix/share/applications"
   fi
   PIXDIR=$prefix/share/pixmaps
   SHORTLINKDIR=$prefix/share/applications
fi

###########################################################################################
# configuration file installation
#
# dvda-author.conf   will be installed in SHORTLINKDIR=INSTALL_CONF_DIR.
# ac_defining INSTALL_CONF_DIR is an alternative to configuring commonvars.h.in
# in AC_CONFIG_FILES. This requires:
# a) AC_DEFINE_UNQUOTED
# b) another identifier than SHORTLINKDIR
# c) including <config.h> in commonvars.h
# if not using configure, define SETTINGSFILE=full/path/to/dvda-author.conf at compile time
###########################################################################################


AC_ARG_WITH(config, [AS_HELP_STRING([--with-config],[Path to directory of configuration file])], [SHORTLINKDIR=$withval], [])


AC_DEFINE_UNQUOTED(INSTALL_CONF_DIR, "$SHORTLINKDIR", [Defines directory of .desktop and .conf files])
AC_SUBST(SHORTLINKDIR)
AC_SUBST(PIXDIR)


AC_MSG_NOTICE([Configuring ${PACKAGE_TARNAME}...])
AC_CONFIG_FILES([Makefile
         dvda-author.desktop
         dvda-author.nsi
         src/Makefile
         src/include/Makefile
         libutils/Makefile
         libutils/include/Makefile
         libutils/private/Makefile
         fixwav/Makefile
         fixwav/src/Makefile
         fixwav/src/include/Makefile
         fixwav/CB_project/Makefile
         fixwav/CB_project/fixwav/Makefile
         fixwav/CB_project/libfixwav/Makefile
         fixwav/images/Makefile
         libFLAC/Makefile
         libFLAC/config/Makefile
         libFLAC/FLAC/Makefile
         libFLAC/private/Makefile
         libFLAC/share/Makefile
         libFLAC/share/grabbag/Makefile
         libFLAC/protected/Makefile
         libFLAC/include/libogg/Makefile
         libFLAC/include/libogg/src/Makefile
         libFLAC/include/libogg/include/Makefile
         libFLAC/include/libogg/include/ogg/Makefile
         libFLAC/include/libogg/include/ogg/config_types.h
         libFLAC/include/libogg/win32/Makefile
         libFLAC/include/libogg/ogg.pc
         libFLAC/include/libogg/ogg-uninstalled.pc
         CB_project/Makefile
         CB_project/dvda-author/Makefile
         CB_project/libc_utils/Makefile
         CB_project/libfixwav/Makefile
         CB_project/libFLAC/Makefile
         CB_project/libogg/Makefile
         CB_project/libats2wav/Makefile
         CB_project/libsoxconvert/Makefile
         CB_project/libsox/Makefile
         glibc/Makefile
         libats2wav/Makefile
         images/Makefile
         libsoxconvert/Makefile
         libsoxconvert/src/Makefile
         libsoxconvert/libgsm/Makefile
         libsoxconvert/lpc10/Makefile
         libsoxconvert/sox.pc
])

AC_OUTPUT

#######################
# configuration summary
#######################

AC_MSG_RESULT([

*************************************************
* ${PACKAGE_TARNAME} was configured
*************************************************

You can now build ${PACKAGE_TARNAME} by issuing 'make'.
When the build is complete, become root and install
it by issuing 'make install'.
A ${PACKAGE_TARNAME} man page will be installed on Unix system

  Configuration summary :

    Version : ..................... $VERSION

    Dependencies:
                 ...................fixwav/libfixwav13.a
                 ...................$FLAC_LIB
                 ...................$OGG_LIB
                 ...................$SOX_LIB

    Build libraries:
                    libFLAC ........$FLAC_CONFIGURE
                    libogg  ........$FLAC_CONFIGURE
                    libsox  ........$SOX_CONFIGURE
                    gnu libc .......$glibc_replacement
                    libats2wav .....yes
                    libutils .......yes

    Ogg FLAC support:
                     ...............$OGG_FLAC_SUPPORTED

])

if test x$ac_cv_c_compiler_gnu = xyes -a x$glibc_replacement = xno ; then
  AC_MSG_RESULT([
  Tools :
         Compiler is GCC : ............. $ac_cv_c_compiler_gnu
])
fi

if test x$LIBIBERTY != x ; then


  AC_MSG_RESULT([
         libiberty.a will be linked to
])
fi

if test x$glibc_replacement = xyes ; then

  AC_MSG_RESULT([

  GNU lib sources in glibc/ will be recompiled for enhanced portability.
])
fi


if test x$ac_cv_c_big_endian = xyes ; then
    AC_MSG_RESULT([    Machine is big- endian])
else
    AC_MSG_RESULT([    Machine is little-endian])
fi


AC_MSG_RESULT([[
  Installation directories :
    prefix is: ....................$prefix
    exec_prefix is: ...............$exec_prefix
    Library directory: ........... $libdir
    Program directory: ........... $bindir
    Man pages: ................... $datarootdir/man/man1
    Documentation directory: ..... $datarootdir/doc/${PACKAGE_TARNAME}
    Images directory: ............ $PIXDIR
    Configuration files: ......... $SHORTLINKDIR

]])



