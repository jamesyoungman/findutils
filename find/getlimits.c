/* getlimits - print various platform dependent limits.
   Copyright (C) 2023-2026 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* Based on 'getlimits' of GNU coreutils, written by Pádraig Brady.
 * Stripped down to a minimal version by Bernhard Voelker.  */

#include <config.h>             /* sets _FILE_OFFSET_BITS=64 etc. */
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <stdint.h>

#include "system.h"
#include "intprops.h"

#ifndef UID_T_MAX
# define UID_T_MAX TYPE_MAXIMUM (uid_t)
#endif

#ifndef GID_T_MAX
# define GID_T_MAX TYPE_MAXIMUM (gid_t)
#endif

#ifndef MIN
# define MIN(a,b) (a<b?a:b)
#endif

/* Silence GCC 14.  */
#if 14 <= __GNUC__
# pragma GCC diagnostic ignored "-Wanalyzer-out-of-bounds"
#endif

/* Add one to the absolute value of the number whose textual
   representation is BUF + 1.  Do this in-place, in the buffer.
   Return a pointer to the result, which is normally BUF + 1, but is
   BUF if the representation grew in size.  */
static char const *
decimal_absval_add_one (char *buf)
{
  bool negative = (buf[1] == '-');
  char *absnum = buf + 1 + negative;
  char *p = absnum + strlen (absnum);
  absnum[-1] = '0';
  while (*--p == '9')
    *p = '0';
  ++*p;
  char *result = MIN (absnum, p);
  if (negative)
    *--result = '-';
  return result;
}


static void
check_add_one (const char *input, const char *expected)
{
  char buf[100];
  buf[0] = ' ';
  strcpy (&buf[1], input);
  const char *result = decimal_absval_add_one (buf);
  if (0 != strcmp (result, expected))
    {
      fprintf (stderr,
               "check_add_one: wrong output for [%s]; expected [%s], got [%s]\n",
               input, expected, result);
      exit (EXIT_FAILURE);
    }
}

static void
self_test (void)
{
  check_add_one ("0", "1");
  check_add_one ("1", "2");
  check_add_one ("9", "10");
  check_add_one ("10", "11");
  check_add_one ("94", "95");
  check_add_one ("199", "200");
  check_add_one ("999", "1000");
  check_add_one ("499999999999999999999999999999999",
                 "500000000000000000000000000000000");

  check_add_one ("-1", "-2");
  check_add_one ("-9", "-10");
  check_add_one ("-10", "-11");
  check_add_one ("-94", "-95");
  check_add_one ("-199", "-200");
  check_add_one ("-999", "-1000");
  check_add_one ("-499999999999999999999999999999999",
                 "-500000000000000000000000000000000");
}

int
main (int argc, char **argv)
{
  char limit[100];

  self_test ();

#define print_int(TYPE)                                      \
  sprintf (limit + 1, "%" "ju", (uintmax_t) TYPE##_MAX);     \
  printf (#TYPE"_MAX=%s\n", limit + 1);                      \
  printf (#TYPE"_OFLOW=%s\n", decimal_absval_add_one (limit))

  print_int (INT);
  print_int (UID_T);
  print_int (GID_T);

  return EXIT_SUCCESS;
}
