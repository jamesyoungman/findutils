#!/bin/sh
# Verify that find -used works.

# Copyright (C) 2020 Free Software Foundation, Inc.

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

# Create sample files with the access date D=1,3,5,7 days in the future.
for d in 1 3 5 7; do
  touch -a -d "$(date -d "$d day" '+%Y-%m-%d %H:%M:%S')" t$d \
    || skip_ "creating files with future timestamp failed"

  # Check with stat(1) the access (%X) vs. the status change time (%z).
  exp="$( expr 86400 '*' $d )" \
    && x="$( stat -c "%X" t$d )" \
    && z="$( stat -c "%Z" t$d )" \
    && tdiff="$( expr "$x" - "$z" )" \
    && test "$tdiff" -ge "$exp" \
    || skip_ "cannot verify timestamps of sample files"
done
# Create another sample file with timestamp now.
touch t0 \
  || skip_ "creating sample file failed"

stat -c "Name: %n  Access: %x  Change: %z" t? || : # ignore error.

# Verify the output for "find -used $d".  Use even number of days to avoid
# possibly strange effects due to atime/ctime precision etc.
for d in -8 -6 -4 -2 -0 0 2 4 6 8 +0 +2 +4 +6 +8; do
  echo "== testing: find -used $d"
  find . -type f -name 't*' -used $d > out2 \
    || fail=1
  LC_ALL=C sort out2 || framework_failure_
done > out

cat <<\EOF > exp || framework_failure_
== testing: find -used -8
./t0
./t1
./t3
./t5
./t7
== testing: find -used -6
./t0
./t1
./t3
./t5
== testing: find -used -4
./t0
./t1
./t3
== testing: find -used -2
./t0
./t1
== testing: find -used -0
== testing: find -used 0
== testing: find -used 2
== testing: find -used 4
== testing: find -used 6
== testing: find -used 8
== testing: find -used +0
./t1
./t3
./t5
./t7
== testing: find -used +2
./t3
./t5
./t7
== testing: find -used +4
./t5
./t7
== testing: find -used +6
./t7
== testing: find -used +8
EOF

compare exp out || { fail=1; cat out; }

Exit $fail
