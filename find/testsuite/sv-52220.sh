#! /bin/sh
# Copyright (C) 2017 Free Software Foundation, Inc.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#
# Verify that 'find -D' without further argument outputs an error diagnostic.
# Between FINDUTILS_4_3_1-1 and 4.6, find crashed on some platforms.

testname="$(basename $0)"

. "${srcdir}"/binary_locations.sh

die() {
  echo "$@" >&2
  exit 1
}

# This is used to simplify checking of the return value
# which is useful when ensuring a command fails as desired.
# I.e., just doing `command ... &&fail=1` will not catch
# a segfault in command for example.  With this helper you
# instead check an explicit exit code like
#   returns_ 1 command ... || fail
returns_ () {
  # Disable tracing so it doesn't interfere with stderr of the wrapped command
  { set +x; } 2>/dev/null

  local exp_exit="$1"
  shift
  "$@"
  test $? -eq $exp_exit && ret_=0 || ret_=1

  set -x
  { return $ret_; } 2>/dev/null
}

set -x

fail=0
# Exercise both find executables.
for exe in "${ftsfind}" "${oldfind}"; do
  e="$(basename "$exe")"
  err="${e}${opt}.err"
  returns_ 1 "$exe" -D >/dev/null 2> "$err" || fail=1
  grep -F "find: Missing argument after the -D option." "$err" \
    || { cat "$err"; fail=1; }
done

exit $fail
