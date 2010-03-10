Name: dvda-author
Summary: dvda-author creates high-definition DVD-AUDIO discs
Version: 09.03
Release: 1
License: GPL v3
Group: devel
Source: %{name}-%{version}.tar.bz2


BuildRoot: %{_tmppath}/build-root-%{name}
Packager: Fab Nicol
Distribution: linux
Prefix: /usr
Url: http://




%description
dvda-author creates high-definition DVD-Audio discs with navigable DVD-Video zone from DVD-Audio zone
Supported input audio types: .wav, .flac, .oga, SoX-supported formats
EXAMPLES
-creates a 3-group DVD-Audio disc (legacy syntax):

    dvda-author -g file1.wav file2.flac -g file3.flac -g file4.wav 

-creates a hybrid DVD disc with both AUDIO_TS mirroring audio_input_directory and VIDEO_TS imported from directory VID, outputs disc structure to directory DVD_HYBRID and links video titleset #2 of VIDEO_TS to AUDIO_TS:

    dvda-author -i ~/audio/audio_input_directory -o DVD_HYBRID -V ~/Video/VID -T 2 

Both types of constructions can be combined.   

%prep
rm -rf $RPM_BUILD_ROOT 
mkdir $RPM_BUILD_ROOT

%setup -q

%build
CFLAGS="$RPM_OPT_FLAGS" CXXFLAGS="$RPM_OPT_FLAGS" \
./configure --prefix=%{prefix}
make -j 2

%install
make DESTDIR=$RPM_BUILD_ROOT install-strip

cd $RPM_BUILD_ROOT

find . -type d -fprint $RPM_BUILD_DIR/file.list.%{name}.dirs
find . -type f -fprint $RPM_BUILD_DIR/file.list.%{name}.files.tmp
echo ./usr/local/share/man/man1/dvda-author.1 > $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/local/bin/dvda-author >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/local/lib/libc_utils.a >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/applications/dvda-author.desktop >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/pixmaps/dvda-author.png >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/applications/dvda-author.conf >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/applications/fixwav.desktop >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/doc/dvda-author/BUGS >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/doc/dvda-author/README >> $RPM_BUILD_DIR/file.list.%{name}.files
echo   ./usr/share/doc/dvda-author/dvda-author-09.03.html >> $RPM_BUILD_DIR/file.list.%{name}.files

find . -type l -fprint $RPM_BUILD_DIR/file.list.%{name}.libs
sed '1,2d;s,^\.,\%attr(-\,root\,root) \%dir ,' $RPM_BUILD_DIR/file.list.%{name}.dirs > $RPM_BUILD_DIR/file.list.%{name}
sed 's,^\.,\%attr(-\,root\,root) ,' $RPM_BUILD_DIR/file.list.%{name}.files >> $RPM_BUILD_DIR/file.list.%{name}
sed 's,^\.,\%attr(-\,root\,root) ,' $RPM_BUILD_DIR/file.list.%{name}.libs >> $RPM_BUILD_DIR/file.list.%{name}

rm -rf  /var/tmp/build-root-dvda-author/usr/include
rm -rf  /var/tmp/build-root-dvda-author/usr/lib
rm -rf  /var/tmp/build-root-dvda-author/usr/share/aclocal

%clean
rm -rf $RPM_BUILD_ROOT
rm -rf $RPM_BUILD_DIR/file.list.%{name}
rm -rf $RPM_BUILD_DIR/file.list.%{name}.libs
rm -rf $RPM_BUILD_DIR/file.list.%{name}.files
rm -rf $RPM_BUILD_DIR/file.list.%{name}.files.tmp
rm -rf $RPM_BUILD_DIR/file.list.%{name}.dirs

#%files -f ../file.list.%{name}
%files 
%defattr(-,root,root,0755)
%{_bindir}/*
%{_datadir}/applications/*
%{_datadir}/doc/*
%{_datadir}/pixmaps/*
%{_mandir}/man?/*

