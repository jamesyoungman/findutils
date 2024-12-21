#!/bin/sh
# Verify that -ignore_readdir_race properly handles vanished files/directories.

# Copyright (C) 2024 Free Software Foundation, Inc.

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

# Require seq(1) for this test - which may not be available
# on some systems, e.g on some *BSDs.
seq 2 >/dev/null 2>&1 \
  || skip_ "required utility 'seq' missing"

mkdir testdir || framework_failure_

# Constantly create and remove a subdirectory in the background.
# Disable shell debugging for this part.
# Terminate the background process later again.
endless_mkdir_rmdir() {
  { set +x; } 2>/dev/null
  while :; do mkdir testdir/foo; rmdir testdir/foo; done
}
endless_mkdir_rmdir & pid=$!
cleanup_() { kill $pid 2>/dev/null && wait $pid; }

# Now run find(1) many times.
> err
for f in $(seq 1000); do \
  find testdir -ignore_readdir_race -ls 2>> err || fail=1; \
done > out

test 1000 -le $( wc -l < out ) || fail=1
compare /dev/null err || fail=1

Exit $fail
