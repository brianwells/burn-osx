dnl Copyright (C) 2003, 2004 Herbert Valerio Riedel <hvr@gnu.org>
dnl Copyright (C) 2003, 2004, 2005 Rocky Bernstein <rocky@panix.com>
dnl
dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2, or (at your option)
dnl any later version.
dnl
dnl This program is distributed in the hope that it will be useful,
dnl but WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
dnl GNU General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this program; if not, write to the Free Software
dnl Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
dnl 02111-1307, USA.

define(RELEASE_NUM, 23)
define(LIBVCD_VERSION_STR, 0.7.$1)

AC_PREREQ(2.52)
AC_REVISION([$Id: configure.ac,v 1.43 2005/07/11 12:43:02 rocky Exp $])dnl

AC_INIT([GNU VCDimager],LIBVCD_VERSION_STR(RELEASE_NUM), 
	[bugs-vcdimager@gnu.org], [vcdimager])
AC_CONFIG_SRCDIR([lib/vcd.c])
AM_INIT_AUTOMAKE(1.6.0)

SPEC_VERSION=0.7.23
AC_SUBST(SPEC_VERSION)

dnl AM_ACLOCAL_INCLUDE(.)
dnl AM_CONFIG_HEADER(include/libvcd/acconfig.h)
AM_CONFIG_HEADER(config.h)

LIBVCD_VERSION_NUM=RELEASE_NUM
AC_SUBST(LIBVCD_VERSION_NUM)

AM_MISSING_PROG(HELP2MAN, help2man, $missing_dir)
AM_MISSING_PROG(CVS2CL, cvs2cl, $missing_dir)
AM_MAINTAINER_MODE

AM_SANITY_CHECK
AC_CANONICAL_HOST

AC_DEFINE_UNQUOTED(HOST_ARCH, "$host_os/$host_cpu", [host os/cpu identifier])

dnl conditionally built frontends

AC_ARG_WITH(cli-frontend,
	[  --without-cli-frontend  enable cli frontend (enabled by default)], 
	enable_cli_fe="${withval}", enable_cli_fe=yes)

AC_ARG_WITH(xml-frontend,
	[  --without-xml-frontend  enable XML frontend (enabled by default)], 
	enable_xml_fe="${withval}", enable_xml_fe=yes)

AC_ARG_WITH(versioned_libs,
[  --without-versioned-libs build versioned library symbols (enabled by default)],
enable_versioned_libs="${withval}", enable_versioned_libs=yes)

dnl programs

AC_PROG_CC
if test "x$GCC" != "xyes" 
then
  echo "*** non GNU CC compiler detected."
  echo "*** This package has not been tested very well with non GNU compilers"
  echo "*** you should try to use 'gcc' for compiling this package."
else
  WARN_CFLAGS="-Wall -Wchar-subscripts -Wmissing-prototypes -Wmissing-declarations -Wunused -Wpointer-arith -Wwrite-strings -Wnested-externs -Wno-sign-compare"

  warning_flags=""

  if test "x$enable_maintainer_mode" = "xyes"; then

    case $host_os in
     solaris*)
        # Something with -std=c99 in libcdio messes up the uint64_t decls
        # There is probably a better fix around somewhere.
	WOPT="-pedantic"
	;;
     *)
	WOPT="-std=c99 -pedantic"
        ;;
    esac
    
    WOPT="std=c99 -pedantic"
    SAVE_CFLAGS="$CFLAGS"
    CFLAGS="$CFLAGS $WOPT"
    AC_MSG_CHECKING([whether $CC accepts $WOPT])
    AC_TRY_COMPILE([], [], 
      [has_option=yes; warning_flags="$warning_flags $WOPT"], 
      has_option=no)
    CFLAGS="$SAVE_CFLAGS"
    AC_MSG_RESULT($has_option)
  fi

  for WOPT in $WARN_CFLAGS; do
    SAVE_CFLAGS="$CFLAGS"
    CFLAGS="$CFLAGS $WOPT"
    AC_MSG_CHECKING([whether $CC accepts $WOPT])
    AC_TRY_COMPILE([], [], has_option=yes, has_option=no)
    CFLAGS="$SAVE_CFLAGS"
    AC_MSG_RESULT($has_option)
    if test "x$has_option" = "xyes"; then
      warning_flags="$warning_flags $WOPT"
    fi
    unset has_option
    unset SAVE_CFLAGS
  done
  unset WOPT
  WARN_CFLAGS="$warning_flags"
  unset warning_flags
fi

AC_PROG_CPP
AM_PROG_CC_STDC
AC_PROG_AWK
dnl AM_PROG_LIBTOOL tests whether we have GNU ld
dnl this must come before checking --with-versioned-libs
dnl which requires GNU ld.
AM_PROG_LIBTOOL

dnl We use a diff in regression testing
AC_PATH_PROG(DIFF, diff, no)
DIFF_OPTS=

if test "$DIFF" = no ; then
   AC_PATH_PROG(DIFF, cmp, no)
else 
   dnl Try for GNU diff options.
  # MSDOG output uses \r\n rather than \n in tests
  for diff_opt in -w --unified ; do 
    if $DIFF $diff_opt ./configure ./configure > /dev/null 2>&1; then
      AC_MSG_RESULT([adding $diff_opt to diff in regression tests])
      DIFF_OPTS="$DIFF_OPTS $diff_opt"
    fi
  done
fi
AC_SUBST(DIFF)
AC_SUBST(DIFF_OPTS)

dnl libs
AC_CHECK_FUNCS(snprintf vsnprintf, , [AC_MSG_ERROR(required function not found)])

dnl For vcdimager and vcdxbuild to be able to set creation time of VCD
AC_CHECK_FUNCS(getdate strptime, , )

if test "x$enable_cli_fe" = "xyes" -o "x$enable_xml_fe" = "xyes"; then
  AM_PATH_LIBPOPT(, [enable_cli_fe=no; enable_xml_fe=no])
fi

if test "x$enable_xml_fe" = "xyes"; then
  AM_PATH_XML2(2.3.8, , enable_xml_fe=no)
fi

dnl headers

AC_DEFINE(_DEVELOPMENT_, [], enable warnings about being development release)
AC_DEFINE(_GNU_SOURCE, [], enable GNU libc extension)
AC_STDC_HEADERS
AC_CHECK_HEADERS(sys/stat.h stdint.h inttypes.h stdbool.h sys/mman.h)

if test "x$ac_cv_header_stdint_h" != "xyes" 
 then
   AC_CHECK_SIZEOF(int, 4)
   AC_CHECK_SIZEOF(long, 4)
   AC_CHECK_SIZEOF(long long, 8)
fi

dnl compiler
AC_C_BIGENDIAN
AC_C_CONST
AC_C_INLINE

dnl ISOC99_PRAGMA
AC_MSG_CHECKING([whether $CC supports ISO C99 _Pragma()])
AC_TRY_COMPILE([_Pragma("pack(1)")], [], [
  ISOC99_PRAGMA=yes 
  AC_DEFINE(HAVE_ISOC99_PRAGMA, [], [Supports ISO _Pragma() macro])
],ISOC99_PRAGMA=no)
AC_MSG_RESULT($ISOC99_PRAGMA)

dnl empty_array_size
AC_MSG_CHECKING([how to create empty arrays])

empty_array_size="xxx"
AC_TRY_COMPILE([],[struct { int foo; int bar[]; } doo;], empty_array_size="")

if test "x$empty_array_size" = "xxxx";then
 AC_TRY_COMPILE([],[struct { int foo; int bar[0]; } doo;], empty_array_size="0")
fi

if test "x$empty_array_size" = "xxxx"
then
  AC_MSG_ERROR([compiler is unable to creaty empty arrays])
else
  AC_DEFINE_UNQUOTED(EMPTY_ARRAY_SIZE, $empty_array_size, 
	[what to put between the brackets for empty arrays])
  changequote(`,')
  msg="[${empty_array_size}]"
  changequote([,])
  AC_MSG_RESULT($msg)
fi
dnl empty_array_size

#
# Check bitfield order in structs
#
AC_MSG_CHECKING([bitfield ordering in structs])
dnl basic compile test for all platforms
AC_COMPILE_IFELSE([
int
 main() {
  struct { char bit_0:1, bit_12:2, bit_345:3, bit_67:2; }
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ > 4)
  __attribute__((packed))
#endif
  bf = { 1,1,1,1 };
  switch (0) case 0: case sizeof(bf) == 1:;
  return 0;
}
], [], AC_MSG_ERROR([compiler doesn't support bitfield structs]))
    dnl run test
    AC_RUN_IFELSE([
int main() {
  struct { char bit_0:1, bit_12:2, bit_345:3, bit_67:2; }
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ > 4)
  __attribute__((packed))
#endif
  bf = { 1,1,1,1 };
  if (sizeof (bf) != 1) return 1;
  return *((unsigned char*) &bf) != 0x4b; }
], bf_lsbf=1, [
  AC_RUN_IFELSE([
int main() {
  struct { char bit_0:1, bit_12:2, bit_345:3, bit_67:2; }
#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ > 4)
  __attribute__((packed))
#endif
 bf = { 1,1,1,1 };
 if (sizeof (bf) != 1) return 1;
 return *((unsigned char*) &bf) != 0xa5; }
], bf_lsbf=0, AC_MSG_ERROR([unsupported bitfield ordering]))
  ],
  [case "$host" in
     *-*-mingw32* | *-*-cygwin*)
       bf_lsbf=1
     ;;
     *)
       AC_MSG_RESULT([unknown])
       AC_MSG_ERROR([value of bitfield test isn't known for $host
*********************************************************************
Value of bitfield test can't find out for cross-compiling and we
don't know its value for host "$host".
*********************************************************************])
  esac]
)

    if test "x$cross_compiling" = "xyes"; then
      TEXT=" (guessed)"
    else
      TEXT=""
    fi

    if test "x$bf_lsbf" = "x1"; then
      AC_MSG_RESULT(LSBF${TEXT})
      AC_DEFINE(BITFIELD_LSBF, [], [compiler does lsbf in struct bitfields])
    else
      AC_MSG_RESULT(MSBF${TEXT})
    fi
dnl

dnl system
PKG_CHECK_MODULES(LIBCDIO, libcdio >= 0.72, [], 
	[AC_MSG_ERROR(Required libcdio library not found. Please get libcdio from http://www.gnu.org/software/libcdio/ and install it.)])
AC_SUBST(LIBCDIO_LIBS)
AC_SUBST(LIBCDIO_CFLAGS)

PKG_CHECK_MODULES(LIBISO9660, libiso9660 >= 0.72, [], 
	[AC_MSG_ERROR(Required libiso9660 library (part of libcdio) not found. Please get libcdio from http://www.gnu.org/software/libcdio/ and install it.)])
AC_SUBST(LIBISO9660_CFLAGS)
AC_SUBST(LIBISO9660_LIBS)

case $host_os in
     cygwin*)
	AC_DEFINE([CYGWIN], [1], 
                  [Define 1 if you are compiling using cygwin])
	;;
     darwin*)
       AC_CHECK_HEADERS(IOKit/IOKitLib.h CoreFoundation/CFBase.h, 
                        [have_iokit_h="yes"])
       if test "x$have_iokit_h" = "xyes" ; then 
	 LIBS="$LIBS  -framework CoreFoundation -framework IOKit"
       fi
     ;;
esac

LIBS="$LIBS -lm"
CFLAGS="$CFLAGS $WARN_CFLAGS"

# We need either GNU make or --without-versioned-libs
if test "x$enable_versioned_libs" = "xyes" ; then 
  if test -n "$MAKE" ; then
    $MAKE --version 2>/dev/null >/dev/null
    if test "$?" -ne 0 ; then
       AC_MSG_ERROR(Either set MAKE variable to GNU make or use 
   --without-versioned-libs option)
    fi
  else 
    make --version 2>/dev/null >/dev/null
    if test "$?" -ne 0 ; then
       AC_MSG_ERROR(Either set MAKE variable to GNU make or use 
   --without-versioned-libs option)
    else 
      # Do we have GNU ld? We need that too.
      if test "$with_gnu_ld" != yes; then
        AC_MSG_WARN(I don't see GNU ld. I'm going to assume --without-versioned-libs)
	enable_versioned_libs='no'
      fi
    fi
  fi
fi

AM_CONDITIONAL(CYGWIN, test "x$CYGWIN" = "xyes")
AM_CONDITIONAL(BUILD_CLI_FE, test "x$enable_cli_fe" = "xyes")
AM_CONDITIONAL(BUILD_XML_FE, test "x$enable_xml_fe" = "xyes")
AM_CONDITIONAL(BUILD_VERSIONED_LIBS, test "x$enable_versioned_libs" = "xyes")

LIBVCD_CFLAGS='-I$(top_srcdir)/include/ -I$(top_srcdir)/lib/'
LIBVCD_LIBS='$(top_builddir)/lib/libvcd.la'
LIBVCDINFO_LIBS='$(top_builddir)/lib/libvcdinfo.la'
AC_SUBST(LIBVCD_CFLAGS)
AC_SUBST(LIBVCD_LIBS)
AC_SUBST(LIBVCDINFO_LIBS)

AC_CONFIG_FILES([ \
	Makefile \
	libvcdinfo.pc \
	amiga/Makefile \
	include/Makefile \
	include/libvcd/Makefile \
	include/libvcd/version.h \
	lib/Makefile \
	frontends/Makefile \
	frontends/xml/Makefile \
	frontends/cli/Makefile \
	docs/Makefile \
        docs/doxygen/Doxyfile \
	example/Makefile \
	test/check_common_fn \
	test/Makefile \
	vcdimager.spec \
])
AC_OUTPUT

if test -z "$enable_maintainer_mode"; then
  enable_maintainer_mode="no"
fi

echo "
Setup:
  Install path:     ${prefix}
  Build CLI FE:	    $enable_cli_fe
  Build XML FE:	    $enable_xml_fe
  Maintainer mode:  $enable_maintainer_mode
"

if test "x$enable_cli_fe" != "xyes" -a "x$enable_xml_fe" != "xyes"
then
  cat <<EOF
****************************************************************************
****************************************************************************
***                                                                      ***
***         WARNING: BUILDING ONLY LIBVCD W/O ANY FRONTENDS              ***
***      (maybe you are missing some libraries (libpopt 1.7 or greater   ***
***       and libxml2)?                                                  ***
***                                                                      ***
****************************************************************************
****************************************************************************
EOF
fi

dnl EOF
