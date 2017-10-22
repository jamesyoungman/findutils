#! /bin/sh
# Copyright (C) 2016-2017 Free Software Foundation, Inc.
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

# This test verifies find's behavior regarding comma-separated file
# type arguments to the -type/-xtype options.

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

# Check if the given file type is supported by find.
# Used for the file type compiled in conditionally: l,p,s,D)
find_supports_type() {
  "${ftsfind}" '.' -maxdepth 0 -type "$1"
}

# Create test files of all possible types (if possible):
# f,d,p,l,b,c,s,D, and a dangling symlink.
make_test_data() {
  d="$1"
  (
    cd "$1" || exit 1
    # regular file
    : > reg || exit 1
    # directory
    mkdir dir || exit 1
    # BLK device
    mknod blk b 0 0 || :  # ignore failure
    # CHR device
    mknod chr c 0 0 || :  # ignore failure

    # FIFO
    if [ $HAVE_FIFO = 1 ]; then
      mkfifo fifo || :  # ignore failure
    fi

    # Socket: try various ways to create one.
    if [ $HAVE_SOCK = 1 ]; then
      perl -e '
        use IO::Socket::UNIX;
        my $s = IO::Socket::UNIX->new (Type => SOCK_STREAM(), Local => "sock");'

      test -S sock \
        || python -c \
             "import socket as s;
              sock = s.socket(s.AF_UNIX);
              sock.bind('sock');
              "
      # Also the netcat family leaves the socket behind ...
      test -S sock \
        || { nc -lU sock & pid=$!; \
             sleep 1; kill $pid; wait $pid; }
      test -S sock \
        || { netcat -lU sock & pid=$!; \
             sleep 1; kill $pid; wait $pid; }
      # ...  while socat has to be forcefully killed.
      test -S sock \
        || { socat unix-listen:sock fd:2 & pid=$!; \
             sleep 1; kill -9 $!; wait $pid; }
    fi

    # Door: not that easy.
    if [ $HAVE_DOOR = 1 ]; then
      : # TODO
    fi

    # Symbolic links to all types, and a dangling one.
    if [ $HAVE_LINK = 1 ]; then
      test -f reg && ln -s reg reg-link
      test -d dir && ln -s dir dir-link
      test -b blk && ln -s blk blk-link
      test -c chr && ln -s chr chr-link
      test -S sock && ln -s sock sock-link
      test -p fifo && ln -s fifo fifo-link
      ln -s enoent dangling-link
    fi
  ) \
  || die "failed to set up the test in ${outdir}"
}

set -x
outdir="$(mktemp -d)" || die "FAIL: could not create a test directory."
all="${outdir}.all"
exp="${outdir}.exp"
out="${outdir}.out"
err="${outdir}.err"

# Check what file types are compiled into find(1).
find_supports_type l && HAVE_LINK=1 || HAVE_LINK=0
find_supports_type p && HAVE_FIFO=1 || HAVE_FIFO=0
find_supports_type s && HAVE_SOCK=1 || HAVE_SOCK=0
find_supports_type D && HAVE_DOOR=1 || HAVE_DOOR=0

# Create some test files.
make_test_data "${outdir}" \
  && "${ftsfind}" "${outdir}" -mindepth 1 > $all \
  && sort -o $all $all \
  || die "FAIL: failed to set up the test in ${outdir}"
# Just to see what's there.
"${ftsfind}" "${outdir}" -mindepth 1 -ls

fail=0
for exe in "${ftsfind}" "${oldfind}"; do

  # Negative tests first.  Expect the output to be empty.
  : > $exp

  # Ensure empty type arguments are rejected.
  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -type '' > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Arguments to -type should contain at least one letter' $err \
    || { cat $err; fail=1; }

  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -xtype '' > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Arguments to -xtype should contain at least one letter' $err \
    || { cat $err; fail=1; }

  # Ensure non-separated type arguments are rejected.
  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -type fd > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Must separate multiple arguments to -type' $err \
    || { cat $err; fail=1; }

  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -xtype fd > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Must separate multiple arguments to -xtype' $err \
    || { cat $err; fail=1; }

  # Ensure unterminated type list arguments are rejected.
  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -type f, > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Last file type in list argument to -type is missing' $err \
    ||  { cat $err; fail=1; }

  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -xtype f, > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Last file type in list argument to -xtype is missing' $err \
    ||  { cat $err; fail=1; }

  # Ensure duplicate entries in the type list arguments are rejected.
  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -type f,f > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Duplicate file type .* in the argument list to -type' $err \
    ||  { cat $err; fail=1; }

  returns_ 1 "${exe}" "${outdir}" -mindepth 1 -xtype f,f > $out 2> $err || fail=1
  compare $exp $out || fail=1
  grep 'Duplicate file type .* in the argument list to -xtype' $err \
    ||  { cat $err; fail=1; }

  # Continue with positive tests.
  # Files only
  grep -e '/reg$' $all > $exp
  "${exe}" "${outdir}" -type f > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  # Symbolic links only.
  if [ $HAVE_LINK = 1 ]; then

    grep -e 'link$' $all > $exp
    "${exe}" "${outdir}" -type l > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;

    grep -e 'dangling-link$' $all > $exp
    "${exe}" "${outdir}" -xtype l > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;
  fi

  # Files and directories.
  grep -e '/reg$' -e '/dir$' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -type f,d > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  grep -e '/reg' -e '/dir' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -xtype f,d > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  # Block devices.
  grep -e '/reg$' -e '/dir$' -e '/blk$' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -type b,f,d > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  grep -e '/reg' -e '/dir' -e '/blk' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -xtype b,f,d > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  # Character devices.
  grep -e '/reg$' -e '/dir$' -e '/chr$' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -type f,c,d > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  grep -e '/reg' -e '/dir' -e '/chr' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -xtype f,c,d > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  # FIFOs.
  if [ $HAVE_FIFO = 1 ]; then
    grep -e '/reg$' -e '/dir$' -e '/fifo$' $all > $exp
    "${exe}" "${outdir}" -mindepth 1 -type f,d,p > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;

    grep -e '/reg' -e '/dir' -e '/fifo' $all > $exp
    "${exe}" "${outdir}" -mindepth 1 -xtype f,d,p > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;
  fi

  # Sockets.
  if [ $HAVE_SOCK = 1 ]; then
    grep -e '/reg$' -e '/dir$' -e '/sock$' $all > $exp
    "${exe}" "${outdir}" -mindepth 1 -type f,d,s > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;

    grep -e '/reg' -e '/dir' -e '/sock' $all > $exp
    "${exe}" "${outdir}" -mindepth 1 -xtype f,d,s > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;
  fi

  # Symbolic links.
  if [ $HAVE_LINK = 1 ]; then

    grep -e '/reg$' -e 'link$' $all > $exp
    "${exe}" "${outdir}" -mindepth 1 -type f,l > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;

    grep -e '/reg' -e 'dangling-link$' $all > $exp
    "${exe}" "${outdir}" -mindepth 1 -xtype f,l > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;
  fi

  # -xtype: all but the dangling symlink.
  t='f,d,b,c'
  [ $HAVE_FIFO = 1 ] && t="$t,p"
  [ $HAVE_SOCK = 1 ] && t="$t,s"
  [ $HAVE_DOOR = 1 ] && t="$t,D"
  grep -v 'dangling-link$' $all > $exp
  "${exe}" "${outdir}" -mindepth 1 -xtype "$t" > $out || fail=1
  sort -o $out $out
  compare $exp $out || fail=1;

  # negation
  if [ $HAVE_LINK = 1 ]; then
    "${exe}" "${outdir}" -mindepth 1 -not -xtype l > $out || fail=1
    sort -o $out $out
    compare $exp $out || fail=1;
  fi

  # Finally: full list
  [ $HAVE_LINK = 1 ] && t="$t,l"
  "${exe}" "${outdir}" -mindepth 1 -type "$t" > $out || fail=1
  sort -o $out $out
  compare $all $out || fail=1;

  "${exe}" "${outdir}" -mindepth 1 -xtype "$t" > $out || fail=1
  sort -o $out $out
  compare $all $out || fail=1;
done

rm -rf "${outdir}" $all $exp $out $err || exit 1
exit $fail
