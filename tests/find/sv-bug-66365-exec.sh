#!/bin/sh
# Test that find -exec ... + treats the + as a terminator only when it
# immediately follows a {}.  See Savannah bug #66365.

# Copyright (C) 2024-2025 Free Software Foundation, Inc.

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

find . -prune -exec echo x{} + \; >| out
echo 'x. +' >| exp || framework_failure_
compare exp out || fail=1

Exit $fail
