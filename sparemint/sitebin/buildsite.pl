#! /usr/bin/perl
# buildsite.pl - Rebuild html versions of Sparemint files.
# Copyright (C) 1999-2001 Guido Flohr <guido@imperia.net>.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
# USA.  */

# $Id: buildsite.pl,v 2.7 2008/02/06 07:12:25 fna Exp $

# TODO/FIXME/BUGS:
# - Use mktemp/rename when rewriting files to avoid race conditions
#   while being mirrored.
# - Why cannot we sum up the number of packages and the sizes in
#   the group list?
# - Design a resource description format schema and embed RDF in
#   the html files (see http://www.w3.org/TR/).

use strict;
my ($rpm, $Revision, $Version,
    $base_dir, $sparemint_dir, $rpms_dir, 
    $rpms_m68kmint_dir, $rpms_noarch_dir,
    $srpms_dir, $sitebin_dir, $html_dir, $pkg_dir, $images_dir,
    $misc_dir, $ntw_dir, $ntm_dir, $expired_dir, $prog_name,
    $verbose, $now, $one_week, $one_month, 
    $package_list, $authors_list,
    %srpms, %rpms, %authors, %packages, %ntw_links, %ntm_links, %htmls,
    $packages_header, $authors_header,
    $generated
    );

##########################################################################
# Configuration stuff, change these variables to your needs.
##########################################################################
$rpm = "rpm";        # Default: in $PATH.

##########################################################################
# Version control.
##########################################################################
$Revision = q ($Revision: 2.7 $ );
$Version;

##########################################################################
# External modules used.
##########################################################################
use File::Basename;
use File::stat;
use POSIX;
use IO::Handle;
use Getopt::Long;

##########################################################################
# Global variables.
##########################################################################
# Directories.
$base_dir;
$sparemint_dir;
$rpms_dir;
$rpms_m68kmint_dir;
$rpms_noarch_dir;
$srpms_dir;
$sitebin_dir;
$html_dir;
$pkg_dir;
$images_dir;
$misc_dir;
$ntw_dir;
$ntm_dir;
$expired_dir;

$prog_name;
$verbose = 0;
$now = time;
$one_week = 7 * 24 * 60 * 60;
$one_month = 30 * 24 * 60 * 60;  # Accurate enough.

# File names.
$package_list;
$authors_list;

##########################################################################
# File fragments.
##########################################################################
$packages_header = <<EOF;
# This file contains a list of packages that are already available for
# Sparemint or are planned to be made available in the future.
# Format is as follows: 
#
# 	Package|Status|Maintainer|New Maintainer
#
# See the file \`AUTHORS' in the same directory for the meaning of
# the short tags in the \`Maintainer' column.
#
# The \`Status' is one of the following:
#
#	a - assigned
#	    The package is already assigned to a new maintainer but
#	    not yet ready.
#	o - orphaned
#	    The package is ready but currently orphaned.  If you
#           are interested in taking over the maintainance please
#           contact the Sparemint people.
#       r - released
#           The current maintainer has a released version ready
#           for download.
#	w - waiting
#	    There is no binary package available.
#
# An empty status is equivalent to status \`waiting'.

EOF

$authors_header = <<EOF;
# This file is a list of the people that are currently maintaining
# Sparemint packages.  Format is as follows:
#
# 	Tag|Full Name|E-Mail|Homepage

EOF

# Global hashs.
%srpms;
%rpms;
%authors;
%packages;
%ntw_links;
%ntm_links;
%htmls;

# Subroutines.
sub setup;
sub find_me;
sub read_authors;
sub read_all_srpms;
sub read_all_rpms;
sub read_rpms;
sub expire_rpms;
sub read_delete_list;
sub delete_stale;
sub canonicalize_address;
sub read_packages;
sub write_ftp_files;
sub format_number;
sub write_authors_html;
sub write_group_packages;
sub write_alpha_packages;
sub write_todos;
sub by_group;

# Main program.
setup;
find_me;
read_delete_list;
read_authors;
read_packages;
read_all_srpms;
read_all_rpms;
expire_rpms;
write_ftp_files;
write_authors_html;
write_alpha_packages;
write_alpha_packages "ntw";
write_alpha_packages "ntm";
write_group_packages;
write_todos;
delete_stale;

sub setup {
  my ($opt_verbose, $opt_help, $opt_version);

  STDERR->autoflush (1);
  STDOUT->autoflush (1);
  
  $Version = $Revision;
  $Version =~ s,.*Revision: ,,g;
  $Version =~ s, .,,g;
  
  # NLS nuisances.  Avoid spurious non-English strings in output.
  POSIX::setlocale (&POSIX::LC_ALL, "POSIX");
  $ENV{'LANG'} = $ENV{'LANGUAGE'} = $ENV{'LC_ALL'} = "POSIX";
 
  GetOptions ("--verbose" => \$opt_verbose,
	      "-v" =>        \$opt_verbose, 
              "--help" =>    \$opt_help,
	      "-h" =>        \$opt_help,
              "--version" => \$opt_version,
	      "-V" =>        \$opt_version) 
      or die "Try `$0 --help' for more information";

  if ($opt_help) {
    print <<EOF;
Usage: $0 [ OPTIONS ]
Consistency check the Sparemint files and build the html pages. Options:

  --help, -h               Display this help page and exit
  --verbose, -v            Print diagnostic output on stdout.
  --version, -V            Print version information and exit

Report bugs to Guido Flohr <gufl0000\@stud.uni-sb.de>.
EOF

    exit 0;
  }

  if ($opt_version) {
    print <<EOF;
$0 (Sparemint) Revision $Version
Copyright (C) 1999 Guido Flohr (gufl0000\@stud.uni-sb.de)
This program is free software; you may redistribute it under the terms of
the GNU General Public License.  This program has absolutely no warranty.
EOF
    exit 0;
  }
  
  if ($opt_verbose) {
    $verbose = 1;
  }

  $generated = "Generated automatically " 
      . gmtime () . " UTC by $prog_name Revision $Version.\n";
}

# Find ourselves so that we have a well-known directory structure.
sub find_me {
  my $program_invocation_name = $0;
  $prog_name = basename $program_invocation_name;
  my $here;
  
  if ($prog_name eq $program_invocation_name) {
    $here = "./";
  } else {
    my $l1 = length ($prog_name);
    my $l2 = length ($program_invocation_name);
    $here = substr $program_invocation_name, 0, $l2 - $l1;
  }
  
  # Now cd into that directory and construct the directory names.
  chdir $here . "/../..";
  $base_dir = `pwd`;
  chomp $base_dir;
  $sparemint_dir = $base_dir . "/sparemint";
  $rpms_dir = $sparemint_dir . "/RPMS";
  $rpms_m68kmint_dir = $rpms_dir . "/m68kmint";
  $rpms_noarch_dir = $rpms_dir . "/noarch";
  $srpms_dir = $sparemint_dir . "/SRPMS";
  $sitebin_dir = $sparemint_dir . "/sitebin";
  $html_dir = $sparemint_dir . "/html";
  $pkg_dir = $html_dir . "/packages";
  $images_dir = $html_dir . "/images";
  $misc_dir = $sparemint_dir . "/misc";
  $ntw_dir = $sparemint_dir . "/NEW-THIS-WEEK";
  $ntm_dir = $sparemint_dir . "/NEW-THIS-MONTH";
  $expired_dir = $sparemint_dir . "/expired";
  
  $package_list = $sitebin_dir . "/PACKAGES.in";
  $authors_list = $sitebin_dir . "/AUTHORS.in";

  # Check if all directories exist and have the correct permissions.
  my $errors = "no";
  my %permissions = (
    #$base_dir => 0755,
    $sparemint_dir => 0755,
    $rpms_dir => 0755,
    $rpms_m68kmint_dir => 0755,
    $rpms_noarch_dir => 0755,
    $srpms_dir => 0755,
    $sitebin_dir => 0755,
    $html_dir => 0755,
    $pkg_dir => 0755,
    $images_dir => 0755,
    $misc_dir => 0755,
    $ntw_dir => 0755,
    $ntm_dir => 0755,
    $expired_dir => 0755,
  );
  
  foreach my $dir (keys %permissions) {
    print "checking for $dir ...\n" if $verbose;
    
    if (my $st = stat ($dir)) {
      # Check if it is a directory.
      if (S_ISDIR ($st->mode)) {
        if (($st->mode & 0xfff) != $permissions{$dir}) {
          $errors = "yes";
          print STDERR "$prog_name: error: wrong permissions for directory $dir.\n";
          printf STDERR "(Please run \`chmod %o $dir' to fix that.)\n",
                        $permissions{$dir};
        }
      } else {
        $errors = "yes";
        print STDERR "$prog_name: error: $dir is not a directory.\n";
      }
    } else {
      $errors = "yes";
      print STDERR "$prog_name: error: directory $dir does not exist.\n";
    }
  }
  
  # Check if the files that we absolutely need exist.  If not create
  # them.
  my %filelist = (
    $package_list => "$packages_header",
    $authors_list => "$authors_header",
  );  
  
  foreach my $file (keys %filelist) {
    print "checking for $file ...\n" if $verbose;
    my $contents = $filelist{$file};
    my $bits = 0644;

    if (my $st = stat ($file)) {
      # Check if it is a regular file.
      if (S_ISREG ($st->mode)) {
        if (($st->mode & 0xfff) != $bits) {
          $errors = "yes";
          print STDERR <<EOF;
$prog_name: error: wrong permissions for file $file.
EOF
          printf STDERR "(Please run \`chmod %o $file' to fix that.)\n",
                        $bits;
        }
      } else {
        $errors = "yes";
        print STDERR "$prog_name: error: $file is not a regular file.\n";
      }
    } else {
      # Create the file.
      open HANDLE, ">$file" or die "$prog_name: error: cannot create $file: $!";
      print HANDLE $contents;
      close HANDLE or die "$prog_name: error: cannot close $file: $!\n";
      print STDERR "$prog_name: created missing file $file\n";
    }
  }
  
  die "$prog_name: unrecoverable errors encountered" unless $errors eq "no";
}

# Read authors file.
sub read_authors {
  print "parsing $authors_list\n" if $verbose;
  open AUTHORS, $authors_list 
      or die "$prog_name: can't open $authors_list for reading: $!";
  
  AUTHOR: while (<AUTHORS>) {
    chomp;
    s,#.*$,,g;
    next AUTHOR if /^[ \t]*$/;
    my ($tag, $fullname, $email, $http) = split /\|/;
    $authors{$tag}{name} = $fullname;
    $authors{$tag}{email} = $email;
    $authors{$tag}{email_html} = $email;
    $authors{$tag}{email_html} =~ s/@/(at)/g;
    $authors{$tag}{email_encrypted} = "";
    my $mailto = "mailto:";
    for (my $i = 0; $i < length($mailto); $i++) {
      $authors{$tag}{email_encrypted} .= chr(ord(substr($mailto,$i,1))+1);
    }
    for (my $i = 0; $i < length($email); $i++) {
      $authors{$tag}{email_encrypted} .= chr(ord(substr($email,$i,1))+1);
    }
    $_ = $http;
    unless (/^\s$/) {
      $authors{$tag}{http} = $http;
    }
  }
  
  close AUTHORS;
}

# Read all source rpms.
sub read_all_srpms
{
  my $size;
  my $mtime;

  opendir DIR, $srpms_dir or die "$prog_name: can't opendir $srpms_dir: $!";
  my @files = grep { ! /^\./ && -f "$srpms_dir/$_" } readdir(DIR);
  closedir DIR;
  
  SRPM: foreach my $file (@files) {
    my $fullname = $srpms_dir . "/" . $file;
    print "querying $file ...\n" if $verbose;
    open RPM, "$rpm -qp --queryformat '%{name} %{version} %{release}' $fullname |"
      or die "$prog_name: error: rpm -qp $fullname failed";
    my $query = <RPM>;
    my ($package, $version, $release) = split / /, $query;
    close RPM;
    my $rc = 0xffff & $?;
    
    if ($rc & 0xff00) {
      die "$prog_name: error: $rpm -qp $fullname failed: $!";
    } elsif ($rc > 0x80) {
      $rc >>= 8;
      print STDERR "$prog_name: warning: skipping $fullname\n";
      next SRPM;
    } elsif ($rc != 0) {
      print STDERR "$prog_name: warning: $rpm -qp $fullname: ";
      if ($rc & 0x80) {
        $rc &= ~0x80;
	print STDERR "core dump from ";
      } else {
        print STDERR "killed by ";
      }
      print STDERR "signal $rc\n";
      
      next SRPM;	
    }

    chmod 0444, $fullname or die "cannot chmod 0444 $fullname: $!";
      
    if ("$file" ne "$package" . "-$version" . "-$release.src.rpm") {
      print STDERR "$prog_name: warning: skipping $file\n";
      print STDERR "(Please rename $file to $package"
        . "-$version" . "-$release.src.rpm\n";
      next SRPM;
    }
    
    if (my $st = stat ($fullname)) {
      $size = $st->size;
      $mtime = $st->mtime;

      if ($now < $st->mtime + $one_week) {
        my $name = "$package-$version-$release.src.rpm";
	if ($ntw_links{$name} != 1) {
	    my $link = "../SRPMS/$name";
	    my $target = "$ntw_dir/$name";
	    symlink $link, $target
		or die "$prog_name: error: cannot symlink $link to $target: $!\n";
	    print "symlink $link to $target\n" if $verbose;
	} else {
	    delete $ntw_links{$name};
	}
      }
      if ($now < $st->mtime + $one_month) {
        my $name = "$package-$version-$release.src.rpm";
	if ($ntm_links{$name} != 1) {
	    my $link = "../SRPMS/$name";
	    my $target = "$ntm_dir/$name";
	    symlink $link, $target
		or die "$prog_name: error: cannot symlink $link to $target: $!\n";
	    print "symlink $link to $target\n" if $verbose;
	} else {
	    delete $ntm_links{$name};
	}
      }
    } else {
      die "$prog_name: error: cannot stat $fullname: $!\n";
    }
    
    # OK, the file is fine, save the information.
    $srpms{$file}{package} = $package;
    $srpms{$file}{version} = $version;
    $srpms{$file}{release} = $release;
    $srpms{$file}{size} = $size;
    $srpms{$file}{mtime} = $mtime;
  }
}

# Get a list of files to be deleted unless used.
sub read_delete_list
{
    print "reading links in $ntw_dir\n" if $verbose;
    opendir DIR, $ntw_dir or die "$prog_name: can't opendir $ntw_dir: $!";
    my @files = grep { ! /^\./ && -f "$ntw_dir/$_" } readdir(DIR);
    closedir DIR;
    
  NTW: foreach my $file (@files) {
      $ntw_links{$file} = 1;
  }

    print "reading links in $ntm_dir\n" if $verbose;
    opendir DIR, $ntm_dir or die "$prog_name: can't opendir $ntm_dir: $!";
    my @files = grep { ! /^\./ && -f "$ntm_dir/$_" } readdir(DIR);
    closedir DIR;
    
  NTM: foreach my $file (@files) {
      $ntm_links{$file} = 1;
  }

    print "reading html files in $pkg_dir\n" if $verbose;
    opendir DIR, $pkg_dir or die "$prog_name: can't opendir $pkg_dir: $!";
    my @files = grep { ! /^\./ && -f "$pkg_dir/$_" } readdir(DIR);
    closedir DIR;
    
  HTML: foreach my $file (@files) {
      if (my $st = stat ("$pkg_dir/$file")) {
	  $htmls{$file}{mtime} = $st->mtime;
      } else {
	  die "$prog_name cannot stat $pkg_dir/$file: $!";
      }
  }
}

# Delete stale files.
sub delete_stale {
    foreach my $file (keys %ntw_links) {
	print "deleting $ntw_dir/$file\n" if $verbose;
	unlink $ntw_dir . "/" . $file;
    }
    foreach my $file (keys %ntm_links) {
	print "deleting $ntm_dir/$file\n" if $verbose;
	unlink $ntm_dir . "/" . $file;
    }
    foreach my $file (keys %htmls) {
	print "deleting $html_dir/packages/$file\n" if $verbose;
	unlink $html_dir . "/packages" . "/" . $file;
    }
}

# Read all binary rpms.
sub read_all_rpms
{
  read_rpms "m68kmint";
  read_rpms "noarch";
  
  # Check if there are lone source rpms left.
  foreach (keys %srpms) {
    if ($srpms{$_}{used} != 1) {
        print STDERR "$prog_name: warning: no binary rpms for $srpms_dir/$_\n";
    }
  }
}

sub read_rpms
{
    my $arch = $_[0];
    my $dir = $rpms_dir . "/$arch";
    my ($packagesize, $packagedate);
    my $queryformat = ""
      . "%{name}|%{version}|%{release}|%{arch}|"
      . "%{prefixes}|%{vendor}|%{buildtime}|%{group}|%{size}|"
      . "%{sourcerpm}|%{license}|%{packager}|"
      . "%{url}|%{os}|"
      . "%{changelogname}|%{changelogtime}|%{changelogtext}|%{serial}|"
      . "%{summary}|%{description}|";
  
  opendir DIR, $dir or die "$prog_name: can't opendir $dir: $!";
  my @files = grep { ! /^\./ && -f "$dir/$_" } readdir(DIR);
  closedir DIR;
  
  BINARY_RPM: foreach my $file (@files) {
    my $fullname = $dir . "/" . $file;
    print "querying $file ...\n" if $verbose;
    open RPM, "$rpm -qp --queryformat '$queryformat' $fullname |"
      or die "$prog_name: error: rpm -qp $fullname failed";
    my $query = "";
    while (<RPM>) {
      s,\&,&amp;,g;
      s,<,&lt;,g;
      s,>,&gt;,g;
      # To be continued.
      s,^\s*$,<P>\n,g;
      s,\n,<BR>,g;
      $query .= $_;
    }
    close RPM;
    
    print "querying filelist for $file ...\n" if $verbose;
    open RPM, "$rpm -qpvl $fullname |"
      or die "$prog_name: error: rpm -qpvl $fullname failed";
    my $rpm_filelist = "<PRE>\n";
    while (<RPM>) {
      $rpm_filelist .= $_
    }
    close RPM;
    $rpm_filelist .= "</PRE>\n";

    # Chmod to 0444.
    chmod 0444, $fullname or die "cannot chmod 0444 $fullname: $!";
    
    my ($package, $version, $release, $buildarch, $prefixes, $vendor,
        $buildtime, $group, $size, $sourcerpm, $license, $rpmpackager,
        $url, $os, $changelogname, $changelogtime, $changelogtext, 
        $serial, $summary, $description) = split /\|/, $query; 
    my $rc = 0xffff & $?;
    
    if ($rc & 0xff00) {
      die "$prog_name: error: $rpm -qp $fullname failed: $!";
    } elsif ($rc > 0x80) {
      $rc >>= 8;
      print STDERR "$prog_name: warning: skipping $fullname\n";
      next BINARY_RPM;
    } elsif ($rc != 0) {
      print STDERR "$prog_name: warning: $rpm -qp $fullname: ";
      if ($rc & 0x80) {
        $rc &= ~0x80;
	print STDERR "core dump from ";
      } else {
        print STDERR "killed by ";
      }
      print STDERR "signal $rc\n";
      next BINARY_RPM;	
    }

    open RPM, "$rpm -qp --provides $fullname |"
      or die "$prog_name: error: rpm -qp --provides $fullname failed";
    my $provides = "";
    while (<RPM>) {
      chomp;
      $provides .= "  <LI>$_<BR>\n";
    }
    close RPM;
    
    if ($rc & 0xff00) {
      die "$prog_name: error: $rpm -qp --provides $fullname failed: $!\n";
    } elsif ($rc != 0) {
      print STDERR "$prog_name: warning: $rpm -qp --provides $fullname: ";
      if ($rc & 0x80) {
        $rc &= ~0x80;
	print STDERR "core dump from ";
      } else {
        print STDERR "killed by ";
      }
      print STDERR "signal $rc\n";
    }

    open RPM, "$rpm -qp --requires $fullname |"
      or die "$prog_name: error: rpm -qp --requires $fullname failed";
    my $requires = "";
    while (<RPM>) {
      chomp;
      $requires .= "  <LI>$_<BR>\n";
    }
    close RPM;
    
    if ($rc & 0xff00) {
      die "$prog_name: error: $rpm -qp --requires $fullname failed: $!";
    } elsif ($rc != 0) {
      print STDERR "$prog_name: warning: $rpm -qp --requires $fullname: ";
      if ($rc & 0x80) {
        $rc &= ~0x80;
	print STDERR "core dump from ";
      } else {
        print STDERR "killed by ";
      }
      print STDERR "signal $rc\n";
    }

    open RPM, "$rpm -qp --conflicts $fullname |"
      or die "$prog_name: error: rpm -qp --conflicts $fullname failed";
    my $conflicts = "";
    while (<RPM>) {
      chomp;
      $conflicts .= "  <LI>$_<BR>\n";
    }
    close RPM;
    
    if ($rc & 0xff00) {
      die "$prog_name: error: $rpm -qp --conflicts $fullname failed: $!";
    } elsif ($rc != 0) {
      print STDERR "$prog_name: warning: $rpm -qp --conflics $fullname: ";
      if ($rc & 0x80) {
        $rc &= ~0x80;
	print STDERR "core dump from ";
      } else {
        print STDERR "killed by ";
      }
      print STDERR "signal $rc\n";
    }

    if ($serial ne "(none)") {
      if ("$file" ne "$package" . "-$version" . "-$release" 
                     . ".$arch" . ".rpm") {
        print STDERR "$prog_name: warning: skipping $file\n";
        print STDERR "(Please rename $file to $package"
          . "-$version" . "-$release.$arch.rpm\n";
        next BINARY_RPM;
      }
    }
    
    # Check correct architecture.
    if ($arch ne $buildarch) {
      print STDERR "$prog_name: warning: $file: not for architecture $arch\n";
    }
    
    # Check for vendor Sparemint.
    if ($vendor ne "Sparemint") {
      print STDERR "$prog_name: warning: $file: vendor ($vendor) is not Sparemint\n";
    }
    
    # FIXME: What was the original if-clause good for?
    # Check if we know the packager.
    #if ($packager eq "(none)") {
    #  print STDERR "$prog_name: warning: $file: no packager specified\n";
    #} else {
      my ($packager, undef) = canonicalize_address ($rpmpackager, $fullname);
    #}
    
    # Check for a group.
    if ($group eq "(none)") {
      print STDERR "$prog_name: warning: $file: no group specified\n";
    }
    
    # Check if we have a corresponding source rpm.
    if (!$srpms{$sourcerpm}) {
      print STDERR "$prog_name: warning: $file: source rpm $sourcerpm is missing\n";
    } else {
      $srpms{$sourcerpm}{used} = 1;
    }
    
    if (my $st = stat ($fullname)) {
	$packagesize = $st->size;
	$packagedate = $st->mtime;
	if ($now < $packagedate + $one_week) {
	    my $pfullname = "$package-$version-$release.$arch.rpm";
	    if ($ntw_links{$pfullname} != 1) {
		my $link = "../RPMS/$arch/$pfullname";
		my $target = "$ntw_dir/$pfullname";
		symlink $link, $target
		    or die "$prog_name: error: cannot symlink $link to $target: $!\n";
		print "symlink $link to $target\n" if $verbose;
	    } else {
		delete $ntw_links{$pfullname};
	    }
	}
	if ($now < $packagedate + $one_month) {
	    my $pfullname = "$package-$version-$release.$arch.rpm";
	    if ($ntm_links{$pfullname} != 1) {
		my $link = "../RPMS/$arch/$pfullname";
		my $target = "$ntm_dir/$pfullname";
		symlink $link, $target
		    or die "$prog_name: error: cannot symlink $link to $target: $!\n";
		print "symlink $link to $target\n" if $verbose;
	    } else {
		delete $ntm_links{$pfullname};
	    }
	}
    } else {
	die "$prog_name: error: cannot stat $fullname: $!\n";
    }

    # OK, the file is fine, save the information.
    $rpms{$file}{package} = $package;
    $rpms{$file}{version} = $version;
    $rpms{$file}{release} = $release;
    $rpms{$file}{size} = $size;
    $rpms{$file}{packagesize} = $packagesize;
    $rpms{$file}{packagedate} = $packagedate;
    if ($now < $packagedate + $one_week) {
      $rpms{$file}{ntw} = 1;
    }
    if ($now < $packagedate + $one_month) {
      $rpms{$file}{ntm} = 1;
    }
    $rpms{$file}{arch} = $arch;
    $rpms{$file}{srpm} = $sourcerpm;
    $rpms{$file}{summary} = $summary;
    $rpms{$file}{group} = $group;
    $rpms{$file}{packager} = $packager;
    $rpms{$file}{rpmpackager} = $rpmpackager;
    $rpms{$file}{vendor} = $vendor;
    $rpms{$file}{description} = $description;
    $rpms{$file}{changelogname} = $changelogname;
    $rpms{$file}{changelogtime} = $changelogtime;
    $rpms{$file}{changelogtext} = $changelogtext;
    $rpms{$file}{buildtime} = $buildtime;
    $rpms{$file}{relocations} = $prefixes;
    $rpms{$file}{requires} = $requires;
    $rpms{$file}{provides} = $provides;
    $rpms{$file}{conflicts} = $conflicts;
    $rpms{$file}{os} = $os;
    $rpms{$file}{url} = $url;
    $rpms{$file}{license} = $license;
    $rpms{$file}{filelist} = $rpm_filelist;
  }
}

sub expire_rpms 
{
    print "Moving expired source rpms if any\n" if $verbose;

    my $last_package = "";
    my $last_file = "";
    foreach my $file (sort { uc ($a) cmp uc ($b) } keys %srpms) {
	if ($srpms{$file}{package} eq $last_package) {
	    # Duplicate, move the older one.
	    my $older = $file;
	    my $newer = $last_file;
	    if ($srpms{$older}{mtime} > $srpms{$newer}{mtime}) {
		$older = $last_file;
		$newer = $file;
	    }
	    print "$prog_name: Moving expired file $older to $expired_dir\n";
	    rename $srpms_dir . "/" . $older, $expired_dir . "/" . $older;
	    unlink $ntw_dir . "/" . $older;
	    unlink $ntm_dir . "/" . $older;
	    $file = $newer;
	    delete $srpms{$older};
	}
	$last_file = $file;
	$last_package = $srpms{$file}{package};
    }

    print "Moving expired binary rpms if any\n" if $verbose;

    $last_package = "";
    $last_file = "";
    foreach my $file (sort { uc ($a) cmp uc ($b) } keys %rpms) {
	if ($rpms{$file}{package} eq $last_package) {
	    # Duplicate, move the older one.
	    my $older = $file;
	    my $newer = $last_file;
	    if ($rpms{$older}{packagedate} > $rpms{$newer}{packagedate}) {
		$older = $last_file;
		$newer = $file;
	    }
	    print "$prog_name: Moving expired file $older to $expired_dir\n";
	    my $arch = $rpms{$older}{arch};
	    rename $rpms_dir . "/" . $arch . "/" . $older,  $expired_dir . "/" . $older;
	    unlink $ntw_dir . "/" . $older;
	    unlink $ntm_dir . "/" . $older;
	    # FIXME: Remove link if already written.
	    $file = $newer;
	    delete $rpms{$older};
	}
	$last_file = $file;
	$last_package = $rpms{$file}{package};
    }
}

sub canonicalize_address {
  my ($parse, $filename) = @_;

  my ($fullname, $address);

  $_ = $parse;
  # Remove trailing and leading whitespace.
  s,^\s+,,g;
  s,\s$,,g;
  
  my $address_pattern = ".+\@.+\..+";
    
  # We support three different formats for mail addresses:
  #   Bill Clinton <president@whitehouse.gov>
  #   Bill Clinton (president@whitehouse.gov)
  #   president@whitehouse.gov (Bill Clinton)
  
  if (/(.*)\s*&lt;($address_pattern)&gt;$/) {
    $fullname = $1;
    $address = $2;
  } elsif (/(.*)\s*\(($address_pattern)\)$/) {
    $fullname = $1;
    $address = $2;
  } elsif (/($address_pattern)\s*\((.*\))$/) {
    $fullname = $2;
    $address = $1;
  } else {
    print STDERR "$prog_name: cannot parse email address \`$_' in $filename\n";
    return ("unknown");
  }
  
  $address =~ s,\s,,g;
  $fullname =~ s,^\s+,,g;
  $fullname =~ s,\s+$,,g;
  $fullname =~ s,\s+, ,g;
  
  return ($fullname, $address);
}

# Read packages file.
sub read_packages {
  print "parsing $package_list\n" if $verbose;
  open PACKAGE, $package_list 
      or die "$prog_name: can't open $package_list for reading: $!";
  my $lineno = 0;
  
  PACKAGE: while (<PACKAGE>) {
    $lineno++;
    chomp;
    s,#.*$,,g;
    next PACKAGE if /^[ \t]*$/;
    my ($package, $status, $tag, $newtag) = split /\|/;
    
    next PACKAGE if (!$package);
    
    $packages{$package}{tag} = $tag;
    $packages{$package}{status} = $status;
    if ($status eq "a") {
      $packages{$package}{long_status} = "assigned";
    } elsif ($status eq "o") {
      $packages{$package}{long_status} = "orphaned";
    } elsif ($status eq "r") {
      $packages{$package}{long_status} = "released";
    } elsif ($status eq "w") {
      $packages{$package}{long_status} = "waiting";
    } elsif (!$status or $status eq "") {
      $packages{$package}{status} = "w";
      $packages{$package}{long_status} = "waiting";
    } else {
      print STDERR "$prog_name: $package_list: $lineno: warning: unknown status \`$status'\n";
      $packages{$package}{long_status} = "unknown";
    }
    $packages{$package}{newtag} = $newtag;
    
    # Check if we know the tag.
    if ($tag && !$authors{$tag}) {
      print STDERR "$prog_name: $package_list: $lineno: warning: unknown maintainer tag \`$tag'\n";
      print STDERR "$prog_name: (Please edit $authors_list to fix that.)\n";
    }
    if ($newtag && !$authors{$newtag}) {
      print STDERR "$prog_name: $package_list: $lineno: warning: unknown new maintainer tag \`$tag'\n";
      print STDERR "$prog_name: (Please edit $authors_list to fix that.)\n";
    }
    
    # If assigned we need a new maintainer.
    if ($status eq "a" and !$newtag) {
      print STDERR "$prog_name: $package_list: $lineno: package $package: warning: when assigned you have to specify a new maintainer\n";
    }
    
  }
  
  close PACKAGE;
}

# Write files intended for ftp users.
sub write_ftp_files {
  my $file = $sparemint_dir . "/AUTHORS";
  print "creating $file\n" if $verbose;
  open AUTHORS, ">$file"
      or die "$prog_name: can't open $file for writing: $!";
  
  print AUTHORS "The following people have built software packages for Sparemint:\n\n";
  
  foreach my $author (sort keys %authors) {
    print AUTHORS "$authors{$author}{name} <$authors{$author}{email_html}>\n";
  }

  print AUTHORS $generated;  
  close AUTHORS or die "$prog_name: cannot close  $file: $!";

  $file = $sparemint_dir . "/PACKAGES";
  my $pkglist = $sparemint_dir . "/pkglist";

  print "creating $file\n" if $verbose;
  open PACKAGES, ">$file"
      or die "$prog_name: can't open $file for writing: $!";
  print "creating $pkglist\n" if $verbose;
  open PKGLIST, ">$pkglist"
      or die "$prog_name: can't open $pkglist for writing: $!";
  
  print PACKAGES "These packages are currently available for Sparemint:\n\n";
  
  foreach my $package (sort { uc ($a) cmp uc ($b) } keys %rpms) {
    my $number;
    my $date = gmtime $rpms{$package}{packagedate};
    print PKGLIST <<EOF;
$rpms{$package}{package}-$rpms{$package}{version}-$rpms{$package}{release}
EOF

    print PACKAGES "$rpms{$package}{package}, version $rpms{$package}{version}, "
                   . "release $rpms{$package}{release}\n";
    print PACKAGES "Group: $rpms{$package}{group}\n";
    print PACKAGES "Summary: $rpms{$package}{summary}\n";
    print PACKAGES "Available since: $date UTC\n";
    print PACKAGES "Download: RPMS/$rpms{$package}{arch}/$package\n";
    $number = format_number $rpms{$package}{packagesize};
    print PACKAGES "Package size: $number bytes\n";
    $number = format_number $rpms{$package}{size};
    print PACKAGES "Installed size: $number bytes\n";
    print PACKAGES "Sources: SRPMS/$rpms{$package}{srpm}\n";
    print PACKAGES "\n";
  }
  
  $generated = gmtime;
  $generated = "Generated automatically " 
      . $generated . " UTC by $prog_name Revision $Version.\n";
  
  print PACKAGES $generated;  
  close PACKAGES or die "$prog_name: cannot close  $file: $!";
  close PKGLIST or die "$prog_name: cannot close $pkglist: $!";
}

sub format_number {
  my $number = $_[0];
  my $formatted;
  my $next_group;
  
  $next_group = $number % 1000;
  $number = int ($number / 1000);
  if ($number > 0) {
    if ($next_group < 10) {
      $next_group = "00". $next_group;
    } elsif ($next_group < 100) {
      $next_group = "0" . $next_group;
    }
  }
  $formatted = $next_group;
  while ($number > 0) {
    $next_group = $number % 1000;
    $number = int ($number / 1000);
    if ($number > 0) {
      if ($next_group < 10) {
        $next_group = "00". $next_group;
      } elsif ($next_group < 100) {
        $next_group = "0" . $next_group;
      }
    }
    $formatted = $next_group . ",$formatted";
  }
  
  return $formatted;
}

# Write AUTHORS file for http users.
sub write_authors_html {
  #print "removing $html_dir/*.html\n" if $verbose;
  #`rm -f $html_dir/*.html`;
  #print "removing $pkg_dir/*.html\n" if $verbose;
  #`rm -f $pkg_dir/*.html`;
  
  my $file = $html_dir . "/AUTHORS.html";
  print "creating $file\n" if $verbose;
  open AUTHORS, ">$file"
      or die "$prog_name: can't open $file for writing: $!";

  print AUTHORS <<EOF;
<HTML>

<HEAD>
  <TITLE>Sparemint Authors</TITLE>
  <LINK rel="stylesheet" href="../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>

<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../index.html">Home</a>
<img src="images/leaf-bullet.gif"> <a href="../info.html">Information</a>
<img src="images/leaf-bullet.gif"> <a href="../NEWS.html">News</a>
<img src="images/leaf-bullet.gif"> <a href="../development.html">Development</a>
<img src="images/leaf-bullet.gif"> <a href="../download.html">Download</a>
<img src="images/leaf-bullet.gif"> <a href="../mirrors.html">Mirrors</a></h4>
<br>

   <H2>Sparemint Authors</H2>
   The following people are contributing to the Sparemint project by
   maintaining software packages:
   <UL>
EOF

  foreach my $author (sort keys %authors) {
    print AUTHORS <<EOF;
     <LI>$authors{$author}{name}
     <UL>
       <LI>Mail: <A HREF="javascript:linkto_decode_mt('$authors{$author}{email_encrypted}');">
           $authors{$author}{email_html}</A>
EOF
    if ($authors{$author}{http}) {
      print AUTHORS <<EOF;
       <LI>URL: <A HREF="$authors{$author}{http}">
           $authors{$author}{http}</A>
EOF
    }
    print AUTHORS "    </UL>\n";
  }
  
  print AUTHORS "  </UL>\n";

  $generated = gmtime;
  $generated = "<SMALL>Generated automatically " 
      . $generated . " UTC by "
      . "<A HREF=\"sitebin/buildsite.html\">$prog_name</A>"
      . " Revision $Version.</SMALL>\n";
  
  print AUTHORS "$generated\n";

  close AUTHORS or die "$prog_name: cannot close  $file: $!";
}

my $total_size = 0;
my $total_installed_size = 0;
my $number_of_packages = 0;

# Write alphabetical package list.
sub write_alpha_packages {
  my $file;
  my $what = $_[0];
  my $silent = 1;
  my $written_packages = 0;
  
  if ($what eq "ntw") {
    $file = $html_dir . "/new-this-week.html";
  } elsif ($what eq "ntm") {
    $file = $html_dir . "/new-this-month.html";
  } else {
    $file = $html_dir . "/packages.html";
  }
  
  print "creating $file\n" if $verbose;
  open PACKAGES, ">$file"
      or die "$prog_name: can't open $file for writing: $!";

  if ($what eq "ntw") {
    my $since = gmtime ($now - $one_week);
    print PACKAGES <<EOF;
<HTML>

<HEAD>
  <TITLE>This Week's New Sparemint Packages</TITLE>
  <LINK rel="stylesheet" href="../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>

<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../index.html">Home</a>
<img src="images/leaf-bullet.gif"> <a href="../info.html">Information</a>
<img src="images/leaf-bullet.gif"> <a href="../NEWS.html">News</a>
<img src="images/leaf-bullet.gif"> <a href="../development.html">Development</a>
<img src="images/leaf-bullet.gif"> <a href="../download.html">Download</a>
<img src="images/leaf-bullet.gif"> <a href="../mirrors.html">Mirrors</a></h4>
<br>
    <H2>This Week's New Sparemint Packages</H2>
    These packages have been uploaded to the Sparemint server during the last
    week (since $since UTC):   
EOF
  } elsif ($what eq "ntm") {
    my $since = gmtime ($now - $one_month);
    print PACKAGES <<EOF;
<HTML>

<HEAD>
  <TITLE>This Month's New Sparemint Packages</TITLE>
  <LINK rel="stylesheet" href="../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>

<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../index.html">Home</a>
<img src="images/leaf-bullet.gif"> <a href="../info.html">Information</a>
<img src="images/leaf-bullet.gif"> <a href="../NEWS.html">News</a>
<img src="images/leaf-bullet.gif"> <a href="../development.html">Development</a>
<img src="images/leaf-bullet.gif"> <a href="../download.html">Download</a>
<img src="images/leaf-bullet.gif"> <a href="../mirrors.html">Mirrors</a></h4>
<br>
    <H2>This Month's New Sparemint Packages</H2>
    These packages have been uploaded to the Sparemint server during the last
    month (since $since UTC):
EOF
  } else {  
    $silent = 0;
    print PACKAGES <<EOF;
<HTML>

<HEAD>
  <TITLE>Sparemint Packages Alphabetically Sorted</TITLE>
  <LINK rel="stylesheet" href="../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>

<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../index.html">Home</a>
<img src="images/leaf-bullet.gif"> <a href="../info.html">Information</a>
<img src="images/leaf-bullet.gif"> <a href="../NEWS.html">News</a>
<img src="images/leaf-bullet.gif"> <a href="../development.html">Development</a>
<img src="images/leaf-bullet.gif"> <a href="../download.html">Download</a>
<img src="images/leaf-bullet.gif"> <a href="../mirrors.html">Mirrors</a></h4>
<br>
    <H2>Sparemint Packages Alphabetically Sorted</H2>
    These packages are currently available for Sparemint:
EOF
  }
  
  print PACKAGES <<EOF;
    <P>  
    <DIV ALIGN=center>
      <H3>Quick alphabetical index:</H3>
EOF

  my $last;
  PACKAGE: foreach my $package (sort { uc ($a) cmp uc ($b) } keys %rpms) {
    next PACKAGE if $what eq "ntw" and !$rpms{$package}{ntw};
    next PACKAGE if $what eq "ntm" and !$rpms{$package}{ntm};
    
    $written_packages++;

    my $current = substr $package, 0, 1;
    if (uc ($current) ne uc ($last)) {
      $last = uc ($current);
      print PACKAGES "    <A HREF=#$last>$last</A>\n";
    }
  }
  
  print PACKAGES <<EOF; 
      </DIV>
   <UL>
   
EOF

  $last = "\000";
  PACKAGE: foreach my $package (sort { uc ($a) cmp uc ($b) } keys %rpms) {
    next PACKAGE if $what eq "ntw" and !$rpms{$package}{ntw};
    next PACKAGE if $what eq "ntm" and !$rpms{$package}{ntm};
    
    my $number;
    my $name = $rpms{$package}{package};
    my $group = $rpms{$package}{group};
    my $summary = $rpms{$package}{summary};
    my $packagesize = $rpms{$package}{packagesize};
    my $version = $rpms{$package}{version};
    my $release = $rpms{$package}{release};
    my $current = substr $package, 0, 1;
    my $description = $rpms{$package}{description};
    my $vendor = $rpms{$package}{vendor};
    my $fpackagesize = format_number $packagesize;
    my $fsize = format_number $rpms{$package}{size};
    my $rpm_filelist = $rpms{$package}{filelist};

    if (uc ($current) ne uc ($last)) {
      $last = uc ($current);
      print PACKAGES "    <A NAME=$last><H2>$last</H2></A>\n";
    }

    my $new1 = "";
    my $new2 = "";
    if (!$silent) {
      if ($rpms{$package}{ntw}) {
        $new1 = "<IMG SRC=\"images/new_this_week.jpeg\" ALT=\"New this week!\" ALIGN=middle WIDTH=160 HEIGHT=58>";
        $new2 = "<IMG SRC=\"../images/new_this_week.jpeg\" ALT=\"New this week!\" ALIGN=middle WIDTH=160 HEIGHT=58>";
      } elsif ($rpms{$package}{ntm}) {
        $new1 = "<IMG SRC=\"images/new_this_month.jpeg\" ALT=\"New this month!\" ALIGN=middle WIDTH=160 HEIGHT=58>";
        $new2 = "<IMG SRC=\"../images/new_this_month.jpeg\" ALT=\"New this month!\" ALIGN=middle WIDTH=160 HEIGHT=58>";
      }
    }
    
    print PACKAGES "    <LI>$name $new1\n";
    print PACKAGES "      <DL>\n";
    print PACKAGES "        <DD>Summary: $summary\n";
    $number = format_number $packagesize;
    print PACKAGES <<EOF;
        <DD><A HREF="packages/$name.html">Information</A><BR>
            <A HREF="../RPMS/$rpms{$package}{arch}/$package">Download</A>
              $number bytes
      </DL>
EOF

    next PACKAGE if $silent;  	# If silent the rest is not needed.
    				# The detailed file has already been
    				# written.

    $number_of_packages++;
    $total_size += $packagesize;
    $total_installed_size += $rpms{$package}{size};

    # Check if we have the package listed in PACKAGES.in.
    my $maintainer;
    my $tag = 0;
    unless ($packages{$name}{tag}) {
      if (!$silent) {
        print STDERR "$prog_name: warning: package $name not listed in $package_list\n";
      }
    } else {
      $packages{$name}{used} = 1;
      $tag = $packages{$name}{tag};
      # Check if the maintainer is correct.
      $maintainer = $authors{$tag}{name};
      if ($maintainer ne $rpms{$package}{packager}) {
        if (!$silent) {
          print STDERR "$prog_name: warning: $package_list says that $maintainer maintains $package, not $rpms{$package}{packager}\n";
        }
      }
    }
    
    # Check if we have a source rpm.
    my $sourcerpm = "";
    my $fparen_srcsize;
    if ($rpms{$package}{srpm}) {
      $sourcerpm = $rpms{$package}{srpm};
      if ($sourcerpm) {
        $fparen_srcsize = format_number $srpms{$sourcerpm}{size};
        $fparen_srcsize = " (" . $fparen_srcsize . " bytes)";
      } else {
        if (!$silent) {
          print STDERR "$prog_name: warning: no source rpm for $package\n";
        }
      }
    }

    # Write a complete changelog line.
    my $changelog = "";
    if ($rpms{$package}{changelogname} ne "(none)") {
      $changelog = $rpms{$package}{changelogtext};
      my $fdate = gmtime $rpms{$package}{changelogtime};
      $changelog =~ s,\n,<BR>\n,g;
      $changelog = "<LI>Last change: $rpms{$package}{changelogname} $fdate UTC<BR>\n"
                 . $changelog;
    }
    
    my $buildtime = gmtime $rpms{$package}{buildtime};
    my $uploadtime = gmtime $rpms{$package}{packagedate};
    my $size = format_number $rpms{$package}{size};
    my $relocations = $rpms{$package}{relocations};
    
    # If the file already exists then check if it needs rewriting.
    my $info_html = "$pkg_dir/$name.html";
    if ($htmls{"$name.html"}{mtime} > 0) {
	my $html_mtime = $htmls{"$name.html"}{mtime};
	delete $htmls{"$name.html"};
	if ($rpms{$package}{packagedate} < $html_mtime) {
	    next PACKAGE;
	}
    }

    delete $htmls{"$name.html"};

    # Write all provides.
    my $provides = $rpms{$package}{provides};
    if ($provides) {
      $provides = "<LI>Provides:<UL>\n" . $provides . "</UL>\n"; 
    }
            
    # Write all requires.
    my $requires = $rpms{$package}{requires};
    if ($requires) {
      $requires = "<LI>Requires:<UL>\n" . $requires . "</UL>\n"; 
    }
            
    # Write all conflicts.
    my $conflicts = $rpms{$package}{conflicts};
    if ($conflicts) {
      $conflicts = "<LI>Conflicts:<UL>\n" . $conflicts . "</UL>\n"; 
    }
            
    my $full_packager;
    if ($tag eq "") {
      $full_packager = $rpms{$package}{rpmpackager};
    } else {
      if ($authors{$tag}{http} eq "") {
        $full_packager="$authors{$tag}{name}"
          . " (<A HREF=\"javascript:linkto_decode_mt(\'$authors{$tag}{email_encrypted}\');\">$authors{$tag}{email_html}</A>)";
      } else {
        $full_packager = "<A HREF=\"$authors{$tag}{http}\">$authors{$tag}{name}</A>"
          . " (<A HREF=\"javascript:linkto_decode_mt(\'$authors{$tag}{email_encrypted}\');\">$authors{$tag}{email_html}</A>)";
      }
    }

    my $os = $rpms{$package}{os};
    my $license = $rpms{$package}{license};
    my $url = $rpms{$package}{url};
    unless ($url eq "(none)") {
	$url = "<LI>URL: <A HREF=\"$url\">$url</A><BR>";
    } else {
	$url = "";
    }
    
    if ($group eq "(none)") {
      $group = "";
    } else {
      $group = "<LI>Group: <A HREF=\"../groups.html#$group\">$group</A>";
    }

    # Write the info html document.
    print "creating $pkg_dir/" . "$name.html\n" if $verbose;
    open INFO, ">$pkg_dir/$name.html"
      or die "$prog_name: cannot create $pkg_dir/$name.html: $!";

    print INFO <<EOF;
<HTML>

<HEAD>
  <TITLE>Sparemint - $name, version $version, release $release</TITLE>
  <LINK rel="stylesheet" href="../../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>
  
<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="./../images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../../index.html">Home</a>
<img src="./../images/leaf-bullet.gif"> <a href="../../info.html">Information</a>
<img src="./../images/leaf-bullet.gif"> <a href="../../NEWS.html">News</a>
<img src="./../images/leaf-bullet.gif"> <a href="../../../development.html">Development</a>
<img src="./../images/leaf-bullet.gif"> <a href="../../download.html">Download</a>
<img src="./../images/leaf-bullet.gif"> <a href="../../mirrors.html">Mirrors</a></h4>
<br>

    <H2>$name</H2>

<UL> 
<LI>Summary: $summary<BR>
$url
<LI>Version: $version<BR>
<LI>Release: $release<BR>
$group
<LI>License: $license</BR>
<LI>Installation size: $size bytes<BR>
<LI>Operating system: $os<BR>
$provides
$requires
$conflicts
<LI>Relocations: $relocations<BR>
<LI>Build date: $buildtime UTC<BR>
<LI>Upload date: $uploadtime UTC<BR>
<LI>Packager: $full_packager<BR>
<LI>Vendor: $vendor<BR>
<LI>Sources: <A HREF="../../SRPMS/$sourcerpm">$sourcerpm</A> $fparen_srcsize<BR>
$changelog
<LI>Description:<BR>
$description
<LI>Files:<BR>
$rpm_filelist
</UL>
<P>
<H2><A HREF="../../RPMS/$rpms{$package}{arch}/$package">Download</A></H2> ($fpackagesize bytes)
<DIV ALIGN=right>
  <A HREF="../../index.html"><IMG SRC="../images/top.gif" ALT="Top" BORDER=0></A>
  <A HREF="../packages.html"><IMG SRC="../images/a-z.gif" ALT="A-Z" BORDER=0></A>
</DIV>
EOF

    $generated = gmtime;
    $generated = "<SMALL>Generated automatically " 
        . $generated . " UTC by "
        . "<A HREF=\"../../sitebin/buildsite.html\">$prog_name</A>"
        . " Revision $Version.</SMALL>\n";
  
    print INFO "<HR>\n$generated\n";
    close INFO or die "$prog_name: cannot close  $pkg_dir/$name.html: $!";
  }
  
  $number_of_packages = format_number $number_of_packages;
  $total_size = format_number $total_size;
  $total_installed_size = format_number $total_installed_size;
  
  print PACKAGES "  </UL>\n";

  if (!$silent) {
    print PACKAGES <<EOF;
  
    <HR>
    $total_size bytes in $number_of_packages binary packages.  Installation
    size totals to $total_installed_size bytes.
EOF
  }
  if ($what eq "ntw" and $written_packages == 0) {
    print PACKAGES "  <EM>No packages uploaded this week!</EM>\n";
  } elsif ($what eq "ntm" and $written_packages == 0) {
    print PACKAGES "  <EM>No packages uploaded this month!</EM>\n";
  } 
  
  $generated = gmtime;
  $generated = "<SMALL>Generated automatically " 
      . $generated . " UTC by "
      . "<A HREF=\"../sitebin/buildsite.html\">$prog_name</A>"
      . " Revision $Version.</SMALL>\n";
  
  print PACKAGES <<EOF;
<DIV ALIGN=right>
  <A HREF="../index.html"><IMG SRC="images/top.gif" ALT="Top" BORDER=0></A>
</DIV>
    <HR>
    $generated
EOF

  close PACKAGES or die "$prog_name: cannot close  $file: $!";
  
  # Some additional checks for PACKAGES.in.
  my $package;
  foreach $package (keys %packages) {
    # Orphaned and released packages must exist.
    my $status = $packages{$package}{status};
    my $long_status = $packages{$package}{status};
    
    if (($status eq "r" or $status eq "o") and !$packages{$package}{used}) {
      print STDERR "$prog_name: warning: $package has status \`$long_status' in $package_list but no binary rpm\n";
    } elsif (($status ne "r" and $status ne "o" and $status ne "a") and $packages{$package}{used}) {
      print STDERR "$prog_name: warning: $package has status \`$long_status' in $package_list but there is already a binary rpm\n";
    }    
  }  
}

# Write package list sorted by group.
sub write_group_packages {
  my $file = $html_dir . "/groups.html";
  
  print "creating $file\n" if $verbose;
  open PACKAGES, ">$file"
      or die "$prog_name: can't open $file for writing: $!";
  
  print PACKAGES <<EOF;
<HTML>

<HEAD>
  <TITLE>Sparemint Packages Sorted By Group</TITLE>
  <LINK rel="stylesheet" href="../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>

<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../index.html">Home</a>
<img src="images/leaf-bullet.gif"> <a href="../info.html">Information</a>
<img src="images/leaf-bullet.gif"> <a href="../NEWS.html">News</a>
<img src="images/leaf-bullet.gif"> <a href="../development.html">Development</a>
<img src="images/leaf-bullet.gif"> <a href="../download.html">Download</a>
<img src="images/leaf-bullet.gif"> <a href="../mirrors.html">Mirrors</a></h4>
<br>
    <H2>Sparemint Sorted by Group</H2>
    The Sparemint packages belong to one of these groups:
   
    <P>
EOF

  my $last = "";;
  foreach my $package (sort by_group keys %rpms) {
    my $current = $rpms{$package}{group};
    if (uc ($current) ne uc ($last)) {
      $last = $current;
      print PACKAGES "    <A HREF=#$last>$last</A><BR>\n";
    }
  }
  
  $last = "";
  foreach my $package (sort by_group keys %rpms) {
    my $group = $rpms{$package}{group};
    my $number;
    my $name = $rpms{$package}{package};
    my $summary = $rpms{$package}{summary};
    my $packagesize = $rpms{$package}{packagesize};
    my $version = $rpms{$package}{version};
    my $release = $rpms{$package}{release};
    my $fpackagesize = format_number $packagesize;
    my $fsize = format_number $rpms{$package}{size};
    
    if (uc ($group) ne uc ($last)) {
      if ($last) {
        print PACKAGES "  </UL>\n";
      }
      $last = $group;
      print PACKAGES "    <A NAME=$last><H2>$last</H2></A>\n";
      print PACKAGES "  <UL>\n";
    }
    
    my $new = "";
    if ($rpms{$package}{ntw}) {
      $new = "<IMG SRC=\"images/new_this_week.jpeg\" ALT=\"New this week!\" ALIGN=middle WIDTH=160 HEIGHT=58>";
    } elsif ($rpms{$package}{ntm}) {
      $new = "<IMG SRC=\"images/new_this_month.jpeg\" ALT=\"New this month!\" ALIGN=middle WIDTH=160 HEIGHT=58>";
    }
    print PACKAGES "    <LI>$name $new\n\n";
    print PACKAGES "      <DL>\n";
    print PACKAGES "        <DD>Summary: $summary\n";
    $number = format_number $packagesize;
    print PACKAGES <<EOF;
        <DD><A HREF="packages/$name.html">
          Information</A><BR>
            <A HREF="../RPMS/$rpms{$package}{arch}/$package">Download</A>
              $number bytes
      </DL>
EOF

  }

  $generated = gmtime;
  $generated = "<SMALL>Generated automatically " 
      . $generated . " UTC by "
      . "<A HREF=\"../sitebin/buildsite.html\">$prog_name</A>"
      . " Revision $Version.</SMALL>\n";
  
  print PACKAGES <<EOF;
  </UL>
<DIV ALIGN=right>
  <A HREF="../index.html"><IMG SRC="images/top.gif" ALT="Top" BORDER=0></A>
  <A HREF="packages.html"><IMG SRC="images/a-z.gif" ALT="A-Z" BORDER=0></A>
</DIV>
    <HR>
    $generated
EOF
  
  close PACKAGES or die "$prog_name: cannot close  $file: $!";
}

sub by_group 
{
  my $comparison = uc ($rpms{$a}{group}) cmp uc ($rpms{$b}{group});
  
  unless ($comparison) {
    $comparison = uc ($rpms{$a}{package}) cmp uc ($rpms{$b}{package});
  }

  return $comparison;
}

sub write_todos
{
  my $file_html = $html_dir . "/todo.html";
  my $file = $sparemint_dir . "/TODO";
  my $number_of_orphaned_packages = 0;
  my $number_of_waiting_packages = 0;
  my $number_of_assigned_packages = 0;
  
  print "creating $file_html\n" if $verbose;
  print "creating $file\n" if $verbose;
  
  open TODO_HTML, ">$file_html"
      or die "$prog_name: can't open $file_html for writing: $!";
  open TODO, ">$file"
      or die "$prog_name: can't open $file for writing: $!";
  
  print TODO_HTML <<EOF;
<HTML>

<HEAD>
  <TITLE>Sparemint TODO List</TITLE>
  <LINK rel="stylesheet" href="../sparemint.css" type="text/css">
  <SCRIPT type="text/javascript">
       /*<![CDATA[*/
<!--
function decode_mt(s) {    //
       var n=0;
       var r="";
       for(var i=0; i < s.length; i++) {
               n=s.charCodeAt(i);
               if (n>=8364) {n = 128;}
               r += String.fromCharCode(n-(1));
       }
       return r;
}
function linkto_decode_mt(s)       {       //
       location.href=decode_mt(s);
}
// -->
       /*]]>*/
  </SCRIPT>
</HEAD>

<body style="background-color: white;">
<h1>
<center> <img style="border: 0px solid ; width: 345px; height: 84px;" src="images/mintlogo.png" alt="Sparemint logo"></center>
</h1>
<h4 style="text-align: center;"><a href="../index.html">Home</a>
<img src="images/leaf-bullet.gif"> <a href="../info.html">Information</a>
<img src="images/leaf-bullet.gif"> <a href="../NEWS.html">News</a>
<img src="images/leaf-bullet.gif"> <a href="../development.html">Development</a>
<img src="images/leaf-bullet.gif"> <a href="../download.html">Download</a>
<img src="images/leaf-bullet.gif"> <a href="../mirrors.html">Mirrors</a></h4>
<br>
    <H2>Sparemint TODO List</H2>

    <H2>Work in Progress</H2>
    The following packages are already assigned to a maintainer.  They will
    appear here soon.  If you want to take over maintainance for Sparemint
    packages you should rather look in the sections for
      <A HREF="#orphaned">orphaned packages</A>
    or
      <A HREF="#waiting">waiting packages</A>.
    <P>
    <UL>
EOF

  print TODO <<EOF;
Sparemint TODO List
===================

Work in Progress
----------------

The following packages are already assigned to a maintainer.  They will
appear here soon.  If you want to take over maintainance for Sparemint
packages you should rather look in the sections for orphaned packages or
waiting packages (below).

EOF

  foreach my $package (sort keys %packages) {
    if ($packages{$package}{status} eq "a") {
      $number_of_assigned_packages++;

      my $tag = $packages{$package}{newtag};
      my $new_maintainer ="$authors{$tag}{name}";
     
      print TODO_HTML <<EOF;
      <LI>$package: <A HREF="javascript:linkto_decode_mt('$authors{$tag}{email_encrypted}');">$new_maintainer</A>
EOF
      print TODO <<EOF;
o $package
  New maintainer: $new_maintainer <$authors{$tag}{email_html}>
EOF
    }    
  }
  
  print TODO_HTML "    </UL>\n";

  if (!$number_of_assigned_packages) {
    print TODO <<EOF;

There are currently no newly assigned packages!

EOF
    print TODO_HTML <<EOF;

<EM>There are currently no newly assigned packages!</EM>

EOF
  }
      
    print TODO_HTML <<EOF;
    <A NAME="orphaned"><H2>Orphaned packages</H2></A>
    The following packages are currently orphaned.  There is a binary
    package available but it may be outdated because the last maintainer
    has abandoned the package.
    <P>
    Please contact the Sparemint project if you are interested in
    taking over maintainance for one of these packages.
    <P>
    <UL>
EOF

    print TODO <<EOF;

Orphaned packages
-----------------

The following packages are currently orphaned.  There is a binary
package available but it may be outdated because the last maintainer
has abandoned the package.

Please contact the Sparemint project if you are interested in
taking over maintainance for one of these packages.

EOF

  foreach my $package (sort keys %packages) {
    if ($packages{$package}{status} eq "o") {
      $number_of_orphaned_packages++;

      my $tag = $packages{$package}{tag};
      my $maintainer ="$authors{$tag}{name}";
     
      print TODO_HTML <<EOF;
      <LI>$package, old maintainer: <A HREF="javascript:linkto_decode_mt('$authors{$tag}{email_encrypted}');">$maintainer</A>
EOF
      print TODO <<EOF;
o $package
  Old maintainer: $maintainer <$authors{$tag}{email_html}>
EOF
    }    
  }
  
  print TODO_HTML "    </UL>\n";

  if (!$number_of_orphaned_packages) {
    print TODO <<EOF;

There are currently no orphaned packages!

EOF
    print TODO_HTML <<EOF;

<EM>There are currently no orphaned packages!</EM>

EOF
  }
      
  print TODO_HTML <<EOF;
    <H2>Waiting packages</H2>
      The following packages are waiting for a maintainer.  There is
      currently no binary package available, so the new maintainer
      would have to start from the beginning.
      <P>
      Please contact the Sparemint project if you are interested in
      taking over maintainance for one of these packages.
      
    <UL>
EOF

  print TODO <<EOF;

Waiting packages
----------------

The following packages are waiting for a maintainer.  There is
currently no binary package available, so the new maintainer
would have to start from the beginning.

Please contact the Sparemint project if you are interested in
taking over maintainance for one of these packages.

EOF

  foreach my $package (sort keys %packages) {
    if ((!$packages{$package}{status}) or ($packages{$package}{status} eq "w")) {
      $number_of_waiting_packages++;
      print TODO_HTML <<EOF;
      <LI>$package
EOF
      print TODO <<EOF;
o $package
EOF
    }    
  }
  

  print TODO_HTML "    </UL>\n";
  
  if (!$number_of_waiting_packages) {
    print TODO <<EOF;

There are currently no waiting packages!  But if you have an idea for
a new package, you're welcome!

EOF
    print TODO_HTML <<EOF

<EM>There are currently no waiting packages!  But if you have an idea for
a new package, you're welcome!</EM>

EOF
  }      

  $generated = gmtime;
  $generated = "<SMALL>Generated automatically " 
      . $generated . " UTC by "
      . "<A HREF=\"../sitebin/buildsite.html\">$prog_name</A>"
      . " Revision $Version.</SMALL>\n";
  
  print TODO_HTML <<EOF;
<DIV ALIGN=right>
  <A HREF="../index.html"><IMG SRC="images/top.gif" ALT="Top" BORDER=0></A>
  <A HREF="packages.html"><IMG SRC="images/a-z.gif" ALT="A-Z" BORDER=0></A>
</DIV>
<HR>
$generated
EOF

  $generated = gmtime;
  $generated = "Generated automatically " 
      . $generated . " UTC by $prog_name Revision $Version.\n";
  
  print TODO "\n$generated\n";
  
  close TODO_HTML or die "$prog_name: cannot close  $file_html: $!\n";
  close TODO or die "$prog_name: cannot close $file: $!\n";
}
