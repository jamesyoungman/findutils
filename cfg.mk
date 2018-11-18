# cfg.mk -- configuration file for the maintainer makefile provided by gnulib.
# Copyright (C) 2010-2018 Free Software Foundation, Inc.
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

manual_title = Finding Files
# We need to pass the -I option to gendocs so that the texinfo tools
# can find dblocation.texi, which is a generated file.
gendocs_options_ = -s find.texi -I $(abs_builddir)/doc

local-checks-to-skip :=

# Errors I think are too picky anyway.
local-checks-to-skip += sc_error_message_period sc_error_message_uppercase \
	sc_file_system

exclude_file_name_regexp--sc_obsolete_symbols = build-aux/src-sniff\.py
exclude_file_name_regexp--sc_space_tab = \
	xargs/testsuite/(inputs/.*\.xi|xargs.(gnu|posix|sysv)/.*\.xo)|find/testsuite/test_escapechars\.golden$$

# Skip sc_two_space_separator_in_usage because it reflects the requirements
# of help2man.   It gets run on files that are not help2man inputs, and in
# any case we don't use help2man at all.
local-checks-to-skip += sc_two_space_separator_in_usage

# Comparing tarball sizes compressed using different xz presets, we see that
# an -7e-compressed tarball has the same size as the -9e-compressed one.
# Using -7e is preferred, since that lets the decompression process use less
# memory (19MiB rather than 67MiB).
# $ pkg=x; out=x.out; \
#     printf "%3s %8s %6s %s\n" OPT PKGSIZE RESMEM TIME; \
#     for i in {5..9}{e,}; do \
#       xz -$i < findutils-4.7.0-git.tar > $pkg; \
#       s=$(wc -c < $pkg); \
#       env time -v xz -d - < $pkg >/dev/null 2> $out; \
#       m=$(sed -n '/Maximum resident set size/{s/^.*: //;p;q}' < $out); \
#       t=$(sed -n '/User time/{s/^.*: //;p;q}' < $out); \
#       printf "%3s %8d %6d %s\n" "$i" "$s" "$m" "$t"; \
#     done | sort -k2,2nr
#OPT  PKGSIZE RESMEM TIME
#  5  1994080  10484 0.12
#  6  1956672  10564 0.11
# 5e  1935660  10456 0.11
# 6e  1930628  10396 0.11
#  8  1881520  34880 0.11
#  9  1881520  67732 0.12
#  7  1881496  18564 0.11
# 7e  1855268  18584 0.11
# 8e  1855268  35016 0.11
# 9e  1855268  67844 0.11
export XZ_OPT = -7e

# Some test inputs/outputs have trailing blanks.
exclude_file_name_regexp--sc_trailing_blank = \
 ^COPYING|(po/.*\.po)|(find/testsuite/(test_escapechars\.golden|find.gnu/printf\.xo))|(xargs/testsuite/(inputs/.*\.xi|xargs\.(gnu|posix|sysv)/.*\.(x[oe])))$$

exclude_file_name_regexp--sc_prohibit_empty_lines_at_EOF = \
	^(.*/testsuite/.*\.(xo|xi|xe))|COPYING|doc/regexprops\.texi|m4/order-(bad|good)\.bin$$
exclude_file_name_regexp--sc_bindtextdomain = \
	^lib/(regexprops|test_splitstring)\.c$$
exclude_file_name_regexp--sc_prohibit_always_true_header_tests = \
	^(build-aux/src-sniff\.py)|ChangeLog$$
exclude_file_name_regexp--sc_prohibit_test_minus_ao = \
	^(ChangeLog)|((find|locate|xargs)/testsuite/.*\.exp)$$
exclude_file_name_regexp--sc_prohibit_doubled_word = \
	^(xargs/testsuite/xargs\.sysv/iquotes\.xo)|ChangeLog|po/.*\.po$$
exclude_file_name_regexp--sc_program_name = \
	^lib/test_splitstring\.c$$

# Suppress syntax-check failure regarding possibly evil strncpy use for now.
exclude_file_name_regexp--sc_prohibit_strncpy = ^(find/print.c|lib/buildcmd.c)$$

# sc_texinfo_acronym: perms.texi from coreutils uses @acronym{GNU}.
exclude_file_name_regexp--sc_texinfo_acronym = doc/perm\.texi

# List syntax-check exemptions.
exclude_file_name_regexp--sc_bindtextdomain = \
  ^(locate/frcode|lib/regexprops|lib/test_splitstring)\.c$$

# sc_prohibit_strcmp is broken because it gives false positives for
# cases where neither argument is a string literal.
local-checks-to-skip += sc_prohibit_strcmp

# Usage of error() with an exit constant, should instead use die(),
# as that avoids warnings and may generate better code, due to being apparent
# to the compiler that it doesn't return.
sc_die_EXIT_FAILURE:
	@GIT_PAGER= git grep -E 'error \(.*_(FAILURE|INVALID)' \
	  -- find lib locate xargs \
	  && { echo '$(ME): '"Use die() instead of error" 1>&2; \
	       exit 1; }  \
	  || :

# Enforce recommended preprocessor indentation style.
sc_preprocessor_indentation:
	@if cppi --version >/dev/null 2>&1; then			\
	  $(VC_LIST_EXCEPT) | grep '\.[ch]$$' | xargs cppi -a -c	\
	    || { echo '$(ME): incorrect preprocessor indentation' 1>&2;	\
		exit 1; };						\
	else								\
	  echo '$(ME): skipping test $@: cppi not installed' 1>&2;	\
	fi

# During 'make update-copyright', convert a sequence with gaps to the minimal
# containing range.
update-copyright-env = \
  UPDATE_COPYRIGHT_FORCE=1 \
  UPDATE_COPYRIGHT_USE_INTERVALS=2 \
  UPDATE_COPYRIGHT_MAX_LINE_LENGTH=79

# NEWS hash.  We use this to detect unintended edits to bits of the NEWS file
# other than the most recent section.   If you do need to retrospectively update
# a historic section, run "make update-NEWS-hash", which will then edit this file.
old_NEWS_hash := d41d8cd98f00b204e9800998ecf8427e
