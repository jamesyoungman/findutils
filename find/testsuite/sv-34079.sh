#! /bin/sh
# Copyright (C) 2011-2019 Free Software Foundation, Inc.
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

# This test verifies that find does not have excessive memory consumption
# even for large directories.   It's not executed by default; it will only
# run if the environment variable RUN_VERY_EXPENSIVE_TESTS=yes is set.

testname="$(basename $0)"

. "${srcdir}"/binary_locations.sh

skip_() { # TODO factor out to a central place.
  echo "$testname: $@" >&2
  exit 77;
}

framework_failure_() { # TODO factor out to a central place.
  echo "$testname: error during test set-up" >&2
  exit 99;
}

very_expensive_() { # TODO factor out to a central place.
  if test "$RUN_VERY_EXPENSIVE_TESTS" != yes; then
    echo 'very expensive: disabled by default
This test is very expensive, so it is disabled by default.
To run it anyway, rerun make check with the RUN_VERY_EXPENSIVE_TESTS
environment variable set to yes.  E.g.,

  env RUN_VERY_EXPENSIVE_TESTS=yes make check
' >&2
  exit 77
  fi
}
very_expensive_

# Require seq(1) for this test - which may not be available
# on some systems, e.g on some *BSDs.
seq -f "_%04g" 0 2 >/dev/null 2>&1 \
  || skip_ "required utility 'seq' missing"

# Get the number of free inodes on the file system of the given file/directory.
get_ifree_() {
  d="$1"
  d="$1"
  # Try GNU coreutils' stat.
  stat --format='%d' -f -- "$d" 2>/dev/null \
    && return 0

  # Fall back to parsing 'df -i' output.
  df -i -- "$d" \
  | awk '
      NR == 1 {  # Find ifree column.
        ifree = -1;
        for (i=1; i<=NF; i++) {
          n=tolower($i);
          if(n=="ifree" || n=="iavail") {
            ifree=i;
          }
        };
        if (ifree<=0) {
          print "failed to determine IFREE column in header: ", $0 | "cat 1>&2";
          exit 1;
        }
        next;
      }
    { print $ifree }
  ' \
  | grep .
}

make_test_data() {
  d="$1"
  (
    cd "$1" || framework_failure_
    echo "Creating test data in '$(pwd -P)' (this may take some time...)" >&2

    maxi=400; maxj=10000

    # Skip early if we know that there are too few free inodes.
    # Require some slack.
    free_inodes=$(get_ifree_ '.') \
      && test 0 -lt $free_inodes \
      && min_free_inodes=$(expr 12 \* $maxi \* $maxj / 10) \
      && { test $min_free_inodes -lt $free_inodes \
             || skip_ "too few free inodes on '.': $free_inodes;" \
                      "this test requires at least $min_free_inodes"; }

    for i in $(seq -f "%03g" 0 $maxi)
    do
      printf "\r${i}/${maxi}" >&2
      seq -f "${i}_%04g" 0 $maxj | xargs touch || skip_ "touch failed"
    done
    printf "\rTest files created.\n" >&2
  )
}

# Remove the temporary directory and exit with the incoming value of $?.
remove_outdir_ ()
{
  __st=$?
  rm -rf "${outdir}" || { test $__st = 0 && __st=1; }
  exit $__st
}

outdir=$(mktemp -d) || framework_failure_
trap remove_outdir_ 0

# Create some test files.
make_test_data "${outdir}" \
  || skip_ "failed to set up the test in '${outdir}'"

fail=0
# We don't check oldfind, as it uses savedir, meaning that
# it stores all the directory entries.  Hence the excessive
# memory consumption bug applies to oldfind even though it is
# not using fts.
for exe in "${ftsfind}" "${oldfind}"; do
  echo "Checking memory consumption of ${exe}..." >&2
  if ( ulimit -v 50000 && ${exe} "${outdir}" >/dev/null; ); then
    echo "Memory consumption of ${exe} is reasonable" >&2
  else
    echo "${exe}: memory consumption is too high"
    fail=1
  fi
done

exit $fail
