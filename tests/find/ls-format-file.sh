#!/bin/sh
# Exercise 'find FILE -ls'

# Copyright (C) 2026 Free Software Foundation, Inc.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

. "${srcdir=.}/tests/init.sh"; fu_path_prepend_
print_ver_ find

# Ensure that find does not generally skip warnings due to POSIX requirements.
unset POSIXLY_CORRECT

# We want to check the date in the output of -ls, so ensure we're
# dealing with the C locale only.
LC_ALL=C
export LC_ALL
unset LANG

user_owner="$( id -u -n )"
if [ -z "${user_owner}" ]
then
    # This could mean that there is no entry in the password database.
    skip_ "unable to determine username of the current user"
fi

# Create a test file with some known properties.  Because of
# differences we cannot set a specific expectation for the number of
# blocks occupied by a file, but we should be able to expect it to be
# consistent with "ls -s".
umask 077
# If you change the value of testfile here to include any characters
# special in either glob patterns or regular expressions, you will
# need to re-check the tests in this file to ensure that they still do
# what you want.
testfile='lsme'
filesize=765
rm -f -- "${testfile}"
# We get the data for the body from "yes" rather than /dev/zero just in case
# the file system has some kind of optimization for files containing only
# zero bytes (e.g. converting it to a hole).
if ! ( yes non-empty | dd bs=1 count="${filesize}" of="${testfile}" ) 2>/dev/null
then
    framework_failure_ "failed to create test file ${testfile}"
fi
# Any specific time for the test will do as long as it is far enough
# away from now for ls to display the year.  This happens to be the
# date of a Swans concert I was at; they played at the Leadmill in
# Sheffield.
if ! touch -t 199203141900.01 "${testfile}"
then
    framework_failure_ "failed to set mtime of ${testfile}"
fi

# The script may be running with an effective group id which has the
# same name as the user's username.  This is inconvenient as we would
# not detect cases where the user and group name are swapped, either
# by find or by this test, or where the test checks against the wrong
# value (as in 9d50e9964449fb5e9f3da84a7c19c29dbf001bb5).
#
# So, find a group of which the current user is a member and which, if
# possible is not the same as the user's username.
choose_distinct_group() {
    chosen=N
    unset group_name
    for group_name in $(groups)
    do
        if [ "${group_name}" != "${user_owner}" ]
        then
            printf '%s\n' "${group_name}"
            chosen=Y
            break
        fi
    done
    if [ "${chosen}" = N ]
    then
        # The user's only group is the same as their username.
        # Default to the last (and only unless two groups have the
        # same name) group name in the output of groups.
        echo "${group_name:-}"
    fi
}
group_owner="$(choose_distinct_group)"
if [ -z "${group_owner}" ]
then
    # This is very unusual, because even if /etc/group has been
    # deleted, id should have printed the numeric value of the user's
    # primary group.  However, there are situations in which this
    # could happen.  For example, getgid() can fail on GNU Hurd.
    skip_ "unable to find a group of which the current user is a member"
fi

if ! chgrp "${group_owner}" "${testfile}"
then
    # There are some circumstances in which we cannot use a group in
    # the filesystem even though getgroups(2) returns it.  An example
    # is NFS version 2, on which the protocol limits the total number
    # of group IDs that a process can use.  If I recall correctly the
    # limit is 16.  Anyway, in this situation we will not claim that
    # the test framework failed, because it is generally not going to
    # be useful for the findutils maintainers to investigate these
    # cases.  We also will not continue with a fallback value as these
    # situations would be difficult to reproduce in the event of a bug
    # report.
    skip_ "failed to change group of ${testfile} to ${group_owner}"
fi

# Remember the file's inode number and block count.
inum="$( find "${testfile}" -printf '%i\n' )"
blocks_expected="$( ls -s "${testfile}" | sed -e "s/${testfile}//g" )"
# The system's value of BLOCKSIZE is implementation-dependent
# ("ls -k" forces ls to use 1KiB blocks, but -ls is intended
# to look like the output of ls -dils, without -k)


# Generate the ls output.
find "${testfile}" -ls > output.txt

# Show the reader of the test log what the output was.
echo "output of find ${testfile} -ls:"
cat output.txt
echo "same thing in od -c format:"
od -c output.txt

# Determine whether there is a trailing newline.  If not, output.txt
# is not actually a text file and some other checks may not work the
# way we expect.
if [ $(sed -n -e '$ s/.*//p'  < output.txt | wc -c) -eq 0 ]
then
    fail_ "find -ls output does not end in newline"
fi

###############################################################################
# Checks on the output fields generated by -ls, ignoring differences in the
# number of spaces between fields.  If these tests break, this likely indicates
# a bug in find.
###############################################################################

grep -e " ${testfile}"'$' < output.txt >/dev/null || fail_ "find -ls output should end with the file name"

# The output is supposed to look like this:

# st_ino  st_blocks
# |       | symbolic st_mode
# |       | |          st_nlink
# |       | |          |  Username corresponding to st_uid
# |       | |          |  |    Group corresponding to st_gid
# |       | |          |  |    |     Size in bytes
# |       | |          |  |    |     |   st_mtime
# |       | |          |  |    |     |   |            file name
# |       | |          |  |    |     |   |            |
# 4485432 1 -rw------- 1 james james 765 Mar 14  1992 lsme

awk < output.txt  \
    -v ME="${ME_}" \
    -v filename_expected="${testfile}" \
    -v inodenum="${inum}" \
    -v blocks_expected="${blocks_expected}" \
    -v filesize="${filesize}" \
    -v uowner="$(id -un)" \
    -v gowner="${group_owner}" '
BEGIN {
      rv=2
}
{
  for (i=1; i<=NF; ++i) {
    printf("%s: info: record %d field %2d contains %s\n", ME, NR, i, $i);
  }
}
NR == 2 {
   rv=1
   printf("%s: failed test: Too many lines of output\n", ME);
}
NR == 1 {
  rv=0

  st_ino=$1;
  st_blocks=$2;
  symbolic_st_mode="" $3;
  st_nlink=$4;
  st_uid=$5;
  st_gid=$6;
  st_size=$7;
  st_mtime_monthname=$8;
  st_mtime_monthday=$9;
  st_mtime_year=$10;
  filename_got=$11;

  printf("%s: info: checking output of -ls (which was [%s])\n", ME, $0);

  # field 1: inode number
  if (st_ino != inodenum) {
    rv=1
    printf("%s: failed test: expected inode number %d, got %s\n", ME, inodenum, $1);
  }

  # field 2: size in blocks
  if (st_blocks != blocks_expected) {
    rv=1
    printf("%s: failed test: expected block count %d got %d\n", ME, blocks_expected, st_blocks);
  } else {
    printf("%s: block count %d looks OK\n", ME, st_blocks);
  }

  # field 3 is the symbolic mode; we allow a final +
  # in case there is somehow a non-default ACL on the file.
  if (symbolic_st_mode != "-rw-------" && symbolic_st_mode != "-rw-------+") {
    rv=1
    printf("%s: failed test: expected symbolic mode [-rw-------], got [%s]\n", ME, symbolic_st_mode);
  }
  # field 4 is the link count
  if (st_nlink != 1) {
    rv=1
    printf("%s: failed test: expected link count 1, got %s\n", ME, st_nlink);
  } else {
    printf("%s: link count %s looks OK\n", ME, st_nlink);
  }
  # field 5 is the owner
  if (st_uid != uowner) {
    rv=1
    printf("%s: failed test: expected owner [%s], got [%s]\n", ME, uowner, st_uid);
  } else {
    printf("%s: owner %s looks OK\n", ME, st_uid);
  }
  # field 6 is the group owner
  if (st_gid != gowner) {
    rv=1
    printf("%s: failed test: expected group owner [%s], got [%s]\n", ME, gowner, st_gid);
  } else {
    printf("%s: group owner %s looks OK\n", ME, st_gid);
  }
  # field 7 is the size in bytes
  if (st_size != filesize) {
    rv=1
    printf("%s: failed test: expected file size %d, got %s\n", ME, filesize, st_size);
  } else {
    printf("%s: file size %s looks OK\n", ME, st_size);
  }
  # field 8 is the month of the mtime
  if (st_mtime_monthname != "Mar") {
    rv=1
    printf("%s: failed test: expected mtime month Mar, got %s\n", ME, st_mtime_monthname);
  } else {
    printf("%s: mtime month %s looks OK\n", ME, st_mtime_monthname);
  }
  # field 9 is the month-day of the mtime
  if (st_mtime_monthday != 14) {
    rv=1
    printf("%s: failed test: expected mtime month-day 14, got %s\n", ME, st_mtime_monthday);
  } else {
    printf("%s: mtime month-day %s looks OK\n", ME, st_mtime_monthday);
  }
  # field 10 is the year of the mtime
  if (st_mtime_year != 1992) {
    rv=1
    printf("%s: failed test: expected mtime year 1992, got %s\n", ME, st_mtime_year);
  } else {
    printf("%s: mtime year %s looks OK\n", ME, st_mtime_year);
  }
  # field 11 is the file name
  if (filename_got != filename_expected) {
    rv=1
    printf("%s: failed test: expected filename %s, got %s\n", ME, filename, $11);
  } else {
    printf("%s: file name %s looks OK\n", ME, $11);
  }
}
END {
    printf("%s: Finished AWK tests: exiting with status %d\n", ME, rv);
    exit rv;
}
'
rv=$?
echo "Awk exit status was ${rv}"
Exit "${rv}"
