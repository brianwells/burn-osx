#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.
# libFLAC script Copyright Fabrice Nicol 2008 <fabnicol@users.sourceforge.net>
####################################################################################################


AC_PREREQ(2.63)
AC_INIT([libflac],[1.2.1],[fab])
AC_CONFIG_SRCDIR([window.c])
AC_CONFIG_HEADER([config.h])

# Path to auxiliary configuration files
# AC_CONFIG must be called before AM_INIT_AUTOMAKE
AC_CONFIG_AUX_DIR([config])
AC_CONFIG_MACRO_DIR([m4])

AC_CANONICAL_BUILD
AM_INIT_AUTOMAKE([-Wall dist-bzip2])

# Checks for libraries.
LT_INIT([static disable-shared])
LT_PREREQ([2.2.6])

#preserving user CFLAGS input
cflags_save=$CFLAGS
CFLAGS=""

#redefine CFLAGS to avoid systematic -g -O2 introduced by AC_PROG_CC

DEBUG_FLAGS=""
LIBS=""

OGG_CONFIGURE=yes
OGG_FLAC_SUPPORT=1
MAYBE_OGG=
OGG_LINK=
OGG_LIB=


AC_ARG_WITH(ogg, [AS_HELP_STRING([--with-ogg],[path to Ogg library])],
   [if test x$withval != xyes; then
    OGG_LIB=$withval
    OGG_CONFIGURE=no
    fi
   ]
, [])

 
AC_ARG_ENABLE(ogg-build, 
	[AS_HELP_STRING([--enable-ogg-build],[Compiling ogg library again ])
	 AS_HELP_STRING([--disable-ogg-build],[Do not compile ogg library again ])],
	[ if test x$enableval = xno ; then
          OGG_CONFIGURE=no
          fi 
	])	
	
AC_ARG_ENABLE(ogg-flac, 
	[AS_HELP_STRING([--disable-ogg-flac],[Compiling FLAC without Ogg FLAC support ])],
        [
         if x$enableval = xno  ; then
          OGG_FLAC_SUPPORT=0
         fi 
        ]

	)
		
AC_ARG_ENABLE(all-builds, 
	[AS_HELP_STRING([--enable-all-builds],[Compiling all libraries ])],
	[ OGG_CONFIGURE=yes
	])	


if test x$OGG_CONFIGURE = xyes ; then

        MAYBE_OGG=include
        OGG_LINK=
        OGG_LIB='${top_builddir}/include/libogg/src/libogg.a'
		AC_CONFIG_SUBDIRS([include/libogg])

else

        # serves for libogg include/ogg/config_types.h if not configured in nested libogg package

        SIZE16="int16_t"
        SIZE32="int32_t"
        SIZE64="int64_t"
        USIZE16="uint16_t"
        USIZE32="uint32_t"
        AC_SUBST(SIZE16)
        AC_SUBST(USIZE16)
        AC_SUBST(SIZE32)
        AC_SUBST(USIZE32)
        AC_SUBST(SIZE64)
fi

AC_SUBST(OGG_LIB)
AC_SUBST(OGG_LINK)
AC_SUBST(OGG_CONFIGURE)
AC_SUBST(MAYBE_OGG)

##################################################################
# if --enable-ogg-build then configure dependency in libogg subdir
##################################################################

AC_TYPE_SIZE_T


# enables Ogg FLAC format

# FLAC__HAS_OGG enables Ogg FLAC support for FLAC 1.2.1
# and defines int variable FLAC_API_SUPPORTS_OGG_FLAC as 1

if test $OGG_FLAC_SUPPORT = 1; then
  AC_MSG_NOTICE([

Compiling with Ogg FLAC support...

])
  AC_DEFINE([FLAC__HAS_OGG], [1], [defines Ogg FLAC format])
fi

# Checks for programs.
AC_PROG_CC
AM_PROG_CC_C_O
AC_PROG_CC_STDC


if test "x$ac_cv_prog_cc_stdc" = "xno" ; then
	AC_MSG_FAILURE(["C compiler does not support ISO C99 standard"])
fi

# Checking for debug/optimization options 
# This must be inserted after AC_PROG_ macros

AC_ARG_WITH(debug, 
	[AS_HELP_STRING([--with-debug],[Debug build])],
	[
	   if test x$withval = xno ; then			
	      if test x$ac_cv_c_compiler_gnu = xyes ; then
		CFLAGS="-g0 -O3 "
                #exceptionally erasing -g and -O. from user CFLAGS input
                cflags_save=`echo $cflags_save | sed 's/-g/ /g' | sed 's/-O2/ /g'`
		LIBS='-s'
             fi
       
	 elif test x$withval = xfull ; then
              if test x$ac_cv_c_compiler_gnu = xyes ; then
		CFLAGS="-g -O0"
                cflags_save=`echo $cflags_save | sed 's/-g./-g/g' | sed 's/-O./-O0/g'`
		DEFS='-DDEBUG' 
             fi
	else	
		 echo "withval=$withval"
                 CFLAGS="-std=c99"
        fi
	],
	[ 
	        CFLAGS="$CFLAGS"
	])

#adding user input

CFLAGS="$CFLAGS $cflags_save"
AC_MSG_NOTICE([
Compiling with CFLAGS=$CFLAGS
])




# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([fcntl.h inttypes.h limits.h mach/mach.h netinet/in.h stddef.h stdint.h stdlib.h string.h sys/param.h unistd.h utime.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_HEADER_STDBOOL
AC_TYPE_INT16_T
AC_TYPE_INT32_T
AC_TYPE_INT64_T
AC_TYPE_OFF_T
AC_TYPE_SIZE_T
AC_TYPE_UINT16_T
AC_TYPE_UINT32_T
AC_TYPE_UINT64_T
AC_C_VOLATILE
AC_CHECK_TYPES([fpos_t])

# Checks for library functions.
AC_FUNC_CHOWN
AC_FUNC_FSEEKO
AC_FUNC_MEMCMP
AC_FUNC_REALLOC

AC_FUNC_STAT
AC_FUNC_STRTOD
AC_FUNC_UTIME_NULL
AC_CHECK_FUNCS([memchr memmove memset strchr strdup strrchr utime])

AC_CONFIG_FILES([Makefile
		 FLAC/Makefile
		 private/Makefile
		 share/Makefile 
		 share/grabbag/Makefile
		 protected/Makefile
		 include/Makefile
		 include/libogg/Makefile
  		 include/libogg/src/Makefile
  		 include/libogg/include/Makefile 
  		 include/libogg/include/ogg/Makefile
  		 include/libogg/include/ogg/config_types.h
  		 include/libogg/win32/Makefile
  		 include/libogg/ogg.pc
  		 include/libogg/ogg-uninstalled.pc
])
AC_OUTPUT

AC_MSG_RESULT([
************************
  libFLAC was configured
************************
])
