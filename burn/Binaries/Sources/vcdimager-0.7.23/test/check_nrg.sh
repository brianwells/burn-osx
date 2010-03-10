#!/bin/sh
#$Id: check_nrg.sh,v 1.2 2003/11/10 11:57:53 rocky Exp $
# Test Nero disk image reading 

if test -z $srcdir ; then
  srcdir=`pwd`
fi

. ${srcdir}/check_common_fn
. ${srcdir}/check_vcdinfo_fn
. ${srcdir}/check_vcdimager_fn
. ${srcdir}/check_vcdxbuild_fn
. ${srcdir}/check_vcdxrip_fn

BASE=`basename $0 .sh`

test_vcdxbuild ${srcdir}/$BASE.xml '--image-type=nrg'
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
1284184221 2630472 videocd.nrg
EOF
    then
    :
else
    echo "$0: cksum(1) checksums didn't match :-("

    cksum videocd.nrg
    exit 1
fi

echo "$0: vcdxbuild cksum(1) checksums matched :-)"

test_vcdxrip \
'--norip --no-command-comment --input videocd.nrg  --output-file svcd1_nrg.xml' \
    svcd1_nrg.xml ${srcdir}/svcd1_nrg.xml-right
RC=$?
check_result $RC 'vcdxrip test 1'

test_vcdinfo '-B -i videocd.nrg -I' \
  svcd1_nrg.dump ${srcdir}/svcd1_nrg.right
RC=$?
check_result $RC 'vcd-info test 1'

cp ${srcdir}/avseq00.m1p avseq01.mpg
cp ${srcdir}/item0000.m1p item0001.mpg

if test ! -f ${BASE}2.xml ; then 
  cp ${srcdir}/${BASE}2.xml ${BASE}2.xml
  REMOVE_EXTRA=${BASE}2.xml
fi

test_vcdxbuild ${BASE}2.xml '--image-type=nrg'
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
2897989104 1653964 videocd.nrg
EOF
    then
    :
else
    echo "$0: cksum(1) checksums didn't match :-("

    cksum videocd.nrg

    test_vcdxbuild_cleanup
    exit 1
fi

echo "$0: vcdxbuild cksum(1) checksums matched :-)"

rm -f avseq01.mpg
rm -f item0001.mpg

test_vcdxrip \
'--no-command-comment --input videocd.nrg  --output-file vcd20_nrg.xml' \
    vcd20_nrg.xml ${srcdir}/check_nrg2.xml
RC=$?
check_result $RC 'vcdxrip generation'

# 
# Compare extracted avseq and item
cmp_files avseq01.mpg ${srcdir}/avseq00.m1p vcdxrip
check_result $RC 'vcdxrip sequence extraction'

cmp_files item0001.mpg ${srcdir}/item0000.m1p vcdxrip
RC=$?
check_result $RC 'vcdxrip segment extraction'

test_vcdinfo '-B -i videocd.nrg -I' \
  vcd20_nrg.dump ${srcdir}/vcd20_nrg.right
RC=$?
check_result $RC 'vcd-info test 2'

test_vcdinfo '-B -i videocd.nrg --debug 3 -I' \
  vcd20_nrg3.dump ${srcdir}/vcd20_nrg3.right
RC=$?
check_result $RC 'vcd-info test 3'

# if we got this far, everything should be ok
test_vcdxbuild_cleanup videocd.nrg vcd20_nrg.xml $REMOVE_EXTRA
exit $RC

#;;; Local Variables: ***
#;;; mode:shell-script ***
#;;; eval: (sh-set-shell "bash") ***
#;;; End: ***
