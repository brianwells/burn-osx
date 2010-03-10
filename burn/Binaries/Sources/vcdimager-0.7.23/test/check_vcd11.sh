#!/bin/sh
#$Id: check_vcd11.sh,v 1.2 2003/11/10 11:57:53 rocky Exp $

if test -z $srcdir ; then
  srcdir=`pwd`
fi

. ${srcdir}/check_common_fn
. ${srcdir}/check_vcdinfo_fn
. ${srcdir}/check_vcdimager_fn
. ${srcdir}/check_vcdxbuild_fn
. ${srcdir}/check_vcdxrip_fn

BASE=`basename $0 .sh`

test_vcdimager --type=vcd11 ${srcdir}/avseq00.m1p
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
3746200718 1764000 videocd.bin
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

  test_vcdinfo '-B -i videocd.cue ' \
    vcd11_test0.dump ${srcdir}/vcd11_test0.right
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
1013953491 3880800 videocd.bin
2088931809 424 videocd.cue
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
'--norip --no-command-comment --input videocd.cue  --output-file vcd11_test1.xml' \
    vcd11_test1.xml ${srcdir}/vcd11_test1.xml-right
RC=$?
check_result $RC 'vcdxrip test 1'

test_vcdinfo '-B -i videocd.cue -I --show-filesystem' \
  vcd11_test1.dump ${srcdir}/vcd11_test1.right
RC=$?
check_result $RC 'vcd-info test 1'

test_vcdinfo '-B --cue-file videocd.cue -X -S --show-pvd vol' \
    vcd11_test2.dump ${srcdir}/vcd11_test2.right
RC=$?
check_result $RC 'vcd-info test 2'

# if we got this far, everything should be ok
test_vcdxbuild_cleanup
exit $RC

#;;; Local Variables: ***
#;;; mode:shell-script ***
#;;; eval: (sh-set-shell "bash") ***
#;;; End: ***
