Summary       : MiNT Binary Utility Development Utilities
Name          : cross-mint-mintbin
Version       : 0.3
Release       : 2
Copyright     : GPL
Group         : Development/Tools

Packager      : Frank Naumann <fnaumann@freemint.de>
Vendor        : Sparemint
URL           : http://www.freemint.de/

Prefix        : %{_prefix}
Buildroot     : %{_tmppath}/%{name}-root

Source: mintbin-%{version}.tar.gz
Patch0: mintbin-0.3-nls.patch


%description
MiNTBin is a collection of supplementary utilities necessary for compiling 
programs for MiNT in a GNU development environment.  It also contains 
tools that are necessary for non-programmers like programs for changing
resp. inquiring program flags but its primary use it to accompany the
GNU binutils (version >2.9.1) on MiNT systems.

%description -l de
MiNTBin is eine Sammlung zusätzlicher Werkzeuge, die benötigt werden, um
Programme für MiNT in einer GNU-Entwicklungsumgebung zu erzeugen.  Das Paket
enthält auch Werkzeuge, die für Nicht-Programmiererinnen notwendig sind, 
z. B., um Programm-Flags zu ermitteln bzw. zu ändern.  Hauptzweck ist aber
die Ergänzung der GNU binutils (Version >2.9.1) auf MiNT-Systemen.


%prep
%setup -q -n mintbin-%{version}
%patch -p1 -b .nls


%build
CFLAGS="$RPM_OPT_FLAGS" \
./configure \
	--prefix=%{_prefix}
make


%install
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}

mkdir -p $RPM_BUILD_ROOT/usr/bin
make prefix=$RPM_BUILD_ROOT%{_prefix} install

ln -s %{_prefix}/m68k-atari-mint/bin/flags $RPM_BUILD_ROOT%{_prefix}/bin/m68k-atari-mint-flags
ln -s %{_prefix}/m68k-atari-mint/bin/stack $RPM_BUILD_ROOT%{_prefix}/bin/m68k-atari-mint-stack

strip $RPM_BUILD_ROOT%{_prefix}/bin/* || :
strip $RPM_BUILD_ROOT%{_prefix}/m68k-atari-mint/bin/* || :
gzip -q9f $RPM_BUILD_ROOT%{_prefix}/info/*.info*


%clean
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}


%post
  /sbin/install-info --info-dir=%{_prefix}/info --info-file=%{_prefix}/info/mintbin.info.gz >/dev/null 2>&1 || :

%preun
if [ $1 = 0 ] ;then
  /sbin/install-info --delete --info-dir=%{_prefix}/info %{_prefix}/info/mintbin.info.gz 2>/dev/null >/dev/null 2>&1 || :
fi


%files
%defattr(-,root,root)
%doc README TODO ABOUT-NLS COPYING ChangeLog NEWS README-alpha
%ifarch m68kmint
%{_prefix}/bin/*
%{_prefix}/include/*.h
%{_prefix}/include/stab.def
%{_prefix}/include/mint/*.h
%else
%{_prefix}/bin/m68k-atari-mint-*
%endif
%{_prefix}/m68k-atari-mint/bin/*
%{_prefix}/m68k-atari-mint/include/*.h
%{_prefix}/m68k-atari-mint/include/stab.def
%{_prefix}/m68k-atari-mint/include/mint/*.h
%{_prefix}/info/*info*
%{_prefix}/share/locale/*/LC_MESSAGES/mintbin.mo


%changelog
* Mon Apr 09 2000 Frank Naumann <fnaumann@freemint.de>
- first release
