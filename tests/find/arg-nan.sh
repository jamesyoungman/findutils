#!/bin/sh
# Ensure 'not-a-number' diagnostic for NAN arguments.

# Copyright (C) 2023-2024 Free Software Foundation, Inc.

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

# Expect no output.
> exp || framework_failure_

for o in used amin cmin mmin atime ctime mtime; do
  find -$o NaN > outid not-a-number argument >out 2>err && fail=1
  compare exp out || fail=1
  grep -F 'find: invalid not-a-number argument:' err \
    || { cat err; fail=1; }
done

Exit $fail
