#!/bin/sh
# Verify behavior for '-!', '-,', '-(', and '-)'.

# Copyright (C) 2025 Free Software Foundation, Inc.

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

# Versions before and including 4.10 accepted the above mentioned operator
# options (with a leading dash '-').
# Findutils 4.11 issues a warning.

cat <<\EOF > exp || framework_failure_
find: warning: operator '-(' (with leading dash '-') will no longer be accepted in future findutils releases!
find: warning: operator '-!' (with leading dash '-') will no longer be accepted in future findutils releases!
find: warning: operator '-,' (with leading dash '-') will no longer be accepted in future findutils releases!
find: warning: operator '-)' (with leading dash '-') will no longer be accepted in future findutils releases!
EOF

find '-(' '-!' -not -type c -, -type b '-)' 2>err || fail=1
cat err
compare exp err || fail=1

Exit $fail
