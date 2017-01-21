Summary       : GEM libraries and header files
Name          : cross-mint-gemlibs
Version       : 1.0
Release       : 1
Copyright     : Public Domain
Group         : Development/Libraries

Packager      : Frank Naumann <fnaumann@freemint.de>
Vendor        : Sparemint
URL           : http://wh58-508.st.uni-magdeburg.de/sparemint/

BuildRequires : cross-mint-gcc, cross-mint-libc

Prefix        : %{_prefix}
BuildRoot     : %{_tmppath}/%{name}-root

Source: gemlibs-%{version}.tar.gz

%ifarch m68kmint
%define installdir %{_prefix}/GEM
%define CROSS no
%else
%define installdir %{_prefix}/m68k-atari-mint
%define CROSS yes
%endif


%package -n cross-mint-gemlib
Summary       : GEM libraries and header files
Group         : Development/Libraries

%package -n cross-mint-cflib
Summary       : Christian Felsch's GEM utility library
Group         : Development/Libraries
Requires      : cross-mint-gemlib

%package -n cross-mint-gemma
Summary       : Draco's minimal GEM utility library
Group         : Development/Libraries
Requires      : cross-mint-gemlib

%description
Nothing.

%description -n cross-mint-gemlib
Contains the standard libraries and header files to develop your own GEM
applications.

Attention, starting from version 0.40.0 the gemlib is heavily modernized
and updated. There are incompatible changes that require modifications
of programs that use this lib too.

%description -n cross-mint-cflib
This is a utility library/toolkit that provide a lot of helper functions
for developping GEM applications.  Sorry, the documentation is all
German.

NOTE: This package has experimental support for installing ST-Guide
hypertexts with rpm.  They will get installed in /usr/GEM/stguide.
Please make sure that this directory is located on a file system that
supports long filenames.  You should then edit your stguide.inf to
make sure that ST-Guide will search that directory for hypertexts.
Also make sure that stool (or stool.tos or stool.ttp) is found either 
in /usr/GEM/stguide or in your $PATH.

You should install cflib if you would like to write GEM applications
that support recent GEM extensions without having to care about 
compatibility issues.

%description -n cross-mint-gemma
This is the gemma GEM library. It is not yet completely finished, 
though most of the functions should be already functioning. The 
unfinished part is mostly the multidialog support (the library can 
actually handle only one opened dialog box per application).

Take this as a public alpha release.


%prep
%setup -q -n gemlibs-%{version}


%build
make CROSS=%{CROSS}


%install
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}

mkdir -p ${RPM_BUILD_ROOT}%{installdir}/{include/gemma,lib/m68020-60,stguide}

install -m 644 gemlib/lib{gem,gem16}.a ${RPM_BUILD_ROOT}%{installdir}/lib
install -m 644 gemlib/{gem,gemx}.h ${RPM_BUILD_ROOT}%{installdir}/include

install -m 644 cflib/lib{cflib,cflib16}.a ${RPM_BUILD_ROOT}%{installdir}/lib
install -m 644 cflib/cflib.h              ${RPM_BUILD_ROOT}%{installdir}/include
install -m 644 cflib/cflib.hyp            ${RPM_BUILD_ROOT}%{installdir}/stguide
install -m 644 cflib/cflib.ref            ${RPM_BUILD_ROOT}%{installdir}/stguide

install -m 644 gemma/documentation/gemma.hyp   ${RPM_BUILD_ROOT}%{installdir}/stguide
install -m 644 gemma/documentation/gemma.ref   ${RPM_BUILD_ROOT}%{installdir}/stguide
install -m 644 gemma/libgemma/libgemma.a       ${RPM_BUILD_ROOT}%{installdir}/lib
install -m 644 gemma/libgemma/libgemma_mt.a    ${RPM_BUILD_ROOT}%{installdir}/lib
install -m 644 gemma/libgemma/libgemma020.a    ${RPM_BUILD_ROOT}%{installdir}/lib/m68020-60
install -m 644 gemma/libgemma/libgemma020_mt.a ${RPM_BUILD_ROOT}%{installdir}/lib/m68020-60
install -m 644 gemma/libslb/libslb.a           ${RPM_BUILD_ROOT}%{installdir}/lib
install -m 644 gemma/src/gemma/*.h             ${RPM_BUILD_ROOT}%{installdir}/include/gemma
install -m 644 gemma/src/gemma.slb             ${RPM_BUILD_ROOT}%{installdir}/lib


%clean
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}


%files -n cross-mint-gemlib
%defattr(-,root,root)
%doc gemlib/ChangeLog*
%{installdir}/include/gem.h
%{installdir}/include/gemx.h
%{installdir}/lib/libgem.a
%{installdir}/lib/libgem16.a

%files -n cross-mint-cflib
%defattr(-,root,root)
%doc cflib/COPYING.LIB cflib/LiesMich
%doc cflib/demo cflib/intrface
%{installdir}/include/cflib.h
%{installdir}/lib/libcflib.a
%{installdir}/lib/libcflib16.a
%{installdir}/stguide/cflib.hyp
%{installdir}/stguide/cflib.ref

%files -n cross-mint-gemma
%defattr(-,root,root)
%doc gemma/COPYING gemma/README
%doc gemma/usage
%{installdir}/include/gemma
%{installdir}/lib/libgemma.a
%{installdir}/lib/libgemma_mt.a
%{installdir}/lib/m68020-60/libgemma020.a
%{installdir}/lib/m68020-60/libgemma020_mt.a
%{installdir}/stguide/gemma.hyp
%{installdir}/stguide/gemma.ref


%changelog
* Mon Apr 09 2000 Frank Naumann <fnaumann@freemint.de>
- first release
