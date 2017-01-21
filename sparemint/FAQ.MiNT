Please try to find answers to your questions regarding the Redhat
Package Manager rpm in this file before you ask on the MiNT 
mailing lists or inquire at the Sparemint maintainers.

It is probably wise to read this file in its entirety, rpm will
become one of the most important tools you use on your system.

Please send corrections or additions to this file to Guido Flohr,
<guido(at)freemint.de>.

1. Errors When Installing Packages
   1.1 Conflicts
   1.2 File Not Found (or: No such file or directory)
   1.3 Truncated File Names In Error Messages
   1.4 Does Not Appear To Be An RPM Package
2. Popular Mistakes And Useful Hints
   2.1 Error That Package Is Not Installed Although It Is
   2.2 Pitfalls On Wildcards
   2.3 Database Backups
   2.4 Finding Packages For Download
   2.5 Installing Noarch Packages
3. Other Problems Not Related To RPM
   3.1 Spurious Errors
   3.2 Setting Stack Size Fails
   3.3 Recommended Stack Sizes
4. Documentation
   4.1 Maximum RPM
   4.2 RPM-HOWTO
   4.3 Manpage
   4.4 The System Behind the Command Line Options
   4.5 Getting An Overview
5. Building Packages From Sources
   5.1 Getting Started
   5.2 Design Guide
   5.3 Directory Structure - FHS Compliancy
   5.4 GEM applications
   5.5 Device Drivers And File Systems
   
1. Errors when installing packages
==================================

1.1 Conflicts

Q: I get a lot of error messages saying something about conflicts
   when installing a binary rpm.  What happens?

A: Some packages really conflict, i. e. you cannot have two smtp
   daemons simultaneously on your system.  If you have installed
   `smail' and then try to install `sendmail', rpm will refuse
   to do so, because the two packages will not work together.
   
   However, this case is currently quite unlikely, since there
   are not many packages that really conflict.  The most probable
   error is that you actually want to _upgrade_ a package and
   not install it.  For instance if you have alread installed
   `mintlib-0.55.27c' and two days later the maintainer of
   the MiNTLib comes up with the regular bugfix update
   `mintlib-0.55.27d' you have to type:
   
   	# rpm -Uvh mintlib-0.55.27d.m68kmint.rpm
   
   `-U' and not `-i'!  In update mode rpm operates slightly different
   than in install mode (but the usage is very similar).  In fact
   you can always use `-U' as a safe replacement for `-i'.  If the
   package `mintlib' is not installed and you upgrade instead of
   installing you can do no harm.  In that case rpm will act just
   as if you have given it the install mode option `-i'.

1.2 File Not Found (or: No such file or directory)

Q: I install a (binary or source) rpm and get an error message like
   `unpacking of archive failed on file /us: cpio: chown failed -
   file not found'.  What has happened there?
   
A: There is no easy answer to that question (and see FAQ 1.2 for
   ways to determine which file really caused the error, it is
   most probably not a file `/usr' as stated by the error message).
   
   a) Older versions of rpm had a bug in the routine that performed
   changing ownerships of symbolic links.  If you see that the 
   rpm file is quite old (July 1999 or older) and was build by
   Frank Naumann (not his fault!!! It was mine, Guido Flohr's) this 
   may cause the error.  Ask for an update of the package in
   question.
   
   b) MiNT (and all TOS compatible systems) often `abuses' the
   error message `file not found'.  The error is issued although
   something else is really meant, often that an operation was
   performed on a directory that can only be performed on regular
   files (like opening for reading/writing or deleting).  Both
   the MiNT kernel and the MiNTLib will successively reduce the
   occurence of such misleading error messages.
   
   c) The error message could be serious (very unlikely).  Try
   to find out which file is missing and report the error.  
   Actually rpm should check for all dependencies before starting
   the installation and should report missing files.

   d) Be careful with wildcards and jokers like `*', `?'
   and so on.  See the answers in the section `Pitfalls With
   Wildcards'.
   
   e) Symbolic links with odd permissions often cause the error.
   This is the most probable case and hard to fix because you have
   to do it yourself (btw, the fix is following the description,
   please read on, even if you don't understand everything).
   
   An example of such a package is smail.  If you had previously installed
   smail without the help of rpm, the program will encounter a 
   situation which it is not prepared for.  Your previous install
   most probably installed the actual program as `/usr/bin/smail'.
   If you list the file ownerships you will see something like this:
   
   	# ls -l /usr/bin/smail
   	-r-sr-xr-x   1 root     wheel      251096 Aug  4 06:16 /usr/bin/smail
   
   You may notice that the owner's execution bit is marked as
   `s' and not as `x' like usual.  This is called the `setuid'
   bit and means that ordinary users when invoking the program
   can temporarily mutate to the file's owner (here `root') to
   perform certain tasks that require superuser rights.
   
   But smail has a lot of names: `runq', `mailq', `/usr/etc/smtpd',
   `/usr/lib/sendmail', ... These are all the names that various
   programs expect as an MUA like smail and smail will also slightly
   change its default behavior, depending on the name it has been
   invoked with.
   
   If you list all files included in the smail package you will
   see something like this:
   
   	# rpm -qpl smail-3.2.0.101-1.m68kmint.rpm
   	/bin/rmail
   	/usr/doc/smail-3.2.0.101
   	/usr/doc/smail-3.2.0.101/README
   	...
   	/usr/lib/sendmail
   	/usr/sbin/smail
   	/usr/sbin/rmail
   	/usr/sbin/mailq
   	...
   
   First thing you see is that the default location for smail has
   changed from `/usr/bin/smail' to `/usr/sbin/smail', and most
   of the links have moved from previously `/usr/etc' to `/usr/sbin'.
   
   Now assume that the directories `/bin' and `/usr/bin' are not
   the same (i. e. you haven't symlinked them in your kernel config
   file `mint.cnf').  Now, if you install the smail rpm, rpm will
   first install the `rmail' program (link to smail), then a lot
   of documentation files, you will already see hashes (`#') and
   then it will barf out with
   
   	smail                       unpacking of archive failed on 
   	file /us: cpio: chown failed - file not found
   
   I can tell you that rpm really meant `/usr/lib/sendmail' and
   not `/us'.  OK, what happened here was that `/usr/lib/sendmail'
   already was a symbolic link to `/usr/bin/smail'.  Usually
   that is no problem, rpm will simply overwrite the old link.
   But in this case the link pointed to a file which has the
   setuid bit set and that currently outsmarts rpm.  It is not
   yet clear if that is a bug in rpm, in the MiNTLib or the 
   MiNT kernel.  This intolerable bug has to get fixed but there
   had been no time to do it (and fixing it may have dangerous
   result, so care should be taken for it).
   
   To make things worse, we assume that you are the average lunatic
   that doesn't believe such error messages.  You simply repeat
   the command (`rpm -ivh smail*') and this time rpm will fail
   earlier (before you even saw a hash `#').  Why?  Now rpm will
   fail on the very first file `/bin/rpm' because that is also
   a symbolic link.
   
   You will usually come across this bug with packages that install
   internet daemons (like smail) or system administration tools
   because these packages usually install linked files in conjunction
   with special permission bits.
   
   How to fix it:  The problem would be solved if rpm knew that
   the problematic files already exist, because it would then delete
   them before overwriting.  And that leads to the fix:
   
   	# rpm -i --justdb smail-3.2.0.101-1.m68kmint.rpm
   	
   First step.  The special option `--justdb' can be used in
   install or erase mode to tell rpm not to alter the file system
   but only change the database.  In other word: This command
   fakes a real installation, no file is really installed but rpm
   now thinks that they are present.
   
   	# rpm -e smail
   
   This will erase the smail package again.  You will see a lot of
   error messages because there are many files that cannot be
   removed because they simply weren't present.  It will also fail
   on your mail spool directory because it is not empty (good
   for you because that will prevent rpm from deleting unsent
   mail).  Finally:
   
   	# rpm -ivh smail-3.2.0.101-1.m68kmint.rpm
   
   Now the installation proceeds normally because all disturbing
   links had previously been removed.
   
1.3 Truncated File Names In Error Messages

Q: I install a (binary or source) rpm and get an error message like
   "unpacking of archive failed on file /us: cpio: chown failed -
   file not found".  What's the story?  Why does rpm 
   complain about a file named "/us", does that exist?
   
A: This error message unfortunately is not very helpful, the name
   of the file that caused the failure is truncated, looks like
   "/us", or "/bi".  It is probably a bug in rpm, but the problem
   needs to get tracked down.  There was not yet time to fix it.
   
   So how do you find out which file caused the error?  Suppose you
   are trying to install the file "foobar-1.0-1.m68kmint.rpm".  You
   would then run the command 
   
   	rpm -qpl foobar-1.0-1.m68kmint.rpm
   
   This will produce a list of all files that get installed by this
   binary rpm in exactly the same order that rpm will really install
   them on your system.  You should then compare that list with
   the current state of your filesystem.  The first file that is
   not present (or maybe the next one or the one before it) probably 
   caused the error.
   
   If the package is very big, that procedure may become difficult.
   You can reduce your trouble with this little helper:
   
   	# rpm -qpl foobar-1.0-1.m68kmint.rpm >/tmp/foobar.list
   	# sed 's,.*,ls -ld &,g' </tmp/foobar.list >/tmp/foobar.check
   	# sh /tmp/foobar.check
   
   What does that do?  The rpm invocation will write the file
   list of the package into the file `/tmp/foobar.list' which will 
   look like:
   
   	/bin/foobar
   	/usr/doc/foobar-1.0/README
   	/usr/man/man1/foobar
   
   The next command (`sed ...') will convert that file list into
   a little shell script `/tmp/foobar.list', that will list all
   the corresponding files on your system in long format (and please
   note the option `-d' to the `ls' command which will prevent
   that the contents of directories gets listed.
   
   You finally fun the script (invoked by your shell `sh').  All
   errors produced by `ls' will indicate that the file does not
   (yet) exist.

1.4 Does Not Appear To Be An RPM Package

Q: I get the above error message when installing an rpm.

A: Sometimes you also see something like `Wrong File Type'.
   Generally you have specified a wrong file name.  Check the 
   spelling and also see the section `Pitfalls With Wildcards'.

2. Popular Mistakes And Useful Hints
====================================

2.1 Error That Package Is Not Installed Although It Is

Q: Check the spelling!  A popular mistake is this one:

	# rpm -ivh foobar-1.0-1.m68kmint.rpm
	foobar                      ###################################
	# rpm -qi foobar-1.0-1.m68kmint.rpm
	package foobar-1.0-1.m68kmint.rpm is not installed

   Hm, I just installed it.  What happens?  You have to distinguish
   carefully between modes in which rpm expects the name of a file
   and modes in which it expects the name of a package.  When you
   install or update a package you have to specify a file name; the
   same applies in query mode if you give the option `-p', resp.
   `--package'.  In our above example the name of the file was
   `foobar-1.0-1.m68kmint.rpm' but remember that the name of the
   file actually doesn't matter for rpm.  You may install from
   an 8+3 file system in which case the name would have been
   truncated to `FOOBAR-1.0-1', or you may even rename it
   to `windoze-95-0.m68kmint.rpm'.  The program will always 
   autodetect whether it is an rpm file, and which package should
   get installed.
   
   In all other modes you have to specify the name of the package,
   optionally followed by the version and release number.  All these
   calls would provide you the information that you wanted to get:
   
   	# rpm -qi foobar
   	# rpm -qi foobar-1.0
   	# rpm -qi foobar-1.0-1
   
2.2 Pitfalls On Wildcards

Q: I hate typing and often use wildcards like `*'.  But that often
   doesn't work with rpm.  Why is the program so stupid?
   
A: It's not rpm that is stupid.  It is rather you or your shell.
   There are several situations that are likely to produce that
   error:
   
   a)
   
	# rpm -ivh foobar*
	foobar                      ###################################
	# rpm -qi foobar*
	package foobar-1.0-1.m68kmint.rpm is not installed

   You installed the package alright, your shell expanded the
   string `foobar*' into the full file name `foobar-1.0-1.m68kmint.rpm'
   and that file got installed.  But in the second command you stepped
   into a trap, to rpm it looks as if you have typed:

	# rpm -qi foobar-1.0-1.m68kmint.rpm
	package foobar-1.0-1.m68kmint.rpm is not installed

   See the answer to question 2.1, in query mode rpm expects the name
   of a package and not the filename.  But you were dreaming and
   added the wildcard `*' again, and so rpm saw `foobar-1.0-1.m68kmint.rpm'
   and not `foobar'.
   
   b) Some shells don't expand wildcards if there are files with more
   than 30 characters in the same directory.  The names of rpm package
   files often exceed this limit and in this case your only chance is
   to type in the file name literally (or run the `ls' command and cut
   and paste it).  For the same reason your desktop will maybe come
   up with an error when you try to display directories containing
   rpm files.
   
   NOTE: It is sufficient that one single file name exceeds that
   30 character limit, not necessary the name of the file you want
   to use.  If one file name is too long you cannot use wildcards
   in that directory anymore. This is a failure of an old MiNT-Lib
   that is linked with your shell. To fix this problem install a
   new recompiled shell like the bash package.

2.3 Database Backups

Q: How reliable is rpm?

A: Quite reliable.  But it also relies on the reliability of your 
   file system and your mass store media.
   
   The more packages you install and manage via rpm, the more the
   rpm database will become the heart of your system.  If it is
   corrupted or deleted there is no way to regenerate it.
   
   The database resides in the directory `/var/lib/rpm', other
   important files are in `/usr/lib/rpm'.  You should make
   regular (preferably daily) backups of these directories.  If yo
   happen to overwrite the program file `/bin/rpm' you can 
   simply replace it.  If the database is corrupted you have lost.

2.4 Finding Packages For Download

Q: I have heard so much about GNU autoconf, automake and libtool.
   I want to install them but I cannot find them on my favorite
   server although I positively know that they are available.
   Where are they?
   
A: RPM decides whether a binary rpm is suitable for your system by
   the architecture and the operating system the package has been
   built for.  Our architecture is `m68kmint', other examples are
   `i386', `sparc', `parisc' and so on.
   
   Now take Linux (Linux is a popular MiNT clone available for various
   hardware platforms) as an example.  Linux is available for 
   many hardware architectures but there are some packages that 
   are actually hardware independent.  Generally that are packages
   that either contain only scripts or maybe packages that only
   create a certain directory structure on your file system.
   These are so-called `noarch' (i. e. no-architecture) packages.
   
   Well, if you find arcitecture dependent packages in
   `/usr/src/sparemint/RPMS/m68kmint' you will find noarch packages
   in `/usr/src/sparemint/RPMS/noarch'.  Have a look there!

2.5 Installing Noarch Packages

Q: My friend has installed `hypercgi-3.25-1.noarch.rpm' on her
   NetBSD box.  MiNT's rpm will refuse to install it although I know
   that it only contains architecture-independent files, namely
   Perl scripts.

A: The package is architecture-independent but not OS-independent.
   If the operating system of your friend is NetBSD the package
   is suitable for NetBSD on an intel architecture, an m68k
   architecture, ... But it is always built for the operating 
   system NetBSD and not for MiNT.  Currently there is no way
   to create `noarch_and_noos' rpm packages.
   
   You can probably still install the package with
   
   	# rpm -ivh --ignoreos-3.25-1.noarch.rpm
   
   thus preventing rpm from verifying the operating system but
   that's at your own risk.  The clean way would be to rebuild
   the package from the sources which will automatically create
   a noarch rpm for the MiNT operating system.

   That os-dependency currently does not make much sense for
   MiNT because it is an OS that will only run on one hardware
   architecture.  But imagine that there would be a MiNT port
   to the Power-PC, then it maybe would make sense.

3. Other Problems Not Related To RPM
====================================

3.1 Spurious Errors

Q: Under certain circumstances, especially if a program has some
   really hard work to do, the program crashes with a memory
   violation, bus error or segmentation fault.  Most of the 
   time the errors are always the same but sometimes they change.
   First it is a bus error and next time it is a segmentation
   fault.  What can I do?

A: It is very likely that there is a stack overrun in that program.
   The stack is a memory region attached to every process.  This
   region is completely at the process' disposition, i. e. it 
   normally does not check if there is still memory availble
   or not.  Unfortunately if the stack is getting too small the
   program will start to write into itself and that will produce
   these funny results.
   
   If you have memory protection enabled this is only a nuisance,
   but without memory protection this can cause serious errors,
   because other processes may be affected by this misbehavior.
   
   To reduce the risks you should really run your system with
   memory protection enabled.  To avoid a certain crash you 
   should fix the stack size of the program (see next question).

3.2 Setting Stack Size Fails

Q: When I try to fix or read the stack size of a program (funny,
   only new programs seem to be affected) the printstk/fixstk
   program fails with `no symbol table' or `symbol _stksize 
   not found'.  Do Sparemint packages forbid this?

A: All binary programs from Sparemint use a slightly different
   program format.  One of its many advantages is that it does
   not need a symbol table attached to the program in order to
   fix the stack size.
   
   Install the mintbin package from your Sparemint server and
   use the program `stack' instead, `stack --help' will print
   a usage summary (usually enough).
   
   For example if you want to fix the stack size of your `sed'
   program to 256 kBytes, you would type
   
   	stack --fix=256k /usr/bin/sed
   
   The `stack' program will also work on old programs.  If you
   run it with no option (here: without `--fix=256k') it reports
   the current stack size.  In other words: It is a full
   replacement for printstk/fixstk.

3.3 Recommended Stack Sizes

Q: What is the recommended stack size for programs?

A: You cannot generally answer that question.  Maybe some facts help:
   The default stack size of programs used to be 8 kBytes and has
   been changed to 16 kBytes lately.
   
   Compilers generally need very, very much stack.  512 kBytes is
   probably a good value but not always sufficient.
   
   All programs that use regular expressions need at least 32 kBytes
   of stack, often 64 kBytes.
   
   There are programs that require a ridiculously large stack.  For
   example `cmp' from the fileutils absolutely needs at least
   256 k, the `kaffe' virtual machine is reported to require a
   stack of 2 MBytes.
   
   You have to find the optimum value yourself.  But don't forget
   that the larger you make the stack, the more memory the program
   consumes.  Often it is useful to only temporarily change the
   stack size.  For example `sed' from Sparemint has currently
   a default stack size of 256 kBytes which should be sufficient
   for most usages.  But if you are very short of RAM in a particular
   situation you can temporarily reduce the stack to 128 k or
   maybe even 64 k.  In other situations even the default of 256 k
   is maybe not enough.  You can then temporarily augment the
   stack too higher values.
   
   Note: If a program from Sparemint permanently crashes because
   of stack overruns you should report that.  Unless your usage
   is extreme in some way, this is considered a bug of the
   package.

4. Documentation
================

4.1 Maximum RPM

Q: I want to exploit all features of rpm.  Is there a book available?

A: Yes, `Maximum RPM' by Edward C. Bailey.  It is available for free
   download from ftp://ftp.rpm.org/ (or http://www.rpm.org/) or you
   can purchase it in most computer book stores.  The electronic 
   version is available in various formats, including PostScript,
   PDF, LaTeX and plain text.

   Unfortunately, at the time of this writing (August 1999) this
   excellent book is a little outdated because it was written for
   rpm version 2.5.x and rpm 3.x differs significantly from that.
   A new edition is in work, watch out.
   
4.2 RPM-HOWTO

Q: Why is the RPM-HOWTO not part of rpm?

A: Because it is part of the Linux-HOWTO package.  You either have
   to install Linux-HOWTO or you will also find that particular 
   HOWTO in the bootstrapping archive `rpm-<version>.m68kmint.tar.gz'
   of your favorite Sparemint mirror site.

4.3 Manpage

Q: Is there a manual page available for RPM?

A: Yes, why do you ask?  You will find manual pages for rpm and
   rpm2cpio in section 8 (`/usr/share/man/man8').

4.4 The System Behind the Command Line Options

Q: Is it really necessary that rpm has so many command line options?

A: Dunno.  Some of them have two forms for convenience (for example
   `-e' and `--erase' are the same) and the rest is easy to remember
   if you get a feeling for the system behind it.  RPM knows
   several modes of operation and the correct mode is selected by
   the first option letter:
   
   o query mode, -q, --query
     get information about packages, package files or installed
     files
   o verify mode, -V, -y, --verify
     verify packages (i. e. check if your installation is still
     complete and consistent)
   o install mode, -i, --install
     install packages (surprise, surprise)
   o upgrade mode, -U, --upgrade
     yep, exactly
   o erase mode, -e, --erase
     erase (i. e. uninstall) packages
   o build mode, -b, (-t)
     build binary packages from a previously installed source rpm's 
     spec file (-b) or from a tarball (-t)
   o key (encryption) mode, -K
     signing packages or checking signatures with gpg (or pgp)
     
  Some general options like `--rebuild' or `--initdb' which are rarely
  used don't fit into this scheme.
  
  Have a look at a few examples.  First take the query mode.  What
  could you possibly query?  What about this:
  
  o a package file, -p
  o an installed package, default, no special option
  o a file that you don't know (want to get information about), -f
  o all packages, -a
  
  Finally, what do you want to know?
  
  o the exact name, version and release, default, no option
  o general Information, -i
  o a list of files that belong to the package, -l
  
  Note that you can group short options together, one single dash (`-')
  in front of them is sufficient.  You want to see which files belong
  to the package `mintnet'?
  
  	# rpm -ql mintnet
  
  Which package does the file `/usr/sbin/checkerr' belong to?
  
  	# rpm -qf /usr/sbin/checkerr
  
  If you want to see which other files belong to that package 
  (a file List) you can even do:
  
  	# rpm -qfl /usr/sbin/checkerr
  	
  What is the package `libungif' good for?
  
  	# rpm -qi libungif
  
  In short terms: First specify the desired mode and then add more
  options that detail your plans.
  
4.5 Getting An Overview

Q: How do I get a quick reference to rpm?

A: Type `rpm --help'.  Attention, this is quick but the list is long.
   You may want to redirect it to a file (`rpm --help >/tmp/rpmhelp')
   or pipe it through a pages (`rpm --help | less' or `rpm --help | more').
  
5. Building Packages From Sources
=================================
   
5.1 Getting Started

Q: Building packages looks complicated.  How can I get an insight?

A: RTFM! But beware, the documentation may be a little outdated.

   Don't reinvent the wheel, steal from existing sources!  If you
   want to build a standard package which is available for Linux
   but not for MiNT you should download the corresponding source
   rpm from ftp://ftp.redhat.com/ the ftp server of Redhat Software.
   First positive effect is that you have current sources, second
   the necessary patches for Linux are very often useful or even
   needed for MiNT, too, and third, you already have a skeleton
   for the spec file.
   
   In all other cases you should download an example source rpm
   from your favorite Sparemint mirror and try to understand it
   (uhm, `it' is usually the spec file).
   
   If you install a source rpm you will find the following files:
   
   o The spec file (the `command file' for the build process
     controlled by rpm) in /usr/src/sparemint/SPECS.
   
   o All sources (usually as g'zipped tar balls, beware, there
     may be more than one tarball) including all necessary patches
     in the directory /usr/src/sparemint/SOURCES.
   
   You will then have to edit the spec file to tailor it to your
   needs.  For complicated packages that are likely to cause trouble
   you will probably need several steps, but finally you run
   the command `rpm -ba' on your new spec file which will create
   a new source rpm in /usr/src/sparemint/SRPMS and the corresponding
   binary rpm in /usr/src/sparemint/RPMS/m68kmint (or noarch for
   architecture-independent packages).
   
   Try to understand existing spec files and watch what is happening
   while you do `rpm -ba' on packages that are known to work.  Last
   but not least, have a glimpse at the rpm docs.

5.2 Design Guide
    
Q: Is there a style-guide for Sparemint rpms?

A: Not really.  Sparemint is not slavery, you are free in your decisions.
   However, it is probably useful if you follow a couple of rules:
   
   o If you want to contribute your package to the Sparemint project
     two lines in the spec file are mandatory:
     
     	Vendor: Sparemint
     	Packager: Johnnie Helpful <johnnie(at)brave.men.org>
     
     Large parts of the Sparemint sites are auto-generated by scripts
     and rely on this information.  Before you start work on a new
     rpm you should also contact the maintainers of the project in
     order to avoid that two people work on the same package.
   
   o Be accurate with version and release numbers!
   
     If you contribute a new package to Sparemint or contribute 
     the first release for a particular version of that software,
     always start with 
     
     	Release: 1
     
     Even if you have downloaded the package from Redhat's and you
     have modified nothing or only little things you should use
     Sparemint's own release numbering (at least you have changed
     the vendor and package lines).
    
     If you get spec files from other sources (mostly Redhat's),
     please delete existing %changelog sections.  If you continue
     work on a Sparemint package (no matter if you take it over
     from somebody else or from yourself), be sure to _add_ a
     %changelog entry.  Document your modifications, even if you
     only got an update of the sources or linked it against new
     library versions.  Installers have a right to know what has
     been changed.
   
   o Other mandatory lines in the spec file:
   
   	Summary: The ever popular `catch the urinal cake' game
   	Package: uc
   	Version: 1.2.3
   	Release: 1
   	Source: ftp://filthy.games.com/pub/arcade/%{name}-%{version}.tar.gz
   	Patch0: uc-mintcnf.patch
   	Patch1: uc-unfilth.patch
   	Buildroot: /var/tmp/%{name}-root
     	Vendor: Sparemint
     	Packager: Johnnie Helpful <johnnie(at)brave.men.org>
	Summary(de): So ein Quatsch, Wiener Schnitzel, ve haf vays to make you talk
	
     The `Source' and `Patch' lines are mandatory because rpm requires
     them.  A summary is helpful, the name of the package is also
     required by rpm, version and release number alike.  Except for
     rare cases you should also use the buildroot feature.
     
     If you try to make your package relocatable (see bash for an
     example) the better!  Currently this is not a must, most 
     recent packages are not yet relocatable, mainly because we
     didn't have the time to do it.
     
     If English is not your native language, try to translate 
     the summary into your native language (see `Summary(de)').
     
     Try to use macros (`%{name}', or `%{version}') whenever possible.
     This make your package less error-prone (for example when the
     version number changes).
   
   o Necessary sections:
     
     Sparemint packages should always have a %description section.
     Again, if English is not your native language, try to translate
     the english description.  Please do not use the Atari charset
     when doing translations: For western European languages use
     ISO-8859-1 (aka Latin-1), for other languages, the corresponding
     ISO-font, other commonly used fonts or a 7-bit ASCII-transliteration.
     
     We have nothing against the Atari charset but its usage is 
     deprecated because it will cause a lot of problems with other
     software.
   
   o Source consistency
     Do not modify the original sources.  Supply a patch for _every_
     modification you apply.  It should be possible that people
     rebuild the package only from your spec file and patches if 
     they already have the sources.
   
   o Save space and compress files.  Files in GNU info format should
     always be compressed using gzip.  Also try to install as many
     manual pages as possible.  There is a pitfall for that: For 
     example the manual page /usr/man/man8/runq.8 actually only
     includes /usr/man/man8/smail.8 (because runq and smail are
     one and the same program).  This is usually done by something
     like
     
     	.so smail.8
     
     or 
     	
     	"\
     	.so smail.8
    
    in the manpage runq(8).  However, the manual reader for MiNT
    will fail to find the smail manpage if it is gzipped, because
    it's name is `smail.8.gz' then.  See the spec files for 
    libtiff (one-line version) or smail (two-line version) for
    a fix.
    
    If you install large documentation files or sample configs
    you should also consider to compress them, especially if
    the programs that are usually used to process or read these
    files are known to be smart enough to handle compressed 
    input.

    o Noarch packages.  If your package only contains scripts
      or text files, html, config files ... build a noarch
      package (i. e. add a line `BuildArchitectures: noarch').
      The distinction between noarch packages and architecture
      dependent packages isn't very useful for MiNT at the
      moment but people will expect it that way.
    
5.3 Directory Structure - FHS compliancy

Q: Should I assume BSDish or SysVish directory structures?

A: The File system Hierarchy Standard (originally for Linux, but
   now also observed by BSD systems) should be obeyed, see 
   http://www.fhs.com/ for details.  If Sparemint follows this
   standard we will reduce portability problems.  In doubt rather
   follow the Linux manner of installing files because this will
   make it easier for the end user to get help (it's hard enough
   getting help if you mention that you have an Atari; it's not
   necessary to confuse even more with non-standard directory
   structures).
   
   Summary of FHS: Executables (and libraries) that are necessary 
   for booting the system should go into `/bin', `/sbin' and
   `/lib', not `/usr/bin', `/usr/sbin' or `/usr/lib'.  Don't
   install any binaries (especially networking stuff) in
   `/usr/etc', it belongs into `(/usr)/sbin'.  Architecture
   and system independent stuff should go into `/usr/share', not
   `/usr/lib' or the like.  In doubt have a look at modern
   MiNT clones like Linux or BSD, resp. commercial systems.
   
   It is currently not really necessary for MiNT to distinguish
   between `/bin' and `/usr/bin' (same for `sbin', `lib', ...)
   but if you build packages you should keep in mind that
   people really have to distinct directories for `/bin' and
   `/usr/bin' and don't symlink the directories.  Your package
   should also work on these systems and it is probably wiser
   if you separate the directories on your private system
   too.

5.4 GEM Applications

Q: What about GEM stuff and rpm?

A: No problem, go ahead!  However you should also adhere to a certain
   directory structure that is adapted from the FHS rules for 
   X Windows System (an AES clone for MiNT clones).
   
   Please install libraries and headers in
   
   	/usr/GEM/lib
   	/usr/GEM/include
   
   GEM libraries are often not very strict about namings and 
   this will avoid conflicts.  Furthermore it makes it easier
   to keep an overview of your development stuff.
   
   No, by default GEM applications should not be installed in
   
   	/usr/GEM/bin or
   	/usr/GEM/sbin
   	
   except for programs that can run stand-alone, i. e. that don't
   need any non-program files for proper operation in the same
   directory.  Most GEM apps at least need a .rsc file and that
   would fill up that directory with junk (and prevents a 
   comfortable uninstallation without the help of rpm).  Create
   a subdirectory under `/opt' instead.  For example the popular
   editor QED by Christian Felsch should go into /opt/qed.
   
   We don't consider it useful to further subdivide that directory
   into `/opt/editors', `/opt/telecomm', `/opt/midi' and so
   on.  Most desktops have much better means to group software.
   
   Please don't expect the directory `/usr/multitos' any longer
   (neither `/usr/mint').  This is now `/boot/mint' and `/boot'
   should be a symbolic link to the boot partition (i. e. the
   program `/boot/auto/mint.prg' resp. `/boot/auto/mintnp.prg'
   is the kernel).
   
   One specialty are help files in ST-Guide format.  ST-Guide
   is a very helpful desk accessory commonly used by GEM
   applications written by Holger Weets.  Unfortunately it is 
   non-free software but Sparemint supports it nevertheless.  
   If you want to automatically install help files in ST-Guide 
   format you should install them in `/usr/GEM/stguide' and 
   you can also expect the tools `hcp.ttp', `stool.tos' etc. 
   to reside there (in fact the user may make `/usr/GEM/stguide' 
   a symbolic link to the actual location; we haven't chosen 
   the most common location `/boot/st-guide' resp. `/boot/help' 
   because we want to avoid forcing people to install large 
   sets of files on the boot drive).  However, you should 
   treat failures on the use of hcp or stool as non-fatal
   errors.  Example:

	%post
	/usr/GEM/stguide/hcp.ttp $RPM_BUILD_DIR/%{name}-%{version} \
	    myapp.stg && \
	  /usr/GEM/stguide/stool.tos >/dev/null 2>&1 || :
	
	%postun
	rm -f /usr/GEM/stguide/myapp.hyp /usr/GEM/stguide/myapp.ref
	/usr/GEM/stguide/stool.tos >/dev/null 2>&1 || :
	
   Nonetheless: If you have the choice, use more versatile
   formats than ST-Guide for your help files.  SGML and
   derivates are probably the future, GNU Texinfo can also be
   converted into lots of other formats (including ST-Guide).

   Generally speaking, questions concerning handling of GEM
   specific stuff has not yet been positively decided.  Feel
   free to make own suggestions or improvements to the rules
   outlined here.
   
5.5 Device Drivers And File Systems

Q: How is such stuff treated?

A: A preliminary approach looks like this:

   1) Drivers should only be installed in 
   
   	/usr/lib/mint/drivers
      
      This directory is kind of a depot for device drivers and
      file systems (and network interfaces).
   
   2) Always add a line 
   
   	Requires: mint-util
      
      to spec files that build or install drivers.  Read the manpage
      drivers(8) and add post-install and post-uninstall sections
      to your spec file:
      
      	%post
      	/sbin/drivers --install mydev && /sbin/drivers --update
      	
      	%postun
      	/sbin/drivers --uninstall mydev

   3) Be careful with /sbin/drivers, do not install too many drivers.
      For example the package `mintnet' comes with the socket device
      driver `sockdev.xdd' and a whole lot of other drivers and 
      network interfaces.  But there is no way for the packager to
      decide which drivers and interfaces are really useful for
      the end-user.  If she installs MiNTNet she will definitely
      want to install or update `sockdev.xdd', so this driver can
      be safely installed.  But for the rest, who knows?
      
      You can always do `/sbin/drivers --update' in the %post
      section, that will cause drivers that /are/ already activated
      to get updated (i. e. new drivers in /usr/lib/mint/drivers
      will overwrite old ones of the same name in /boot/mint).
      
      NOTE: The /sbin/drivers program will have trouble if the
      name of the driver does not fit into the 8+3 restriction
      of old file systems (and /boot will reside on such a
      file system).  Please avoid using names that break this 
      limit!
      
To be continued ...
