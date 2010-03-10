noinst_PROGRAMS = mpegscan mpegscan2 testimage testassert testvcd

INCLUDES = -I$(top_srcdir) $(POPT_CFLAGS) $(LIBVCD_CFLAGS) $(LIBCDIO_CFLAGS)

mpegscan_LDADD = $(LIBVCD_LIBS) $(LIBISO9660_LIBS)
mpegscan2_LDADD = $(LIBVCD_LIBS) $(LIBISO9660_LIBS)
testimage_LDADD = $(LIBVCD_LIBS) $(LIBISO9660_LIBS)
check_sizeof_LDADD = $(LIBVCD_LIBS) $(LIBISO9660_LIBS)
check_bitfield_LDADD = $(LIBVCD_LIBS) $(LIBISO9660_LIBS)
testassert_LDADD = $(LIBVCD_LIBS) $(LIBISO9660_LIBS)
testvcd_LDADD = $(LIBISO9660_LIBS) $(LIBVCDINFO_LIBS) $(LIBVCD_LIBS)

# make check targets

check_PROGRAMS = check_sizeof check_bitfield

check_SCRIPTS = check_vcd11.sh check_vcd20.sh check_svcd1.sh check_nrg.sh

check_DATA = avseq00.m1p item0000.m1p \
	check_vcd11.xml check_vcd20.xml check_svcd1.xml check_nrg.xml \
	vcd11_test0.right vcd20_test0.right svcd1_test0.right \
	vcd11_test1.right vcd20_test1.right svcd1_test1.right \
	vcd11_test2.right vcd20_test2.right svcd1_test2.right \
	vcd11_test1.xml-right vcd20_test1.xml-right svcd1_test1.xml-right \
	svcd1_nrg.xml-right svcd1_nrg.right check_nrg2.xml \
	vcd20_nrg.right vcd20_nrg3.right vcd20_test3.right check_cue.xml \
	svcd1_cue.xml-right

EXTRA_DIST = $(check_SCRIPTS) $(check_DATA) \
	check_common_fn check_common_fn.in  \
	check_vcdinfo_fn check_vcdimager_fn \
	check_vcdxbuild_fn check_vcdxrip_fn

TESTS = \
	check_sizeof \
	check_bitfield \
	check_nrg.sh   \
	check_vcd11.sh \
	check_vcd20.sh \
	check_svcd1.sh \
	testassert     \
	testvcd

XFAIL_TESTS = testassert


MOSTLYCLEANFILES = *.bin *.cue videocd.xml core core.* *.dump
