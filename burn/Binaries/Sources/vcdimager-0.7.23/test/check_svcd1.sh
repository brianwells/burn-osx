#!/bin/sh
#$Id: check_svcd1.sh,v 1.2 2003/11/10 11:57:53 rocky Exp $

if test -z $srcdir ; then
  srcdir=`pwd`
fi

. ${srcdir}/check_common_fn
. ${srcdir}/check_vcdinfo_fn
. ${srcdir}/check_vcdimager_fn
. ${srcdir}/check_vcdxbuild_fn
. ${srcdir}/check_vcdxrip_fn

BASE=`basename $0 .sh`

test_vcdimager -t svcd ${srcdir}/avseq00.m1p
RC=$?

if test $RC -ne 0 ; then
  if test $RC -ne 77 ; then 
    echo vcdimager failed 
    exit $RC
  else
    echo vcdimager skipped
    test_vcdimager_cleanup
  fi
else
  if do_cksum <<EOF
3747978987 1587600 videocd.bin
3699460731 172 videocd.cue
EOF
    then
    :
  else
    echo "$0: cksum(1) checksums didn't match :-("

    cksum videocd.bin videocd.cue
    exit 1
  fi

  echo "$0: vcdimager cksum(1) checksums matched :-)"

  test_vcdinfo '--no-banner -i videocd.cue' \
    svcd1_test0.dump ${srcdir}/svcd1_test0.right
  RC=$?
  check_result $RC 'vcd-info test 0'
fi

test_vcdxbuild ${srcdir}/$BASE.xml
RC=$?
if test $RC -ne 0 ; then
  if test $RC -eq 77 ; then
    echo vcdxbuild skipped
    test_vcdxbuild_cleanup
  else
    echo vcdxbuild failed 
  fi
  exit $RC
fi

if do_cksum <<EOF
4104676060 4059552 videocd.bin
669873986 424 videocd.cue
EOF
    then
    :
else
    echo "$0: cksum(1) checksums didn't match :-("

    cksum videocd.bin videocd.cue

    test_vcdxbuild_cleanup
    exit 1
fi

echo "$0: vcdxbuild cksum(1) checksums matched :-)"

test_vcdxrip \
  '--norip --no-command-comment -c videocd.cue --output-file svcd1_test1.xml' \
  svcd1_test1.xml ${srcdir}/svcd1_test1.xml-right
RC=$?
check_result $RC 'vcdxrip test 1'

test_vcdinfo '--no-banner -i videocd.cue' \
    svcd1_test1.dump ${srcdir}/svcd1_test1.right
RC=$?
check_result $RC 'vcd-info test 1'

test_vcdinfo '--no-banner --cue-file videocd.cue --show-info-all' \
    svcd1_test2.dump ${srcdir}/svcd1_test2.right 
RC=$?
check_result $RC 'vcd-info test 2'

cp ${srcdir}/avseq00.m1p avseq01.mpg
cp ${srcdir}/item0000.m1p item0001.mpg

if test ! -f check_cue.xml ; then 
  cp ${srcdir}/check_cue.xml check_cue.xml
  REMOVE_EXTRA=check_cue.xml
fi

test_vcdxbuild check_cue.xml
RC=$?
if test $RC -ne 0 ; then
  if test $RC -eq 77 ; then
    echo vcdxbuild skipped
    test_vcdxbuild_cleanup
  else
    echo vcdxbuild failed 
  fi
  exit $RC
fi

if do_cksum <<EOF
3695643404 2018016 videocd.bin
483250638 172 videocd.cue
EOF
    then
    :
else
    echo "$0: cksum(1) checksums didn't match :-("

    cksum videocd.bin videocd.cue
    exit 1
fi

echo "$0: vcdxbuild cksum(1) checksums matched :-)"

rm -f avseq01.mpg
rm -f item0001.mpg

test_vcdxrip \
'--no-command-comment --input videocd.cue  --output-file svcd1_cue.xml' \
    svcd1_cue.xml ${srcdir}/check_cue.xml
RC=$?
check_result $RC 'vcdxrip generation'

# 
# Compare extracted avseq and item
cmp_files avseq01.mpg ${srcdir}/avseq00.m1p vcdxrip
check_result $RC 'vcdxrip sequence extraction'

cmp_files item0001.mpg ${srcdir}/item0000.m1p vcdxrip
RC=$?
check_result $RC 'vcdxrip segment extraction'

# if we got this far, everything should be ok
test_vcdxbuild_cleanup $REMOVE_EXTRA
exit $RC

#;;; Local Variables: ***
#;;; mode:shell-script ***
#;;; eval: (sh-set-shell "bash") ***
#;;; End: ***
