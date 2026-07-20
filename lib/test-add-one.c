/* test_add_one - tests for add_one.c
   Copyright (C) 2026 Free Software Foundation, Inc.

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

#include <config.h>


#include <stdlib.h>             /* EXIT_FAILURE, exit */
#include <stdio.h>              /* fprintf */
#include <string.h>             /* strcpy, strcmp */

#include "add-one.h"

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

int
main (int argc, char *argv[])
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

  return EXIT_SUCCESS;
}
