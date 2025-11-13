#! /bin/sh
# Copyright (C) 2007-2025 Free Software Foundation, Inc.
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

case "${GROFF}" in
    :)
	echo "groff is not installed, so we cannot check manual pages.  Continuing without checking them." >&2
	exit 0
	;;
    "")
	echo "The GROFF environment is not set; this is normally set when invoking this command from the Makefile; assuming GNU groff is at 'groff'." >&2
	GROFF=groff
	;;
    *)
	;;
esac

srcdir="$1" ; shift

fixed_width_context_message_without_newline() {
    printf '%-45s (%15s): ' "$1" "$2"
}


check_manpages_format_without_error_messages() {
    for manpage
    do
	fixed_width_context_message_without_newline \
		 'check_manpages_format_without_error_messages' "${manpage}"
	messages="$( ${GROFF} -t -man ${srcdir}/${manpage} 2>&1 >/dev/null )"
	if test -z "$messages"
	then
	    printf 'OK\n'
	else
	    printf 'FAILED\n%s\n' "$messages" >&2
	    return 1
	fi
    done
    return 0
}

check_manpages_with_groff_checkstyle_2() {
    for manpage
    do
	fixed_width_context_message_without_newline \
		 'check_manpages_with_groff_checkstyle_2' "${manpage}"
	messages="$( ${GROFF} -t -z -ww -rCHECKSTYLE=2 -man ${srcdir}/${manpage} 2>&1 )"
	if test -z "$messages"
	then
	    printf 'OK\n'
	else
	    printf 'FAILED\n%s\n' "$messages" >&2
	    return 1
	fi
    done
    return 0
}

rv=0
check_manpages_format_without_error_messages "$@" &&
check_manpages_with_groff_checkstyle_2       "$@"
