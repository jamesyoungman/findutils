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

# Create a test file with some known properties.
umask 077
testfile='lsme'
filesize=765
rm -f -- "${testfile}"
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

# Check the actual properties of the file (to verify that the setup
# was successful).
check_prop() {
    printf_fmt="${1}"
    expected="${2}"
    got="$( find "${testfile}" -printf "${printf_fmt}" )"

    if [ "${expected}" != "${got}" ]
    then
	framework_failure_ "expected test file ${testfile} to have -printf '${printf_fmt}\n' result '${expected}' but we got '${got}'"
    fi
}

check_prop '%M' "-rw-------"  # file mode
check_prop '%n' 1	      # link count
check_prop '%s' "${filesize}" # size in bytes
check_prop '%TF' "1992-03-14" # modification date
check_prop '%TH:%TM' "19:00"  # modification time (without seconds)

# Remember the file's inode number and block count.
inum="$( find "${testfile}" -printf '%i\n')"
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

grep -e ' lsme$' < output.txt >/dev/null || fail_ "find -ls output should end with the file name"

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
    -v filesize="${filesize}" \
    -v uowner="$(id -un)" \
    -v gowner="$(id -gn)" '
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

  # field 2: size in blocks is ignored as we probably cannot assume
  # any particular value for BLOCKSIZE.

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
