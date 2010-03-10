info_TEXINFOS = vcdimager.texi vcd-info.texi vcdxrip.texi
vcdimager_TEXINFOS = fdl.texi gpl.texi glossary.texi

pdf: vcdimager.pdf vcd-info.pdf vcdxrip.pdf

txt: vcdimager.txt vcd-info.txt vcdxrip.txt svcd-ogt-subtitles.txt \
	cvd-subtitles.txt

ps: vcdimager.ps vcd-info.ps vcdxrip.html

html: vcdimager.html vcd-info.html vcdxrip.html svcd-ogt-subtitles.html \
	cvd-subtitles.html

%.ps.gz: %.ps
	gzip -9c $< > $@

.texi.pdf:
	texi2pdf $<

.texi.html:
	texi2html $<

.pod.html:
	pod2html $< > $@

.pod.txt:
	pod2text $< > $@

.texi.txt:
	makeinfo --no-headers $< > $@

all-formats: pdf dvi txt ps html

EXTRA_DIST = cvd-subtitles.pod svcd-ogt-subtitles.pod

MOSTLYCLEANFILES = vcdimager.tgs vcdimager.ps.gz vcdimager.pdf vcdimager.html vcdimager_toc.html vcdimager_foot.html vcd-info.cps vcd-info.kys vcd-info.html vcd-info.fns vcd-info.ps.gz vcd-info.pdf vcdxrip.cps vcdxrip.kys vcdxrip.html vcdxrip.fns vcdxrip.ps.gz vcdxrip.pdf
