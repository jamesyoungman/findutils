#!/bin/sh
# Exercise 'find SYMLINK -ls'

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
symlink_target='target'
symlink='symlink'
filesize=765
rm -f -- "${symlink_target}" "${symlink}"
if ! ( yes non-empty | dd bs=1 count="${filesize}" of="${symlink_target}" ) 2>/dev/null
then
    framework_failure_ "failed to create test file ${symlink_target}"
fi
ln -s "${symlink_target}" "${symlink}"

# Any specific time for the test will do as long as it is far enough
# away from now for ls to display the year.  This happens to be the
# date of a Swans concert I was at; they played at the Leadmill in
# Sheffield.
if ! touch -t 199203141900.01 "${symlink_target}"
then
    framework_failure_ "failed to set mtime of ${symlink_target}"
fi
if ! touch -h -t 199912312359.59 "${symlink}"
then
    framework_failure_ "failed to set mtime of ${symlink}"
fi

# Check the actual properties of the file (to verify that the setup
# was successful).
check_prop() {
    printf_fmt="${1}"
    expected="${2}"
    got="$( find "${symlink}" -printf "${printf_fmt}" )"

    if [ "${expected}" != "${got}" ]
    then
	framework_failure_ "expected test file ${symlink} to have -printf '${printf_fmt}\n' result '${expected}' but we got '${got}'"
    fi
}

check_prop '%M' "lrwxrwxrwx"  # file mode
check_prop '%n' 1	      # link count
check_prop '%s' 6             # size in bytes (length of "target")
check_prop '%TF' "1999-12-31" # modification date
check_prop '%TH:%TM' "23:59"  # modification time (without seconds)

# Remember the file's inode number and block count.
inum="$( find "${symlink}" -printf '%i\n')"
# The system's value of BLOCKSIZE is implementation-dependent
# ("ls -k" forces ls to use 1KiB blocks, but -ls is intended
# to look like the output of ls -dils, without -k)


# Generate the ls output.
find "${symlink}" -ls > output.txt

# Show the reader of the test log what the output was.
echo "output of find ${symlink} -ls:"
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

grep -e ' symlink -> target$' < output.txt >/dev/null || fail_ "find -ls output should end with symlink -> target"

# The output is supposed to look like this:

# st_ino       st_blocks
# |            | symbolic st_mode
# |            | |            st_nlink
# |            | |            | Username corresponding to st_uid
# |            | |            | |        Group corresponding to st_gid
# |            | |            | |        |               Size in bytes
# |            | |            | |        |               | st_mtime
# |            | |            | |        |               | |            symbolic link name
# |            | |            | |        |               | |            |          symlink target
# |            | |            | |        |               | |            |          |
# 5122383      1 lrwxrwxrwx   1 james    james           6 Mar 14  1992 symlink -> target

awk < output.txt  \
    -v ME="${ME_}" \
    -v symlink_name_expected="${symlink}" \
    -v target_name_expected="${symlink_target}" \
    -v inodenum="${inum}" \
    -v filesize=6 '
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
  symlink_got=$11;
  arrow_got=$12;
  target_got=$13;

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
  if (symbolic_st_mode != "lrwxrwxrwx" && symbolic_st_mode != "lrwxrwxrwx+") {
    rv=1
    printf("%s: failed test: expected symbolic mode [lrwxrwxrwx], got [%s]\n", ME, symbolic_st_mode);
  }
  # field 4 is the link count
  if (st_nlink != 1) {
    rv=1
    printf("%s: failed test: expected link count 1, got %s\n", ME, st_nlink);
  } else {
    printf("%s: link count %s looks OK\n", ME, st_nlink);
  }

  # field 5 is the owner
  # field 6 is the group owner

  # field 7 is the size in bytes
  if (st_size != filesize) {
    rv=1
    printf("%s: failed test: expected file size %d, got %s\n", ME, filesize, st_size);
  } else {
    printf("%s: file size %s looks OK\n", ME, st_size);
  }
  # field 8 is the month of the mtime
  if (st_mtime_monthname != "Dec") {
    rv=1
    printf("%s: failed test: expected mtime month Dec, got %s\n", ME, st_mtime_monthname);
  } else {
    printf("%s: mtime month %s looks OK\n", ME, st_mtime_monthname);
  }
  # field 9 is the month-day of the mtime
  if (st_mtime_monthday != 31) {
    rv=1
    printf("%s: failed test: expected mtime month-day 31, got %s\n", ME, st_mtime_monthday);
  } else {
    printf("%s: mtime month-day %s looks OK\n", ME, st_mtime_monthday);
  }
  # field 10 is the year of the mtime
  if (st_mtime_year != 1999) {
    rv=1
    printf("%s: failed test: expected mtime year 1999, got %s\n", ME, st_mtime_year);
  } else {
    printf("%s: mtime year %s looks OK\n", ME, st_mtime_year);
  }
  # field 11 is the file name
  if (symlink_got != symlink_name_expected) {
    rv=1
    printf("%s: failed test: expected filename %s, got %s\n", ME, filename, $11);
  } else {
    printf("%s: file name %s looks OK\n", ME, $11);
  }
  # field 12 is "->"
  if ($12 != "->") {
    rv=1
    printf("%s: failed test: expected ->, got %s\n", ME, $11);
  }
  # field 13 is the symbolic link target
  if (target_got != target_name_expected) {
    rv=1
    printf("%s: failed test: expected symlink target %s, got %s\n", ME, target_name_expected, target_got);
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
