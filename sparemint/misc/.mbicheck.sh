# !/bin/sh
# Copyright (C) 1999, Guido Flohr <gufl0000@stud.uni-sb.de>
# mbicheck - Check system for MBI fitness.  If you add additional checks
# please avoid using any external commands since they will later be
# installed.  Try to restrict yourself to shell builtins.
#

# Uncomment this line for strict independence on non-builtins.
USER_PATH="$PATH"
PATH=""
export PATH

errors=none
warnings=none

# Check the directory structure.
check_dirs ()
{
  echo "Checking if toplevel directory structure is sane ..."
  missing=""
  recommended=""
  for dir in bin etc home lib opt root sbin tmp; do
    if test ! -d /$dir; then
      missing="$missing $dir"
      errors=yes
    fi
  done
  for dir in mnt; do
    if test ! -d /$dir; then
      recommended="$recommended $dir"
      warnings=yes
    fi
  done
  if test x"$missing" != x; then
    echo "*** The following toplevel directories are missing on your system:"
    for dir in $missing; do
      echo "    /$dir"
    done
    echo "  Please create the missing directories on a partition of your"
    echo "  choice and then add the following lines to your kernel"
    echo "  configuration file \`mint.cnf':"
    for dir in $missing; do
      echo "    sln x:\\$dir u:\\$dir"
    done
    echo "  Please replace the drive letter \`x:' with the name of the"
    echo "  partition where you have created the directory."
  fi
  if test x"$recommended" != x; then
    echo "*** The following toplevel directories are recommended but do"
    echo "*** not exist:"
    for dir in $recommended; do
      echo "    /$dir"
    done
    echo "  Please create the missing directories on a partition of your"
    echo "  choice and then add the following lines to your kernel"
    echo "  configuration file \`mint.cnf':"
    for dir in $recommended; do
      echo "    sln x:\\$dir u:\\$dir"
    done
    echo "  Please replace the drive specification \`x:' with the name of the"
    echo "  partition where you have created the directory."
  fi
}

# Check if the boot drive can be positively identified and if we find what
# we need there.
check_boot ()
{
  echo "Checking for boot partition ..."
  noboot=no
  mintdir=/boot/mint
  if test ! -d /boot; then
    warnings=yes
    echo "*** Cannot find your boot partition \`/boot'."
    echo "  The toplevel directory \`boot' should be a symbolic link to your"
    echo "  actual boot partition.  Please add the following line to your"
    echo "  kernel configuration file \`mint.cnf':"
    echo "    sln x:\\ u:\\boot"
    echo "  Please replace the drive specification \`x:' with the name of"
    echo "  your boot partition."
    return
  fi
  if test ! -d $mintdir; then
    if test -d /boot/multitos; then
      errors=yes
      echo "*** Cannot find \`$mintdir'."
      echo "  You should rename \`/boot/multitos' to \`/boot/mint'."
      echo "  Otherwise installation procedures may fail to find"
      echo "  system configuration files."
      mintdir=/boot/multitos
    else
      noboot=yes
    fi
  fi
  
  # Try some checks to see if /boot is really the boot partition.
  test -d /boot/auto || noboot=yes
  test "/boot/auto/mint*.prg" = '/boot/auto/mint*.prg' && noboot=yes
  test -f $mintdir/mint.cnf || noboot=yes
  
  if test $noboot != "yes"; then
    errors=yes
    echo "*** The directory \`/boot' is not your boot partition."
    echo "  The toplevel directory \`boot' should be a symbolic link to your"
    echo "  actual boot partition.  Please add the following line to your"
    echo "  kernel configuration file \`mint.cnf':"
    echo "    sln x:\\ u:\\boot"
    echo "  Please replace the drive specification \`x:' with the name of"
    echo "  your boot partition."    
  fi
  
  if test -d /usr/multitos -o -d /usr/mint; then
    echo "*** Non-standard directories in \`/usr'."
    echo "  The directories (resp. links) \`/usr/multitos' and "
    echo "  \`/usr/mint' are not required.  Their function is fulfilled"
    echo "  by the directory \`/boot/mint'.  Please remove the link."
  fi
}

# Check for FHS 2.0 compatibility.  Full FHS 2.0 compliance cannot be
# achieved for MiNT (see FHS, section 1.8).  We don't check for X
# related things here.
check_fhs ()
{
  echo "Checking for FHS 2.0 compatible directory structure ..."
  local_errors=no
  missing=""
  if test -d /usr; then
    # We also check for the existence of /usr/games which is seemingly not
    # required by FHS 2.0.  However it appears in section 4 of the standard
    # (page 15).
    for subdir in bin include lib local games sbin share share/dict \
        share/doc share/games share/info share/locale share/man share/nls \
        share/misc share/terminfo share/tmac share/zoneinfo src; do
      if test ! -d /usr/$subdir; then
        errors=yes
        local_errors=yes
        missing="$missing /usr/$subdir"
      fi
    done
  fi
  if test -d /var; then
    for subdir in cache cache/fonts cache/man games lock log mail opt run \
        spool spool/cron spool/lpd spool/mqueue spool/news spool/rwho \
        spool/smail spool/uucp state tmp yp; do
      if test ! -d /var/$subdir; then
        errors=yes
        local_errors=yes
        missing="$missing /var/$subdir"
      fi
    done
  fi
  if test $local_errors != no; then
    echo "*** Missing directories found\!"
    echo "  The following directories which may be required are missing on"
    echo "  your system:"
    for dir in $missing; do
      echo "    $dir"
    done
    echo "  You should better create these directories.  The installation"
    echo "  routines may otherwise fail to set the right permissions for"
    echo "  them."
  fi
}

# Check for GEM-specific stuff.
check_gemdirs ()
{
  echo "Checking for GEM specific directory structure ..."
  if test ! -d /usr/GEM; then
    warnings=yes
    echo "*** Missing directory \`/usr/GEM'."
    echo "  Please create this directory and rerun this test later."
    echo "  The directory \`/usr/GEM' will contain some symbolic links"
    echo "  to directories that will otherwise be hard to find for"
    echo "  their actual location may vary widely."
    errors=yes
    return
  fi
  
  # OK, /usr/GEM exists.
  if test ! -d /usr/GEM/gemsys; then
    warnings=yes
    echo "*** Cannot find \`/usr/GEM/gemsys'."
    echo "  \`/usr/GEM/gemsys' is normally identical to \`/boot/gemsys',"
    echo "  the directory where your VDI fonts and drivers are stored."
    echo "  Please create a symbolic link, for example:"
    echo "    ln -s c:/gemsys /usr/GEM/gemsys"
    echo "  If your boot partition is not \`c:', change the command"
    echo "  accordingly."
  fi
  if test ! -d /usr/GEM/btfonts; then
    warnings=yes
    echo "*** Cannot find \`/usr/GEM/btfonts'."
    echo "  \`/usr/GEM/btfonts' should be a symbolic link to the directory"
    echo "  where your VDI implementation expects vector fonts.  If your"
    echo "  VDI does not yet support vector fonts you don't need the"
    echo "  directory but you should still create the line in order to"
    echo "  shut this script up.  Do that as follows:"
    echo "    ln -s x:/btfonts /usr/GEM/btfonts"
    echo "  Please replace \`x:/btfonts' with the actual location of your"
    echo "  vector fonts."
  fi
  if test ! -d /usr/GEM/acc; then
    warnings=yes
    echo "*** Cannot find \`/usr/GEM/acc'."
    echo "  \`/usr/GEM/acc' should be a symbolic link to the directory"
    echo "  where your AES implementation expects desk accessories."
    echo "  Please create the link as follows:"
    echo "    ln -s x:/acc /usr/GEM/acc"
    echo "  Please replace \`x:/acc' with the actual location of your"
    echo "  desk accessories."
  fi
  if test ! -d /usr/GEM/cpx; then
    echo "*** Cannot find \`/usr/GEM/cpx'."
    echo "  \`/usr/GEM/cpx' should be a symbolic link to the directory"
    echo "  where your X-Control implementation expects CPX modules."
    echo "  Please create the link as follows:"
    echo "    ln -s x:/cpx /usr/GEM/cpx"
    echo "  Please replace \`x:/cpx' with the actual location of your"
    echo "  CPX modules."
  fi
  if test ! -d /usr/GEM/stguide; then
    echo "*** Cannot find \`/usr/GEM/stguide'."
    echo "  \`/usr/GEM/stguide' should be a symbolic link to the directory"
    echo "  where your hypertexts in ST-Guide format are stored.  ST-Guide"
    echo "  is a freely availabe hypertext system that is widely spread"
    echo "  on MiNT systems.  Some software packages may need to know the"
    echo "  location where to store help files in hypertext format."
    echo "  Please create the link as follows:"
    echo "    ln -s x:/help /usr/GEM/stguide"
    echo "  Please replace \`x:/help' with the actual location of your"
    echo "  hypertext files."
  fi
}

duplicate_user ()
{
  echo "*** Duplicate entry for user \`$1' found in \`/etc/passwd'."
  echo "  You should remove one entry."
}

duplicate_group ()
{
  echo "*** Duplicate entry for group \`$1' found in \`/etc/group'."
  echo "  You should remove one entry."
}

show_howto_change_uid=yes
wrong_user=
check_passwd_contents ()
{
  user=$1
  xuid=$2
  xgid=$3
  xhome=$4
  xshell=$5
  uid=$6
  gid=$7
  home=$8
  shell=$9
  
  if test "x$xuid" != x"$uid"; then
    warnings=yes
    echo "*** Wrong user id for user \`$user'."
    echo "  The user \`$user' is expected to have the user id $xuid.  Please"
    echo "  change the user id for \`$user' in \`/etc/passwd' from $uid"
    echo "  to $xuid."
    if test $show_howto_change_uid = yes; then
      show_howto_change_uid=no
      wrong_user=$user
      echo "  The user id is the number between the second and the third "
      echo "  colon (\`:') in the line starting with \`$user'.  After you"
      echo "  have done this you have to change the ownership of all files"
      echo "  belonging to \`$user' in the entire filesystem.  This is done"
      echo "  with the command:"
      echo "    find / -user $uid -exec chown $user {} \\;"
    else
      echo "  Please proceed as explained above for the user \`$wrong_user'."
    fi
  fi
  if test "x$xgid" != "x$gid"; then
    warnings=yes
    echo "*** Wrong group id for user \`$user'."
    echo "  The user \`$user' is expected to have the group id $xgid.  Please"
    echo "  change the group id for \`$user' in \`/etc/passwd' from $gid"
    echo "  to $xgid."
    echo "  The group id is the number between the third and the fourth"
    echo "  colon (\`:') in the line starting with \`$user'."
  fi
  if test "x$xhome" != "x$home"; then
    warnings=yes
    echo "*** Wrong home directory for user \`$user'."
    echo "  The user \`$user' is expected to have the home directory"
    echo "  \`$xhome'.  Please change the home directory for \`$user'"
    echo "  in \`/etc/passwd' from \`$home' to \`$xhome'."
    echo "  The home directory is the pathname between the fifth and sixth"
    echo "  colon (\`:') in the line starting with \`$user'."
  fi
  if test "x$xshell" != "x$shell"; then
    wrong_shell=yes
    if test "x$xshell" = "x/bin/bash"; then
      if test "x$shell" = "x/bin/sh" -o "x$shell" = "/bin/csh" -o "x$shell" = "/bin/tcsh"; then
        wrong_shell=no
      fi
    fi
    if test $wrong_shell = yes; then
      warnings=yes
      echo "*** Wrong home directory for user \`$user'."
      echo "  The user \`$user' is expected to have the user shell"
      echo "  \`$xshell'.  Please change the home directory for \`$shell'"
      echo "  in \`/etc/passwd' from \`$shell' to \`$xshell'."
      echo "  The user shell is the pathname after the seventh (last)"
      echo "  colon (\`:') in the line starting with \`$user'."
    fi
  fi
}

show_howto_change_gid=yes
wrong_group=
check_group_contents ()
{
  group=$1
  xgid=$2
  xmembers=$3
  gid=$4
  members=$5
 
  if test "x$xgid" != "x$gid"; then
    warnings=yes
    echo "*** Wrong group id for group \`$group'."
    echo "  The group \`$group' is expected to have the group id $xgid.  Please"
    echo "  change the group id for \`$group' in \`/etc/group' from $gid"
    echo "  to $xgid."
    if test $show_howto_change_gid = yes; then
      show_howto_change_gid=no
      wrong_group=$group
      echo "  The group id is the number between the second and the third "
      echo "  colon (\`:') in the line starting with \`$group'.  After you"
      echo "  have done this you have to change the ownership of all files"
      echo "  belonging to \`$group' in the entire filesystem.  This is done"
      echo "  with the command:"
      echo "    find / -group $gid -exec chgrp $group {} \\;"
    else
      echo "  Please proceed as explained above for the group \`$wrong_group'."
    fi
  fi

  # Now for the members.
  IFS=","
  for wanted_member in $xmembers; do
    found=no
    for member in $members; do
      if test "$member" = "$wanted_member"; then
        found=yes
        break
      fi
    done
    if test x$found = no; then
      warnings=yes
      echo "*** The user \`$wanted_member' should be a member of the group"
      echo "  \`$group'.  The group members are a comma-separated list"
      echo "  following the third (last) colon (\`:') in the line starting"
      echo "  with \`$group' in the file \`/etc/groups'."
    fi
  done
  IFS=":"
}

add_missing_user ()
{
  errors=yes
  echo "*** The user \`$1' is missing on your system."
  echo "  Please add the line"
  echo "    $2"
  echo "  to the file \`/etc/passwd'."
}

add_missing_group ()
{
  errors=yes
  echo "*** The group \`$1' is missing on your system."
  echo "  Please add the line"
  echo "    $2"
  echo "  to the file \`/etc/group'."
}

# Check the contents of /etc/passwd.
check_users ()
{
  echo "Checking user database ..."
  if test ! -f /etc/passwd; then
    errors=yes
    echo "*** Cannot find \`/etc/passwd'."
    echo "  This file contains the user database and is required."
    echo "  Please create it."
    return
  fi

  unset has_user_root has_user_nobody has_user_daemon has_user_bin has_user_uucp has_user_news 
  unset has_user_ftp has_user_games has_user_mail has_user_adm has_user_sync has_user_shutdown has_user_halt
  unset has_user_operator has_user_gopher
  
  exec </etc/passwd
  IFS=":"
  while read user passwd uid gid gecos home shell; do
    case $user in
      root)
        if test x$has_user_root != x; then
          duplicate_user "root"
        else
          has_user_root=yes
          check_passwd_contents root 0 0 /root /bin/bash "$uid" "$gid" "$home" "$shell"
        fi
        ;;
      nobody)
        if test x$has_user_nobody != x; then
          duplicate_user "nobody"
        else
          has_user_nobody=yes
          check_passwd_contents nobody 65534 65534 / "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      daemon)
        if test x$has_user_daemon != x; then
          duplicate_user "daemon"
        else
          has_user_daemon=yes
          check_passwd_contents root 1 1 / "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      bin)
        if test x$has_user_bin != x; then
          duplicate_user "bin"
        else
          has_user_bin=yes
          check_passwd_contents root 3 3 /bin "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;   
      uucp)
        if test x$has_user_uucp != x; then
          duplicate_user "uucp"
        else
          has_user_uucp=yes
          check_passwd_contents uucp 4 8 /var/spool/uucp "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;   
      news)
        if test x$has_user_news != x; then
          duplicate_user "news"
        else
          has_user_news=yes
          check_passwd_contents news 6 6 /var/spool/news "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      ftp)
        if test x$has_user_ftp != x; then
          duplicate_user "ftp"
        else
          has_user_ftp=yes
          check_passwd_contents ftp 8 50 /home/ftp "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      adm)
        if test x$has_user_adm != x; then
          duplicate_user "adm"
        else
          has_user_adm=yes
          check_passwd_contents adm 9 12 /var/adm "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      operator)
        if test x$has_user_operator != x; then
          duplicate_operator "operator"
        else
          has_user_operator=yes
          check_passwd_contents operator 10 0 /root "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      gopher)
        if test x$has_user_gopher != x; then
          duplicate_operator "gopher"
        else
          has_user_gopher=yes
          check_passwd_contents gopher 12 30 /usr/lib/gopher-data "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      sync)
        if test x$has_user_sync != x; then
          duplicate_user "sync"
        else
          has_user_sync=yes
          check_passwd_contents sync 13 0 /sbin /bin/sync "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      shutdown)
        if test x$has_user_shutdown != x; then
          duplicate_user "shutdown"
        else
          has_user_shutdown=yes
          check_passwd_contents shutdown 14 0 /sbin /sbin/shutdown "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      halt)
        if test x$has_user_halt != x; then
          duplicate_user "halt"
        else
          has_user_halt=yes
          check_passwd_contents halt 15 0 /sbin /sbin/halt "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      games)
        if test x$has_user_games != x; then
          duplicate_user "games"
        else
          has_user_games=yes
          check_passwd_contents games 20 100 /usr/games "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
      mail)
        if test x$has_user_mail != x; then
          duplicate_user "mail"
        else
          has_user_mail=yes
          check_passwd_contents mail 7 7 /var/spool/mail "" "$uid" "$gid" "$home" "$shell"
        fi
        ;;      
    esac
  done
  
  if test "x$has_user_root" != "xyes"; then
    add_missing_user "root" "root:*:0:0:root:/root:/bin/bash"
  fi
  if test "x$has_user_nobody" != "xyes"; then
    add_missing_user "nobody" "nobody:*:65534:65534:Nobody:/:"
  fi
  if test "x$has_user_daemon" != "xyes"; then
    add_missing_user "nobody" "nobody:*:65534:65534:daemon:/:"
  fi
  if test "x$has_user_bin" != "xyes"; then
    add_missing_user "bin" "bin:*:3:3:bin:/bin:"
  fi
  if test "x$has_user_uucp" != "xyes"; then
    add_missing_user "uucp" "uucp:*:4:8:uucp:/var/spool/uucp:"
  fi
  if test "x$has_user_news" != "xyes"; then
    add_missing_user "news" "news:*:6:6:news:/var/spool/news:"
  fi
  if test "x$has_user_ftp" != "xyes"; then
    add_missing_user "ftp" "ftp:*:8:50:FTP User:/home/ftp:"
  fi
  if test "x$has_user_adm" != "xyes"; then
    add_missing_user "adm" "adm:*:9:12:adm:/var/adm:"
  fi
  if test "x$has_user_operator" != "xyes"; then
    add_missing_user "operator" "operator:*:10:0:operator:/root:"
  fi
  if test "x$has_user_gopher" != "xyes"; then
    add_missing_user "gopher" "gopher:*:12:0:gopher:/usr/lib/gopher-data:"
  fi
  if test "x$has_user_sync" != "xyes"; then
    add_missing_user "sync" "sync:*:13:0:sync:/sbin:/bin/sync:"
  fi
  if test "x$has_user_shutdown" != "xyes"; then
    add_missing_user "shutdown" "shutdown:*:14:0:shutdown:/sbin:/bin/sync:"
  fi
  if test "x$has_user_halt" != "xyes"; then
    add_missing_user "halt" "halt:*:15:0:halt:/sbin:/bin/halt:"
  fi
  if test "x$has_user_games" != "xyes"; then
    add_missing_user "games" "games:*:20:100:games:/usr/games:"
  fi
  if test "x$has_user_mail" != "xyes"; then
    add_missing_user "mail" "mail:*:7:7:mail:/var/spool/mail:"
  fi
}

# Check the contents of /etc/group
check_groups ()
{
  echo "Checking group database ..."
  if test ! -f /etc/group; then
    errors=yes
    echo "*** Cannot find \`/etc/group'."
    echo "  This file contains the group database and is required."
    echo "  Please create it."
    return
  fi
  
  unset has_group_wheel has_group_nobody has_group_daemon has_group_kmem has_group_bin has_group_tty has_group_lp
  unset has_group_news has_group_mail has_group_uucp has_group_sys has_group_staff has_group_man has_group_adm
  unset has_group_disk has_group_mem has_group_games has_group_gopher has_group_dip has_group_ftp has_group_users

  exec </etc/group
  IFS=":"
  while read group passwd gid members; do
    case $group in
      wheel)
        if test x$has_group_wheel != x; then
          duplicate_group "wheel"
        else
          has_group_wheel=yes
          check_group_contents wheel 0 root "$gid" "$members"
        fi
        ;;
      nobody)
        if test x$has_group_nobody != x; then
          duplicate_group "nobody"
        else
          has_group_nobody=yes
          check_group_contents nobody 65534 "" "$gid" "$members"
        fi
        ;;
      daemon)
        if test x$has_group_daemon != x; then
          duplicate_group "daemon"
        else
          has_group_daemon=yes
          check_group_contents daemon 1 "root,bin,daemon" "$gid" "$members"
        fi
        ;;
      kmem)
        if test x$has_group_kmem != x; then
          duplicate_group "kmem"
        else
          has_group_kmem=yes
          check_group_contents kmem 2 "" "$gid" "$members"
        fi
        ;;
      bin)
        if test x$has_group_bin != x; then
          duplicate_group "bin"
        else
          has_group_bin=yes
          check_group_contents bin 3 "root,bin,daemon" "$gid" "$members"
        fi
        ;;
      tty)
        if test x$has_group_tty != x; then
          duplicate_group "tty"
        else
          has_group_tty=yes
          check_group_contents tty 4 "" "$gid" "$members"
        fi
        ;;
      lp)
        if test x$has_group_lp != x; then
          duplicate_group "lp"
        else
          has_group_lp=yes
          check_group_contents lp 5 "daemon,lp" "$gid" "$members"
        fi
        ;;
      news)
        if test x$has_group_news != x; then
          duplicate_group "news"
        else
          has_group_news=yes
          check_group_contents news 6 news "$gid" "$members"
        fi
        ;;
      mail)
        if test x$has_group_mail != x; then
          duplicate_group "mail"
        else
          has_group_mail=yes
          check_group_contents mail 7 mail "$gid" "$members"
        fi
        ;;
      uucp)
        if test x$has_group_uucp != x; then
          duplicate_group "uucp"
        else
          has_group_uucp=yes
          check_group_contents uucp 8 uucp "$gid" "$members"
        fi
        ;;
      sys)
        if test x$has_group_sys != x; then
          duplicate_group "sys"
        else
          has_group_sys=yes
          check_group_contents sys 9 "root,bin,adm" "$gid" "$members"
        fi
        ;;
      staff)
        if test x$has_group_staff != x; then
          duplicate_group "staff"
        else
          has_group_staff=yes
          check_group_contents staff 10 root "$gid" "$members"
        fi
        ;;
      man)
        if test x$has_group_man != x; then
          duplicate_group "man"
        else
          has_group_man=yes
          check_group_contents man 11 "" "$gid" "$members"
        fi
        ;;
      adm)
        if test x$has_group_adm != x; then
          duplicate_group "adm"
        else
          has_group_adm=yes
          check_group_contents adm 12 "root,adm,daemon" "$gid" "$members"
        fi
        ;;
      disk)
        if test x$has_group_disk != x; then
          duplicate_group "disk"
        else
          has_group_disk=yes
          check_group_contents disk 13 root "$gid" "$members"
        fi
        ;;
      mem)
        if test x$has_group_mem != x; then
          duplicate_group "mem"
        else
          has_group_mem=yes
          check_group_contents mem 14 "" "$gid" "$members"
        fi
        ;;
      games)
        if test x$has_group_games != x; then
          duplicate_group "games"
        else
          has_group_games=yes
          check_group_contents games 20 "" "$gid" "$members"
        fi
        ;;
      gopher)
        if test x$has_group_gopher != x; then
          duplicate_group "gopher"
        else
          has_group_gopher=yes
          check_group_contents gopher 30 "" "$gid" "$members"
        fi
        ;;
      dip)
        if test x$has_group_dip != x; then
          duplicate_group "dip"
        else
          has_group_dip=yes
          check_group_contents dip 40 "" "$gid" "$members"
        fi
        ;;
      ftp)
        if test x$has_group_ftp != x; then
          duplicate_group "ftp"
        else
          has_group_ftp=yes
          check_group_contents ftp 50 "" "$gid" "$members"
        fi
        ;;
      users)
        if test x$has_group_users != x; then
          duplicate_group "users"
        else
          has_group_users=yes
          check_group_contents users 100 "" "$gid" "$members"
        fi
        ;;
    esac
  done
  
  if test "x$has_group_wheel" != "xyes"; then
    add_missing_group "wheel" "wheel:*:0:root"
  fi
  if test "x$has_group_nobody" != "xyes"; then
    add_missing_group "nobody" "nobody:*:65534"
  fi
  if test "x$has_group_daemon" != "xyes"; then
    add_missing_group "daemon" "daemon:*:1:root,bin,daemon"
  fi
  if test "x$has_group_kmem" != "xyes"; then
    add_missing_group "kmem" "kmem:*:2:"
  fi
  if test "x$has_group_bin" != "xyes"; then
    add_missing_group "bin" "bin:*:3:root,bin,daemon"
  fi
  if test "x$has_group_tty" != "xyes"; then
    add_missing_group "tty" "tty:*:4:"
  fi
  if test "x$has_group_lp" != "xyes"; then
    add_missing_group "lp" "lp:*:5:daemon,lp"
  fi
  if test "x$has_group_news" != "xyes"; then
    add_missing_group "news" "news:*:6:news"
  fi
  if test "x$has_group_mail" != "xyes"; then
    add_missing_group "mail" "mail:*:7:mail"
  fi
  if test "x$has_group_uucp" != "xyes"; then
    add_missing_group "uucp" "uucp:*:8:uucp"
  fi
  if test "x$has_group_sys" != "xyes"; then
    add_missing_group "sys" "sys:*:9:root,bin,adm"
  fi
  if test "x$has_group_staff" != "xyes"; then
    add_missing_group "staff" "staff:*:10:root"
  fi
  if test "x$has_group_man" != "xyes"; then
    add_missing_group "man" "man:*:11:"
  fi
  if test "x$has_group_adm" != "xyes"; then
    add_missing_group "adm" "adm:*:12:root,adm,daemon"
  fi
  if test "x$has_group_disk" != "xyes"; then
    add_missing_group "disk" "disk:*:13:root"
  fi
  if test "x$has_group_mem" != "xyes"; then
    add_missing_group "mem" "mem:*:14:"
  fi
  if test "x$has_group_games" != "xyes"; then
    add_missing_group "games" "games:*:20:"
  fi
  if test "x$has_group_gopher" != "xyes"; then
    add_missing_group "gopher" "gopher:*:30:"
  fi
  if test "x$has_group_dip" != "xyes"; then
    add_missing_group "dip" "dip:*:40:"
  fi
  if test "x$has_group_ftp" != "xyes"; then
    add_missing_group "ftp" "ftp:*:50:"
  fi
  if test "x$has_group_users" != "xyes"; then
    add_missing_group "users" "users:*:100:"
  fi
}

check_dirs
check_boot
check_fhs
check_gemdirs
check_users
check_groups

if test "x$errors" = xyes; then
  echo "**************"
  echo "** ERRORS!  **"
  echo "**************"
  echo "Your system is not yet ready!  You should fix the errors"
  echo "that have occured before installing any packages."
  echo "If you cannot scroll back to see the error messages you"
  echo "should rerun the test and redirect the output into a"
  echo "file, for example like this:"
  echo "  $0 >/tmp/checklog"
  echo "Then study the contents of \`/tmp/checklog' to fix the"
  echo "errors."
  exit 2
elif test "x$warnings" = xyes; then
  echo "***************"
  echo "** WARNINGS! **"
  echo "***************"
  echo "Your system is basically ready!  But you should fix the warnings"
  echo "before you install any package."
  echo "If you cannot scroll back to see the warnings you"
  echo "should rerun the test and redirect the output into a"
  echo "file, for example like this:"
  echo "  $0 >/tmp/checklog"
  echo "Then study the contents of \`/tmp/checklog' to fix the"
  echo "warnings."
  exit 1
else
  echo "================"
  echo "CONGRATULATIONS!"
  echo "================"
  echo "Your system is fit! You can proceed installing all packages"
  echo "you want."
fi
