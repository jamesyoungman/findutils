#!/bin/sh
# Verify -user/-group allow UID/GID values as large as UID_T_MAX/GID_T_MAX

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

# The tests -user and -group assume their argument to be a user or group name,
# and fall back to UID/GID if a decimal integer.
# The following limits apply on a regular x86_64 GNU/Linux system:
#     INT_MAX=2147483647
#   UID_T_MAX=4294967295
#   GID_T_MAX=4294967295
# Until findutils-4.9, the number parsing was limited to INT_MAX, even if the
# data types uid_t/gid_t are larger on the actual system.
# Read the limits of the current system.
getlimits_

# Verify that -user/-group support UID/GID numbers until UID_T_MAX/GID_T_MAX.
find -user "$UID_T_MAX" >/dev/null 2>err || fail=1
compare /dev/null err || fail=1

find -group "$GID_T_MAX" >/dev/null 2>err || fail=1
compare /dev/null err || fail=1

# Verify that UID/GID numbers larger than UID_T_MAX/GID_T_MAX get rejected.
echo "find: invalid user name or UID argument to -user: '$UID_T_OFLOW'" >exp || framework_failure_
returns_ 1 find -user "$UID_T_OFLOW" -name enoent >/dev/null 2>err || fail=1
sed -i 's/^.*find/find/' err || framework_failure_
compare exp err || fail=1

echo "find: invalid group name or GID argument to -group: '$GID_T_OFLOW'" >exp || framework_failure_
returns_ 1 find -group "$GID_T_OFLOW" -name enoent >/dev/null 2>err || fail=1
sed -i 's/^.*find/find/' err || framework_failure_
compare exp err || fail=1

Exit $fail
