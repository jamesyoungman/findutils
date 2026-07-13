/* listfile.c -- display a long listing of a file
   Copyright (C) 1991-2026 Free Software Foundation, Inc.

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
*/
/* config.h must be included first. */
#include <config.h>

/* system headers. */
#include <alloca.h>
#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <inttypes.h>           /* PRIuMAX */
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>             /* for readlink() */

/* gnulib headers. */
#include "areadlink.h"
#include "filemode.h"
#include "human.h"
#include "inttostr.h"
#include "mbswidth.h"
#include "idcache.h"
#include "pathmax.h"
#include "stat-size.h"

/* find headers. */
#include "system.h"
#include "listfile.h"

/* Since major is a function on SVR4, we can't use `ifndef major'.  */
#ifdef MAJOR_IN_MKDEV
# include <sys/mkdev.h>
#else
# ifdef MAJOR_IN_SYSMACROS
#  include <sys/sysmacros.h>
# else
#  ifndef major                 /* Might be defined in sys/types.h.  */
#   define major(dev)  (((dev) >> 8) & 0xff)
#   define minor(dev)  ((dev) & 0xff)
#  endif
# endif
#endif


static bool print_name (register const char *p, FILE * stream,
                        int literal_control_chars);

/* We have some minimum field sizes, though we try to widen these fields on systems
 * where we discover examples where the field width we started with is not enough. */
static int inode_number_width = 9;
static int block_size_width = 6;
static int nlink_width = 3;
static int owner_width = 8;
static int group_width = 8;
static int symbolic_mode_width = 10;
/* We don't print st_author even if the system has it. */
static int major_device_number_width = 3;
static int minor_device_number_width = 3;
static int file_device_or_size_width = 8;
static int time_stamp_width = 12;

static bool
update_width_if_success (int chars_out, int *width)
{
  if (chars_out >= 0)
    {
      if (*width < chars_out)
        *width = chars_out;
      return true;
    }
  return false;
}



static bool
print_num (FILE *stream, unsigned long num, int *width)
{
  return update_width_if_success (fprintf (stream, "%*lu", *width, num),
                                  width);
}


static bool
print_block_count (const struct stat *statp,
                   int output_block_size, FILE *stream)
{
  char hbuf[LONGEST_HUMAN_READABLE + 1];
  int chars_out = fprintf (stream, "%*s",
                           block_size_width,
                           human_readable ((uintmax_t) ST_NBLOCKS (*statp),
                                           hbuf,
                                           human_ceiling,
                                           ST_NBLOCKSIZE, output_block_size));
  return update_width_if_success (chars_out, &block_size_width);
}

static bool
print_file_size (const struct stat *statp,
                 int output_block_size, FILE *stream)
{
  char hbuf[LONGEST_HUMAN_READABLE + 1];
  const int blocksize = output_block_size < 0 ? output_block_size : 1;
  int chars_out = fprintf (stream, "%*s",
                           file_device_or_size_width,
                           human_readable ((uintmax_t) statp->st_size,
                                           hbuf,
                                           human_ceiling,
                                           1, blocksize));
  return update_width_if_success (chars_out, &file_device_or_size_width);
}

static bool
print_file_inum (const struct stat *statp, FILE *stream)
{
  char umaxtostr_buf[INT_BUFSIZE_BOUND (uintmax_t)];
  int chars_out = fprintf (stream, "%*s", inode_number_width,
                           umaxtostr (statp->st_ino, umaxtostr_buf));
  return update_width_if_success (chars_out, &inode_number_width);
}


static bool
print_struct_tm (const struct tm *when_local,
                 time_t file_timestamp, time_t current_time, FILE *stream)
{
  char init_bigbuf[256];
  char *buf = init_bigbuf;
  size_t bufsize = sizeof init_bigbuf;

  /* Use strftime rather than ctime, because the former can produce
     locale-dependent names for the month (%b).

     Output the year if the file is fairly old or in the future.
     POSIX says the cutoff is 6 months old;
     approximate this by 6*30 days.
     Allow a 1 hour slop factor for what is considered "the future",
     to allow for NFS server/client clock disagreement.  */
  char const *fmt =
    ((current_time - 6 * 30 * 24 * 60 * 60 <= file_timestamp
      && file_timestamp <= current_time + 60 * 60)
     ? "%b %e %H:%M" : "%b %e  %Y");

  while (!strftime (buf, bufsize, fmt, when_local))
    buf = alloca (bufsize *= 2);

  int chars_out = fprintf (stream, "%*s", time_stamp_width, buf);
  return update_width_if_success (chars_out, &time_stamp_width);
}


/* Print a time which cannot be represented as a local time,
   as a (presumably huge) integer number of seconds.  */
static bool
print_raw_timestamp (time_t time_val, FILE *stream)
{
  char intmaxtostr_buf[1 + INT_BUFSIZE_BOUND (intmax_t)];

  char const *num = imaxtostr (time_val, intmaxtostr_buf);
  return update_width_if_success (fprintf (stream, "%s", num),
                                  &time_stamp_width);
}


static bool
print_file_mtime (const struct stat *statp, time_t current_time, FILE *stream)
{
  struct tm const *when_local = localtime (&statp->st_mtime);
  if (when_local)
    {
      return print_struct_tm (when_local, statp->st_mtime, current_time,
                              stream);
    }
  else
    {
      /* The time cannot be represented as a local time; print it as
         an integer.  */
      return print_raw_timestamp (statp->st_mtime, stream);
    }
}


static bool
print_file_owner (const struct stat *statp, FILE *stream)
{
  char const *user_name = getuser (statp->st_uid);
  int chars_out;
  if (user_name)
    {
      int len = mbswidth (user_name, 0);
      if (len > owner_width)
        owner_width = len;
      chars_out = fprintf (stream, "%-*s", owner_width, user_name);
    }
  else
    {
      chars_out = fprintf (stream, "%-8lu", (unsigned long) statp->st_uid);
    }
  return update_width_if_success (chars_out, &owner_width);
}

static bool
print_file_group (const struct stat *statp, FILE *stream)
{
  char const *group_name = getgroup (statp->st_gid);
  int chars_out;
  if (group_name)
    {
      int len = mbswidth (group_name, 0);
      if (len > group_width)
        group_width = len;
      chars_out = fprintf (stream, "%-*s", group_width, group_name);
    }
  else
    {
      chars_out = fprintf (stream, "%-*lu",
                           group_width, (unsigned long) statp->st_gid);
    }
  return update_width_if_success (chars_out, &group_width);
}

static void
delete_single_final_space_if_present (char *s)
{
  size_t len = strlen (s);
  if (0 == len)
    return;
  if (s[len - 1] == ' ')
    s[len - 1] = 0;
}


static bool
print_file_mode (const struct stat *statp, FILE *stream)
{
  char modebuf[12];
  modebuf[0] = 0;
#if HAVE_ST_DM_MODE
  /* Cray DMF: look at the file's migrated, not real, status */
  strmode (statp->st_dm_mode, modebuf);
#else
  strmode (statp->st_mode, modebuf);
#endif
  /* modebuf normally includes a trailing space the space between the
   * mode and the number of links, as the POSIX "optional alternate
   * access method flag".  Alternatively though the last character may
   * be non-blank.  If it is blank we delete it (POSIX 2024 ls has an
   * empty string rather than a single blank if there is no alternate
   * access method).
   */
  delete_single_final_space_if_present (modebuf);
  return update_width_if_success (fprintf (stream, "%-*s",
                                           symbolic_mode_width,
                                           modebuf), &symbolic_mode_width);
}

static bool
format_dev_major_or_minor (char *buf,
                           size_t buf_siz,
                           unsigned long dev_maj_or_min, int *max_width)
{
  const char *format = "%*lu";
  int needed = snprintf (NULL, 0, format, *max_width, dev_maj_or_min);
  if (needed >= buf_siz || *max_width > buf_siz)
    {
      /* This is in effect an assertion failure, but we still want to
       * perform the check when _NDEBUG is defined, otherwise we get a
       * compiler warning.
       */
      error (1, 0,
             "device number output buffer is too short to output a field with width %d (want %d, have "
             "%" PRIuMAX ")", *max_width, needed, (uintmax_t) buf_siz);
      return false;
    }
  int output_size = sprintf (buf, format, *max_width, dev_maj_or_min);
  if (output_size == buf_siz || output_size == 0)
    {
      /* Truncated output; result is not terminated. */
      return false;
    }
  --output_size;                /* discount the terminating null character */
  if (output_size > *max_width)
    {
      *max_width = output_size;
    }
  return true;
}



static bool
print_file_device (const struct stat *statp, FILE *stream)
{
  char dev_maj_buf[INT_BUFSIZE_BOUND (unsigned long)];
  char dev_min_buf[INT_BUFSIZE_BOUND (unsigned long)];
  const char *separator = "";

#ifdef HAVE_STRUCT_STAT_ST_RDEV
  separator = ",";
  if (!format_dev_major_or_minor (dev_maj_buf, sizeof (dev_maj_buf),
                                  (unsigned long) major (statp->st_rdev),
                                  &major_device_number_width))
    return false;
  if (!format_dev_major_or_minor (dev_min_buf, sizeof (dev_min_buf),
                                  (unsigned long) minor (statp->st_rdev),
                                  &minor_device_number_width))
    return false;
#else
  dev_maj_buf[0] = 0;
  dev_min_buf[0] = 0;
#endif
  int chars_out = fprintf (stream, "%*s%-2s%*s",
                           major_device_number_width,
                           dev_maj_buf,
                           separator,
                           minor_device_number_width,
                           dev_min_buf);
  return update_width_if_success (chars_out, &file_device_or_size_width);
}

static bool
print_file_dev_or_size (const struct stat *statp,
                        int output_block_size, FILE *stream)
{
  if (S_ISCHR (statp->st_mode) || S_ISBLK (statp->st_mode))
    {
      return print_file_device (statp, stream);
    }
  else
    {
      const int blocksize = output_block_size < 0 ? output_block_size : 1;
      return print_file_size (statp, blocksize, stream);
    }
}


static bool
print_link_count (const struct stat *statp, FILE *stream)
{
  /* This field used to end in a space, but the output of "ls"
     has only one space between the link count and the owner name,
     so we removed the trailing space.  Happily this also makes it
     easier to update nlink_width. */
  return print_num (stream, statp->st_nlink, &nlink_width);
}

static bool
print_file_link_target (const struct stat *statp,
                        int dir_fd,
                        const char *relname,
                        int literal_control_chars,
                        bool *issued_diagnostic, FILE *stream)
{
  char *linkname = areadlinkat (dir_fd, relname);
  if (!linkname)
    {
      error (0, errno, "%s", relname);
      *issued_diagnostic = true;
      return false;
    }

  bool result = true;
  if (fputs (" -> ", stream) < 0)
    result = false;
  if (result)
    {
      if (!print_name (linkname, stream, literal_control_chars))
        result = false;
    }
  free (linkname);
  return result;
}

static bool
maybe_print_file_link_target (const struct stat *statp,
                              int dir_fd,
                              const char *relname,
                              int literal_control_chars,
                              bool *issued_diagnostic, FILE *stream)
{
  if (S_ISLNK (statp->st_mode))
    {
      return print_file_link_target (statp, dir_fd, relname,
                                     literal_control_chars, issued_diagnostic,
                                     stream);
    }
  return true;
}


static bool
print_single_space (FILE *stream)
{
  if (EOF == putc (' ', stream))
    return false;
  return true;
}

/* NAME is the name to print.
   RELNAME is the path to access it from the current directory.
   STATP is the results of stat or lstat on it.
   Use CURRENT_TIME to decide whether to print yyyy or hh:mm.
   Use OUTPUT_BLOCK_SIZE to determine how to print file block counts
   and sizes.
   ISSUED_DIAGNOSTIC is set to true when the return value is false
   and we have already emitted a diagnostic on stderr.
   STREAM is the stdio stream to print on.  */

static bool
list_file_internal (const char *name,
                    int dir_fd,
                    const char *relname,
                    const struct stat *statp,
                    time_t current_time,
                    int output_block_size,
                    int literal_control_chars,
                    bool *issued_diagnostic, FILE *stream)
{

  if (!print_file_inum (statp, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_block_count (statp, output_block_size, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_file_mode (statp, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_link_count (statp, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_file_owner (statp, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_file_group (statp, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_file_dev_or_size (statp, output_block_size, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_file_mtime (statp, current_time, stream))
    return false;

  if (!print_single_space (stream))
    return false;

  if (!print_name (name, stream, literal_control_chars))
    return false;

  if (!maybe_print_file_link_target
      (statp, dir_fd, relname, literal_control_chars, issued_diagnostic,
       stream))
    return false;

  if (EOF == putc ('\n', stream))
    return false;

  return true;
}


/* NAME is the name to print.
   RELNAME is the path to access it from the current directory.
   STATP is the results of stat or lstat on it.
   Use CURRENT_TIME to decide whether to print yyyy or hh:mm.
   Use OUTPUT_BLOCK_SIZE to determine how to print file block counts
   and sizes.
   STREAM is the stdio stream to print on.  */

void
list_file (const char *name,
           int dir_fd,
           const char *relname,
           const struct stat *statp,
           time_t current_time,
           int output_block_size, int literal_control_chars, FILE *stream)
{
  /* POSIX requires in the case of find that if we issue a diagnostic
   * we should have a nonzero status.  But since this function
   * currently returns void, we cannot do that.
   *
   * POSIX doesn't include -ls, so this is already an extension.  But
   * still, it would be good to fix this.
   */
  bool issued_diagnostic = false;
  bool success =
    list_file_internal (name, dir_fd, relname, statp, current_time,
                        output_block_size, literal_control_chars,
                        &issued_diagnostic, stream);
  if (!success && !issued_diagnostic)
    {
      error (EXIT_FAILURE, errno, _("Failed to write output"));
    }
}

static bool
print_name_without_quoting (const char *p, FILE *stream)
{
  return (fprintf (stream, "%s", p) >= 0);
}


static bool
print_name_with_quoting (register const char *p, FILE *stream)
{
  register unsigned char c;

  while ((c = *p++) != '\0')
    {
      int fprintf_result = -1;
      switch (c)
        {
        case '\\':
          fprintf_result = fprintf (stream, "\\\\");
          break;

        case '\n':
          fprintf_result = fprintf (stream, "\\n");
          break;

        case '\b':
          fprintf_result = fprintf (stream, "\\b");
          break;

        case '\r':
          fprintf_result = fprintf (stream, "\\r");
          break;

        case '\t':
          fprintf_result = fprintf (stream, "\\t");
          break;

        case '\f':
          fprintf_result = fprintf (stream, "\\f");
          break;

        case ' ':
          fprintf_result = fprintf (stream, "\\ ");
          break;

        case '"':
          fprintf_result = fprintf (stream, "\\\"");
          break;

        default:
          if (c > 040 && c < 0177)
            {
              if (EOF == putc (c, stream))
                fprintf_result = -1;
              else
                fprintf_result = 1;     /* otherwise it's used uninitialized. */
            }
          else
            {
              fprintf_result = fprintf (stream, "\\%03o", (unsigned int) c);
            }
        }
      if (fprintf_result < 0)
        return false;
    }
  return true;
}

static bool
print_name (register const char *p, FILE *stream, int literal_control_chars)
{
  if (literal_control_chars)
    return print_name_without_quoting (p, stream);
  else
    return print_name_with_quoting (p, stream);
}
