#! /bin/sh
# Copyright (C) 2016 Free Software Foundation, Inc.
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
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# This test verifies that find refuses the internal -noop, ---noop option.
# Between findutils-4.3.1 and 4.6, find dumped core ($? = 139).

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

set -x
tmpdir="$(mktemp -d)" \
  && cd "$tmpdir" \
  || die "FAIL: failed to set up the test in ${tmpdir}"

fail=0
# Exercise both the previous name of the pseudo-option '-noop',
# and the now renamed '---noop' option for both find executables.
for exe in "${ftsfind}" "${oldfind}"; do
  for opt in 'noop' '--noop'; do
    out="${exe}${opt}.out"
    err="${exe}${opt}.err"
    returns_ 1 "$exe" "-${opt}" >"$out" 2> "$err" || fail=1
    compare /dev/null "$out" || fail=1
    grep "find: unknown predicate .-${opt}." "$err" \
      || { cat "$err"; fail=1; }
  done
done

cd ..
rm -rf "$tmpdir" || exit 1
exit $fail
