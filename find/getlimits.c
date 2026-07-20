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

/* Always include config.h first. */
#include <config.h>             /* sets _FILE_OFFSET_BITS=64 etc. */

/* system headers */
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <stdint.h>

/* gnulib headers */
#include "intprops.h"
#include "inttostr.h"

/* findutils headers */
#include "add-one.h"
#include "system.h"
#include "intprops.h"

#ifndef UID_T_MAX
# define UID_T_MAX TYPE_MAXIMUM (uid_t)
#endif

#ifndef GID_T_MAX
# define GID_T_MAX TYPE_MAXIMUM (gid_t)
#endif

int
main (int argc, char **argv)
{
  char *printable;
  char limit[1 + INT_BUFSIZE_BOUND (uintmax_t)];

#define print_int(TYPE)                                      \
  printable = umaxtostr((uintmax_t) TYPE##_MAX, limit+1);    \
  printf (#TYPE"_MAX=%s\n", printable);                      \
  printf (#TYPE"_OFLOW=%s\n", decimal_absval_add_one (printable-1))

  print_int (INT);
  print_int (UID_T);
  print_int (GID_T);

  return EXIT_SUCCESS;
}
