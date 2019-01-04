#! /bin/sh
# Copyright (C) 2016-2019 Free Software Foundation, Inc.
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

# This test verifies that find invokes the given command for the
# multiple-argument sytax '-exec CMD {} +'.  Between FINDUTILS-4.2.12
# and v4.6.0, find(1) would have failed to execute CMD another time
# if there was only one last single file argument.

testname="$(basename $0)"

. "${srcdir}"/binary_locations.sh

# Require seq(1) for this test - which may not be available
# on some systems, e.g on some *BSDs.
seq 2 >/dev/null 2>&1 \
  || { echo "$testname: required utility 'seq' missing" >&2; exit 77; }

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

# Define the nicest compare available (borrowed from gnulib).
if diff_out_=`exec 2>/dev/null; diff -u "$0" "$0" < /dev/null` \
   && diff -u Makefile "$0" 2>/dev/null | grep '^[+]#!' >/dev/null; then
  # diff accepts the -u option and does not (like AIX 7 'diff') produce an
  # extra space on column 1 of every content line.
  if test -z "$diff_out_"; then
    compare () { diff -u "$@"; }
  else
    compare ()
    {
      if diff -u "$@" > diff.out; then
        # No differences were found, but Solaris 'diff' produces output
        # "No differences encountered". Hide this output.
        rm -f diff.out
        true
      else
        cat diff.out
        rm -f diff.out
        false
      fi
    }
  fi
elif diff_out_=`exec 2>/dev/null; diff -c "$0" "$0" < /dev/null`; then
  if test -z "$diff_out_"; then
    compare () { diff -c "$@"; }
  else
    compare ()
    {
      if diff -c "$@" > diff.out; then
        # No differences were found, but AIX and HP-UX 'diff' produce output
        # "No differences encountered" or "There are no differences between the
        # files.". Hide this output.
        rm -f diff.out
        true
      else
        cat diff.out
        rm -f diff.out
        false
      fi
    }
  fi
elif cmp -s /dev/null /dev/null 2>/dev/null; then
  compare () { cmp -s "$@"; }
else
  compare () { cmp "$@"; }
fi

DIR='RashuBug'
# Name of the CMD to execute: the file name must be 6 characters long
# (to trigger the bug in combination with the test files).
CMD='tstcmd'

# Create test files.
make_test_data() {
  # Create the CMD script and check that it works.
  mkdir "$DIR" 'bin' \
    && printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$@"' > "bin/$CMD" \
    && chmod +x "bin/$CMD" \
    && PATH="$PWD/bin:$PATH" \
    && [ "$( "${ftsfind}" bin -maxdepth 0 -exec "$CMD" '{}' + )" = 'bin' ] \
    || return 1

  # Create expected output file - also used for creating the test data.
  { seq -f "${DIR}/abcdefghijklmnopqrstuv%04g" 901 &&
    seq -f "${DIR}/abcdefghijklmnopqrstu%04g" 902 3719
  } > exp2 \
    && LC_ALL=C sort exp2 > exp \
    && rm exp2 \
    || return 1

  # Create test files, and check if test data has been created correctly.
  xargs touch < exp \
    && [ -f "${DIR}/abcdefghijklmnopqrstu3719" ] \
    && [ 3719 = $( "${ftsfind}" "$DIR" -type f | wc -l ) ] \
    || return 1
}

set -x
tmpdir="$(mktemp -d)" \
  && cd "$tmpdir" \
  && make_test_data "${tmpdir}" \
  || die "FAIL: failed to set up the test in ${tmpdir}"

fail=0
for exe in "${ftsfind}" "${oldfind}"; do
  "$exe" "$DIR" -type f -exec "$CMD" '{}' + > out || fail=1
  LC_ALL=C sort out > out2 || fail=1
  compare exp out2 || fail=1
done

cd ..
rm -rf "${tmpdir}" || exit 1
exit $fail
