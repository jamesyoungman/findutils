# cfg.mk -- configuration file for the maintainer makefile provided by gnulib.
# Copyright (C) 2010-2019 Free Software Foundation, Inc.
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

# Ensure that each root-requiring test is run via the "check-root" rule.
sc_root_tests:
	@t1=sc-root.expected; t2=sc-root.actual;			\
	grep -nl '^ *require_root_$$' `$(VC_LIST) tests` |		\
	  sed 's|.*/tests/|tests/|' | sort > $$t1;			\
	for t in $(all_root_tests); do echo $$t; done | sort > $$t2;	\
	st=0; diff -u $$t1 $$t2 || st=1;				\
	rm -f $$t1 $$t2;						\
	exit $$st

# Ensure that all version-controlled test cases are listed in $(all_tests).
sc_tests_list_consistency:
	@bs="\\";							\
	test_extensions_rx=`echo $(TEST_EXTENSIONS)			\
	  | sed -e "s/ /|/g" -e "s/$$bs./$$bs$$bs./g"`;			\
	{								\
	  for t in $(all_tests); do echo $$t; done;			\
	  cd $(top_srcdir);						\
	  $(SHELL) build-aux/vc-list-files tests			\
	    | grep -Ev '^tests/init\.sh$$'				\
	    | $(EGREP) "$$test_extensions_rx\$$";			\
	} | sort | uniq -u | grep . && exit 1; :

# Ensure that all version-controlled test scripts are executable.
sc_tests_executable:
	@set -o noglob 2>/dev/null || set -f;				   \
	find_ext="-name '' "`printf -- "-o -name *%s " $(TEST_EXTENSIONS)`;\
	find $(srcdir)/tests \( $$find_ext \) \! -perm -u+x -print	   \
	  | { sed "s|^$(srcdir)/||"; git ls-files $(srcdir)/tests/; }	   \
	  | sort | uniq -d						   \
	  | sed -e "s/^/$(ME): Please make test executable: /" | grep .	   \
	    && exit 1; :

# Avoid :>file which doesn't propagate errors
sc_prohibit_colon_redirection:
	@cd $(srcdir)/tests && GIT_PAGER= git grep -n ': *>.*||' \
	  && { echo '$(ME): '"The leading colon in :> will hide errors" 1>&2; \
	       exit 1; }  \
	  || :

# Usage of error() with an exit constant, should instead use die(),
# as that avoids warnings and may generate better code, due to being apparent
# to the compiler that it doesn't return.
sc_die_EXIT_FAILURE:
	@cd $(srcdir) \
	  && GIT_PAGER= git grep -E 'error \(.*_(FAILURE|INVALID)' \
	       -- find lib locate xargs \
	  && { echo '$(ME): '"Use die() instead of error" 1>&2; \
	       exit 1; }  \
	  || :

sc_prohibit-skip:
	@prohibit='\|\| skip ' \
	halt='Use skip_ not skip' \
	  $(_sc_search_regexp)

# Disallow the C99 printf size specifiers %z and %j as they're not portable.
# The gnulib printf replacement does support them, however the printf
# replacement is not currently explicitly depended on by the gnulib error()
# module for example.  Also we use fprintf() in a few places to output simple
# formats but don't use the gnulib module as it is seen as overkill at present.
# We'd have to adjust the above gnulib items before disabling this.
sc_prohibit-c99-printf-format:
	@cd $(srcdir) \
	  && GIT_PAGER= git grep -n '%[0*]*[jz][udx]' -- "*/*.c" \
	  && { echo '$(ME): Use PRI*MAX instead of %j or %z' 1>&2; exit 1; } \
	  || :

# Ensure that tests don't use `cmd ... && fail=1` as that hides crashes.
# The "exclude" expression allows common idioms like `test ... && fail=1`
# and the 2>... portion allows commands that redirect stderr and so probably
# independently check its contents and thus detect any crash messages.
sc_prohibit_and_fail_1:
	@prohibit='&& fail=1'						\
	exclude='(returns_|stat|kill|test |EGREP|grep|compare|2> *[^/])' \
	halt='&& fail=1 detected. Please use: returns_ 1 ... || fail=1'	\
	in_vc_files='^tests/'						\
	  $(_sc_search_regexp)

# Ensure that env vars are not passed through returns_ as
# that was seen to fail on FreeBSD /bin/sh at least
sc_prohibit_env_returns:
	@prohibit='=[^ ]* returns_ '					\
	exclude='_ returns_ '						\
	halt='Passing env vars to returns_ is non portable'		\
	in_vc_files='^tests/'						\
	  $(_sc_search_regexp)

# Use framework_failure_, not the old name without the trailing underscore.
sc_prohibit_framework_failure:
	@prohibit='\<framework_''failure\>'				\
	halt='use framework_failure_ instead'				\
	  $(_sc_search_regexp)

# Prohibit the use of `...` in tests/.  Use $(...) instead.
sc_prohibit_test_backticks:
	@prohibit='`' in_vc_files='^tests/'				\
	halt='use $$(...), not `...` in tests/'				\
	  $(_sc_search_regexp)

# Ensure that compare is used to check empty files
# so that the unexpected contents are displayed
sc_prohibit_test_empty:
	@prohibit='test -s.*&&' in_vc_files='^tests/'			\
	halt='use `compare /dev/null ...`, not `test -s ...` in tests/'	\
	  $(_sc_search_regexp)

# Ensure that tests call the get_min_ulimit_v_ function if using ulimit -v
sc_prohibit_test_ulimit_without_require_:
	@cd $(srcdir) \
	  && (GIT_PAGER= git grep -l get_min_ulimit_v_ -- tests;	\
	      GIT_PAGER= git grep -l 'ulimit -v' -- tests)		\
	      | sort | uniq -u | grep . && { echo "$(ME): the above test(s)"\
	  " should match get_min_ulimit_v_ with ulimit -v" 1>&2; exit 1; } || :

# Ensure that tests call the cleanup_ function if using background processes
sc_prohibit_test_background_without_cleanup_:
	@cd $(srcdir) \
	  && (GIT_PAGER= git grep -El '( &$$|&[^&]*=\$$!)' -- tests; \
	      GIT_PAGER= git grep -l 'cleanup_()' -- tests | sed p)  \
	      | sort | uniq -u | grep . && { echo "$(ME): the above test(s)"\
	  " should use cleanup_ for background processes" 1>&2; exit 1; } || :

# Ensure that tests call the print_ver_ function for programs which are
# actually used in that test.
sc_prohibit_test_calls_print_ver_with_irrelevant_argument:
	@cd $(srcdir) \
	  && GIT_PAGER= git grep -w print_ver_ -- tests			\
	  | sed 's#:print_ver_##'					\
	  | { fail=0;							\
	      while read file name; do					\
		for i in $$name; do					\
		  grep -w "$$i" $$file|grep -vw print_ver_|grep -q .	\
		    || { fail=1;					\
			 echo "*** Test: $$file, offending: $$i." 1>&2; };\
		done;							\
	      done;							\
	      test $$fail = 0 || exit 1;				\
	    } || { echo "$(ME): the above test(s) call print_ver_ for"	\
		    "program(s) they don't use" 1>&2; exit 1; }

# Exempt the contents of any usage function from the following.
_continued_string_col_1 = \
s/^usage .*?\n}//ms;/\\\n\w/ and print ("$$ARGV\n"),$$e=1;END{$$e||=0;exit $$e}
# Ding any source file that has a continued string with an alphabetic in the
# first column of the following line.  We prohibit them because they usually
# trigger false positives in tools that try to map an arbitrary line number
# to the enclosing function name.  Of course, very many strings do precisely
# this, *when they are part of the usage function*.  That is why we exempt
# the contents of any function named "usage".
sc_prohibit_continued_string_alpha_in_column_1:
	@perl -0777 -ne '$(_continued_string_col_1)' \
	    $$($(VC_LIST_EXCEPT) | grep '\.[ch]$$') \
	  || { echo '$(ME): continued string with word in first column' \
		1>&2; exit 1; } || :
# Use this to list offending lines:
# git ls-files |grep '\.[ch]$' | xargs \
#   perl -n -0777 -e 's/^usage.*?\n}//ms;/\\\n\w/ and print "$ARGV\n"' \
#     | xargs grep -A1 '\\$'|grep '\.[ch][:-][_a-zA-Z]'

# Enforce recommended preprocessor indentation style.
sc_preprocessor_indentation:
	@if cppi --version >/dev/null 2>&1; then			\
	  $(VC_LIST_EXCEPT) | grep '\.[ch]$$' | xargs cppi -a -c	\
	    || { echo '$(ME): incorrect preprocessor indentation' 1>&2;	\
		exit 1; };						\
	else								\
	  echo '$(ME): skipping test $@: cppi not installed' 1>&2;	\
	fi

exclude_file_name_regexp--sc_prohibit_test_backticks = \
  ^tests/(local\.mk|init\.sh)$$

# Now that we have better tests, make this the default.
export VERBOSE = yes

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
