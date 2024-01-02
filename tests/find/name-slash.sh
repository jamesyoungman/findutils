#!/bin/sh
# Exercise 'find -name PATTERN' behavior with a '/' in PATTERN.

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

# Ensure that find does not generally skip warnings due to POSIX requirements.
unset POSIXLY_CORRECT

# Detect if find emits warnings.
find_emits_warnings_ \
  && fwarns=1 \
  || fwarns=0

# Exercise '-name PATTERN' with a '/' somewhere in PATTERN.
find -name 'dir/file' > out 2> err || fail=1
compare /dev/null out || fail=1
if [ $fwarns = 1 ]; then
  grep 'warning: .*matches against basenames only.* evaluate to false' err \
    || { cat err; fail=1; }
else
  compare /dev/null out
fi

# Likewise in POSIX environment.
POSIXLY_CORRECT=1 find -name 'dir/file' > out 2> err || fail=1
compare /dev/null out || fail=1
compare /dev/null err || fail=1

# Likewise with -nowarn.
find -nowarn -name 'dir/file' > out 2> err || fail=1
compare /dev/null out || fail=1
compare /dev/null err || fail=1

# Exercise '-name /', i.e., PATTERN just being "/": no warning because this
# is a valid basename in the (trivial) case comparing to root directory "/".
echo '/' > exp || framework_failure_
find / -maxdepth 0 -name '/' > out 2> err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Exercise '-name /' in POSIX environment.
POSIXLY_CORRECT=1 find / -maxdepth 0 -name '/' > out 2> err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1

# Exercise '-name /' with the -warn option.
find / -warn -maxdepth 0 -name '/' > out 2> err || fail=1
compare exp out || fail=1
compare /dev/null err || fail=1


Exit $fail
