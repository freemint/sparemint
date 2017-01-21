Summary       : GNU Binary Utility Development Utilities
Name          : cross-mint-binutils
Version       : 2.9.1
Release       : 1
Copyright     : GPL
Group         : Development/Tools

Packager      : Frank Naumann <fnaumann@freemint.de>
Vendor        : Sparemint
URL           : http://www.freemint.de/

Requires      : cross-mint-mintbin

Prefix        : %{_prefix}
Buildroot     : %{_tmppath}/%{name}-root

%define TARGET m68k-atari-mint

Source: ftp://prep.ai.mit.edu/binutils/binutils-%{version}.tar.gz
Patch0: binutils-mint0.patch
Patch1: binutils-mint1.patch
Patch2: binutils-mint2.patch
Patch3: binutils-mint3.patch
Patch5: binutils-2.9.1-gas.patch
Patch6: binutils-2.9.1-ldwarning.patch


%description
Binutils is a collection of utilities necessary for compiling programs. It
includes the assembler and linker, as well as a number of other
miscellaneous programs for dealing with executable formats.


%prep
%setup -q -n binutils-%{version}
%patch0 -p1
%patch1 -p1
%patch2 -p1
%patch3 -p1
%patch5 -p1 -b .gas
%patch6 -p1 -b .ldwarning


%build
CFLAGS="$RPM_OPT_FLAGS" \
CXXFLAGS="$RPM_OPT_FLAGS -O" \
./configure \
	--prefix=%{_prefix} \
	--target=%{TARGET}

make all info


%install
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}

make install install-info \
	prefix=$RPM_BUILD_ROOT%{_prefix} \
	mandir=$RPM_BUILD_ROOT%{_mandir}

mv $RPM_BUILD_ROOT%{_prefix}/include $RPM_BUILD_ROOT%{_prefix}/%{TARGET}
mv $RPM_BUILD_ROOT%{_prefix}/lib/* $RPM_BUILD_ROOT%{_prefix}/%{TARGET}/lib/

install -m 644 include/libiberty.h $RPM_BUILD_ROOT%{_prefix}/%{TARGET}/include

# strip executables
strip $RPM_BUILD_ROOT%{_bindir}/* ||:

# compress manpages
gzip -9nf $RPM_BUILD_ROOT%{_prefix}/info/*.info*
gzip -9nf $RPM_BUILD_ROOT%{_mandir}/man1/*


%clean
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}


%post
cat <<EOF
=================
!!! IMPORTANT !!!
=================
Both the new library and the executable format introduced with the
GNU binutils version 2.9.1 or later is incompatible with the formats
previously used for MiNT.  Please see the documentation for the
mintbin package for details on what you have to do.
EOF


%files
%defattr(-,root,root)
%doc README
%{_bindir}/%{TARGET}-*
%{_mandir}/*/%{TARGET}-*
%{_prefix}/%{TARGET}/bin/*
%{_prefix}/%{TARGET}/include/*
%{_prefix}/%{TARGET}/lib/*


%changelog
* Mon Apr 09 2000 Frank Naumann <fnaumann@freemint.de>
- first release
