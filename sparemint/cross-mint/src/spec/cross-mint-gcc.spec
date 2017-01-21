Summary       : Various compilers (C, C++, Objective-C, Chill, ...)
Name          : cross-mint-gcc
Version       : 2.95.3
release       : 1
Copyright     : GPL
Group         : Development/Languages

Packager      : Frank Naumann <fnaumann@freemint.de>
Vendor        : Sparemint
URL           : http://www.freemint.de/

Requires      : cross-mint-binutils cross-mint-libc-devel
BuildRequires : cross-mint-binutils cross-mint-libc-devel
Prereq        : /sbin/install-info

Prefix        : %{_prefix}
BuildRoot     : %{_tmppath}/%{name}-root

Source0: ftp://ftp.gnu.org/pub/gnu/gcc/gcc-%{version}.tar.gz
Source1: README.MiNT
Patch1:  gcc-2.95.3-mint-assert.patch
Patch2:  gcc-2.95.3-mint-config.patch
Patch4:  gcc-2.95.3-mint-target.patch
Patch5:  gcc-2.95.3-mintlib-c++.patch


%define STDC_VERSION 2.10.0
%define TARGET m68k-atari-mint


%description
The gcc package contains the GNU Compiler Collection: cc and gcc. You'll need
this package in order to compile C code.

%package c++
Summary       : C++ support for gcc
Group         : Development/Languages
Requires      : cross-mint-gcc = %{version}

%description c++
This package adds C++ support to the GNU C compiler. It includes support
for most of the current C++ specification, including templates and
exception handling. It does include the static standard C++
library and C++ header files.

%package objc
Summary       : Objective C support for gcc
Group         : Development/Languages
Requires      : cross-mint-gcc = %{version}

%description objc
gcc-objc provides Objective C support for the GNU C compiler (gcc).
Mainly used on systems running NeXTSTEP, Objective C is an
object-oriented derivative of the C language.

Install gcc-objc if you are going to do Objective C development and
you would like to use the gcc compiler.  You'll also need gcc.

%package g77
Summary       : Fortran 77 support for gcc
Group         : Development/Languages
Requires      : cross-mint-gcc = %{version}

%description g77
The gcc-g77 package provides support for compiling Fortran 77
programs with the GNU gcc compiler.

You should install gcc-g77 if you are going to do Fortran development
and you would like to use the gcc compiler.  You will also need gcc.

%package chill
Summary       : CHILL support for gcc
Group         : Development/Languages
Requires      : cross-mint-gcc = %{version}

%description chill
This package adds support for compiling CHILL programs with the GNU
compiler.

Chill is the "CCITT High-Level Language", where CCITT is the old
name for what is now ITU, the International Telecommunications Union.
It is is language in the Modula2 family, and targets many of the
same applications as Ada (especially large embedded systems).
Chill was never used much in the United States, but is still
being used in Europe, Brazil, Korea, and other places.

%package java
Summary       : Java support for gcc
Group         : Development/Languages
Requires      : cross-mint-gcc = %{version}

%description java
This package adds experimental support for compiling Java(tm) programs and
bytecode into native code. To use this you will also need the gcc-libgcj
package.
Note: gcc-libgcj is currently not available for m68k-atari-mint!


%prep
%setup -q -n gcc-%{version}
%patch1 -p1 -b .mint-assert
%patch2 -p1 -b .mint-config
%patch4 -p1 -b .mint-target
%patch5 -p1 -b .mintlib-c++


%build
rm -rf build-%{TARGET}
mkdir build-%{TARGET}
cd build-%{TARGET}

# 
# C++ with simple optimization, C++ Optimizer seems to be buggy
# 
CFLAGS="-O2 -D_GNU_SOURCE" \
CXXFLAGS="-O -D_GNU_SOURCE" \
../configure \
	--with-gnu-ld \
	--with-gnu-as \
	--prefix=%{_prefix} \
	--target=%{TARGET}

# rerun bison
# touch gcc/*.y

# as I have already installed the gcc 2.95.2 and compiled
# it several times there is no reason to bootstrap the
# compiler again and again
# it save lot of time to skip stage1 and stage2 and go
# directly to stage3
#make bootstrap ||:
make

# run the tests - not possible yet
# make -k check || true


%install
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}

cd build-%{TARGET}
make install \
	prefix=${RPM_BUILD_ROOT}%{_prefix} \
	mandir=${RPM_BUILD_ROOT}%{_mandir}

strip ${RPM_BUILD_ROOT}%{_prefix}/bin/* ||:

FULLVER=`${RPM_BUILD_ROOT}%{_prefix}/bin/%{TARGET}-gcc --version | cut -d' ' -f1`
FULLPATH=$(dirname ${RPM_BUILD_ROOT}%{_prefix}/lib/gcc-lib/%{TARGET}/${FULLVER}/cc1)

strip ${FULLPATH}/cc1
strip ${FULLPATH}/cc1chill
strip ${FULLPATH}/cc1obj
strip ${FULLPATH}/cc1plus
strip ${FULLPATH}/collect2
strip ${FULLPATH}/cpp0
strip ${FULLPATH}/f771
strip ${FULLPATH}/jc1
strip ${FULLPATH}/jvgenmain

# fix some things
rm -f ${RPM_BUILD_ROOT}%{_prefix}/info/dir
gzip -9nf ${RPM_BUILD_ROOT}%{_prefix}/info/*.info*
gzip -9nf ${RPM_BUILD_ROOT}%{_mandir}/*/*

cd ..
cp %{SOURCE1} gcc/


%clean
[ "${RPM_BUILD_ROOT}" != "/" ] && rm -rf ${RPM_BUILD_ROOT}


%pre
mkdir -p %{_prefix}/lib/gcc-lib/%{TARGET} 2>/dev/null ||:
mkdir -p %{_prefix}/%{TARGET}/lib/m68020-60/mshort 2>/dev/null ||:
mkdir -p %{_prefix}/%{TARGET}/lib/mshort 2>/dev/null ||:
mkdir -p %{_prefix}/%{TARGET}/include 2>/dev/null ||:


%files
%defattr(-,root,root)
%doc gcc/README* gcc/*ChangeLog* gcc/PROBLEMS gcc/NEWS gcc/SERVICE gcc/BUGS gcc/LANGUAGES
%{_mandir}/man1/%{TARGET}-gcc.1.gz
%{_prefix}/bin/%{TARGET}-gcc
%{_prefix}/bin/%{TARGET}-protoize
%{_prefix}/bin/%{TARGET}-unprotoize
%dir %{_prefix}/lib/gcc-lib/%{TARGET}/%{version}
%dir %{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include
%dir %{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60
%dir %{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/mshort
%dir %{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/mshort
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/cc1
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/collect2
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/cpp0
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/float.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/iso646.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/limits.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/proto.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/stdarg.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/stdbool.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/stddef.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/syslimits.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/varargs.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/libgcc.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/libgcc.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/mshort/libgcc.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/mshort/libgcc.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/SYSCALLS.c.X
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/specs

%files c++
%defattr(-,root,root)
%doc gcc/cp/NEWS gcc/cp/ChangeLog*
%{_mandir}/man1/%{TARGET}-g++.1.gz
%{_prefix}/bin/%{TARGET}-g++
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/cc1plus
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/exception
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/new
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/new.h
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/typeinfo
%{_prefix}/%{TARGET}/lib/libstdc++.a.%{STDC_VERSION}
%{_prefix}/%{TARGET}/lib/m68020-60/libstdc++.a.%{STDC_VERSION}
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/libstdc++.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/libstdc++.a
%{_prefix}/%{TARGET}/include/_G_config.h

%files objc
%defattr(-,root,root)
%doc gcc/objc/README libobjc/THREADS* libobjc/ChangeLog
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/cc1obj
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/libobjc.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/objc

%files g77
%defattr(-,root,root)
%doc gcc/f/README gcc/ChangeLog*
%{_mandir}/man1/%{TARGET}-g77.1.gz
%{_prefix}/bin/%{TARGET}-g77
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/f771
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/libg2c.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/libg2c.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/include/g2c.h

%files chill
%defattr(-,root,root)
%doc gcc/ch/README gcc/ch/chill.brochure gcc/ChangeLog*
%{_prefix}/bin/%{TARGET}-chill
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/cc1chill
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/chill*.o
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/libchill.a
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/chill*.o
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/m68020-60/libchill.a

%files java
%defattr(-,root,root)
%doc gcc/java/ChangeLog*
%{_prefix}/bin/%{TARGET}-gcj
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/jc1
%{_prefix}/lib/gcc-lib/%{TARGET}/%{version}/jvgenmain


%changelog
* Mon Apr 09 2000 Frank Naumann <fnaumann@freemint.de>
- first release
