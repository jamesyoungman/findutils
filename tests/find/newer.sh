#!/bin/sh
# Exercise -anewer -cnewer -newer -newerXY.

# Copyright (C) 2022-2024 Free Software Foundation, Inc.

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

# Verify the -newer test family - omitting birth time as support for this
# is not common enough yet.

# Although 'touch -t' is standardized by POSIX, that would not set the ctime
# to the given timestamp.  Therefore, we have to use sleep(1) to prepare the
# test files 1..3.
touch file1 \
  && sleep 1 \
  && touch file2 \
  && sleep 1 \
  && touch file3 \
  || skip_ "creating files with different timestamp failed"

# Stat the test files for debug purposes.
stat file? || : ignored

echo "./file3" > exp || framework_failure_

# Exercise -new options using a reference file.
for x in \
  -anewer -cnewer -newer \
  -neweraa -newerac -neweram \
  -newerca -newercc -newercm \
  -newerma -newermc -newermm \
  ; do
  rm -f out || framework_failure_
  find . $x file2 -name 'file*' > out || fail=1
  compare exp out || fail=1
done

# Exercise -new options using a reference timestamp (if possible).
tref="$( stat -c '%y' file2 )" || tref=''

if test "${tref}"; then
  for x in -newerat -newerct -newermt; do
    rm -f out || framework_failure_
    find . $x "${tref}" -name 'file*' > out || fail=1
    compare exp out || fail=1
  done
else
  echo "Determining reference timestamp failed - skipping this part."
fi

Exit $fail
