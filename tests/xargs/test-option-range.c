/* test-xargs-option-range -- Verify correct handling of -L, -l, -n range
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
   along with this program.  If not, see <https://www.gnu.org/licenses/>.

   Written by James Youngman <jay@gnu.org>
*/

/* config.h must be included first. */
#include <config.h>

/* System headers */
#include <stdarg.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>           /* PRIuMAX */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>           /* waitpid() */
#include <unistd.h>             /* sleep() */
#include <stdint.h>             /* uintmax_t */

/* gnulib headers */
#include <error.h>
#include "intprops.h"
#include "inttostr.h"
#include "xalloc.h"

/* findutils headers */
#include "add-one.h"
#include "buildcmd.h"


static void
cleanup_argv (char **argv)
{
  for (size_t i = 0; argv[i]; ++i)
    {
      free (argv[i]);
    }
  free (argv);
}


static void
print_argv (char **argv)
{
  for (int i = 0; argv[i]; ++i)
    {
      printf ("argv[%d] = %s\n", i, argv[i]);
    }
}

static int
run_xargs_get_retval (int devnull_fd, ...)
{
  va_list ap;
  va_start (ap, devnull_fd);
  char **argv = xmalloc (sizeof (const char *));
  argv[0] = xstrdup ("xargs");
  int arg_count = 1;
  for (;;)
    {
      const char *s = va_arg (ap, const char *);
      argv = xrealloc (argv, (1 + arg_count) * sizeof (const char *));
      if (s)
        {
          argv[arg_count] = xstrdup (s);
        }
      else
        {
          argv[arg_count] = NULL;
          break;
        }
      ++arg_count;
    }
  va_end (ap);

  pid_t child;
  int childstatus;
  printf ("Full xargs arguments:\n");
  print_argv (argv);

  fflush (stderr);
  fflush (stdout);

  while ((child = fork ()) < 0 && errno == EAGAIN)
    {
      sleep (1);
    }
  if (child == -1)
    {
      error (EXIT_FAILURE, errno, "cannot fork");
       /*NOTREACHED*/ return -42;
    }
  else if (child == 0)
    {
      /* We are the child. */
      /* redirect stdin from /dev/null */
      close (0);
      int newfd = dup (devnull_fd);
      if (-1 == newfd)
        {
          int saved_errno = errno;
          close (devnull_fd);
          error (EXIT_FAILURE, saved_errno, "failed to dup2 /dev/null");
        }
      if (close (devnull_fd) < 0)
        {
          error (EXIT_FAILURE, errno, "failed to close /dev/null");
        }
      execvp ("xargs", argv);
      error (EXIT_FAILURE, errno, "failed to run xargs");
       /*NOTREACHED*/ return -43;
    }

  /* In the parent. */
  cleanup_argv (argv);
  waitpid (child, &childstatus, 0);
  if (WIFSIGNALED (childstatus))
    {
      error (EXIT_FAILURE, 0, "xargs exited due to a fatal signal");
    }
  else if (!WIFEXITED (childstatus))
    {
      error (EXIT_FAILURE, 0, "xargs did not exit normally");
    }
  return WEXITSTATUS (childstatus);
}

static void
run_xargs_expect_retval (int devnull_fd, int retval_min, int retval_max,
                         const char *option, const char *optval)
{
  if (optval)
    {
      printf ("Testing xargs with option and value %s %s\n", option, optval);
    }
  else
    {
      printf ("Testing xargs with option %s\n", option);
    }
  int retval = run_xargs_get_retval (devnull_fd, option, optval, NULL);
  fputs ("Expecting return value ", stdout);
  if (retval_min == retval_max)
    {
      printf ("of %d", retval_min);
    }
  else
    {
      printf ("between %d and %d (inclusive)", retval_min, retval_max);
    }
  printf ("; actual return value was %d\n", retval);
  if (retval < retval_min)
    {
      error (EXIT_FAILURE, 0,
             "FAILED; actual return value %d < minimum value %d\n",
             retval, retval_min);
    }
  else if (retval > retval_max)
    {
      error (EXIT_FAILURE, 0,
             "FAILED; actual return value %d > maximum value %d\n",
             retval, retval_max);
    }
  else
    {
      printf ("success: exit value %d is acceptable.\n", retval);
    }
}


static char *
value_to_str (uintmax_t val, bool add_one)
{
  char buf[1 + INT_BUFSIZE_BOUND (uintmax_t)];
  char *s = umaxtostr (val, buf + 1);
  if (add_one)
    {
      return xstrdup (decimal_absval_add_one (s - 1));
    }
  return xstrdup (s);
}

static void
check_xargs_for_limiting_joined_option_value (int devnull_fd,
                                              const char *option,
                                              uintmax_t limit_value)
{
  char *inrange = value_to_str (limit_value, false);
  char *joined = xmalloc (strlen (inrange) + 2);
  sprintf (joined, "-l%s", inrange);
  printf ("Testing xargs with in-range option value %s\n", joined);
  run_xargs_expect_retval (devnull_fd, 0, 0, joined, NULL);
  free (joined);
  free (inrange);

  char *toobig = value_to_str (limit_value, true);
  char *toobig_joined = xmalloc (strlen (toobig) + 2);
  sprintf (toobig_joined, "-l%s", toobig);
  printf ("Testing xargs with out-of--range option value %s\n",
          toobig_joined);
  run_xargs_expect_retval (devnull_fd, 1, 125, toobig_joined, NULL);
  free (toobig);
  free (toobig_joined);
}

static void
check_xargs_for_limiting_option_value (int devnull_fd,
                                       const char *option,
                                       uintmax_t limit_value)
{
  char *inrange = value_to_str (limit_value, false);
  printf ("Testing xargs with in-range option value %s %s\n",
          option, inrange);
  run_xargs_expect_retval (devnull_fd, 0, 0, option, inrange);
  free (inrange);
  putchar ('\n');


  char *toobig = value_to_str (limit_value, true);
  printf ("Testing xargs with out-of-range option value %s %s\n",
          option, toobig);
  run_xargs_expect_retval (devnull_fd, 1, 125, option, toobig);
  free (toobig);
}


static void
check_xargs_s_option_accepts_val (int devnull_fd, uintmax_t value,
                                  bool add_one)
{
  char *val = value_to_str (value, add_one);
  run_xargs_expect_retval (devnull_fd, 0, 0, "-s", val);
  free (val);
}

static void
check_xargs_s_option (int devnull_fd)
{
  /* Any positive value should be accepted (even if it is silently clamped) */
  check_xargs_s_option_accepts_val (devnull_fd, UINTMAX_MAX, false);
  check_xargs_s_option_accepts_val (devnull_fd, UINTMAX_MAX, true);

  /* Very small values for -s are valid but will fail as there is not
   * enough room for the utility name (which is echo by default).  Zero
   * would be accepted but it would not work (as all command lines
   * would be too long) so we don't test zero.
   */
  run_xargs_expect_retval (devnull_fd, 0, 0, "-s", "6");

  /* We should reject negative values */
  run_xargs_expect_retval (devnull_fd, 1, 1, "-s", "-1");
}

int
main (int argc, char *argv[])
{
  int devnull_fd = open ("/dev/null", O_RDONLY);
  if (devnull_fd < 0)
    {
      error (EXIT_FAILURE, errno, "cannot open /dev/null");
    }

  run_xargs_get_retval (devnull_fd, "--version", NULL);
  putchar ('\n');

  check_xargs_for_limiting_option_value (devnull_fd, "-L",
                                         BC_LINES_PER_EXEC_MAX);
  check_xargs_for_limiting_joined_option_value (devnull_fd, "-l",
                                                BC_LINES_PER_EXEC_MAX);
  check_xargs_for_limiting_joined_option_value (devnull_fd, "-n",
                                                BC_ARGS_PER_EXEC_MAX);
  check_xargs_s_option (devnull_fd);
  return EXIT_SUCCESS;
}
