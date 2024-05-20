/* test-sigusr -- Verify that xargs SIGUSR1/SIGUSR2 handling is correct.
   Copyright (C) 2024 Free Software Foundation, Inc.

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
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

/* Gnulib modules */
#include <error.h>


enum { FLAGFILE_MAX = 128 };
static char flagfile_name[FLAGFILE_MAX];
static const char* tmpdir = NULL;


static void
remove_temporary_files(void)
{
  if (tmpdir)
    {
      unlink(flagfile_name);
      rmdir(tmpdir);
    }
  tmpdir = NULL;
}

static void
wait_for_flagfile(void)
{
  struct stat st;
  for (;;)
    {
      if (0 == stat(flagfile_name, &st))
	{
	  return;
	}
      sleep(1);
    }
}

static void
delete_flagfile(void)
{
  if (0 != unlink(flagfile_name))
    {
      if (ENOENT != errno)
	{
	  error (2, errno, "Failed to unlink %s", flagfile_name);
	}
    }
}


static void
ignore_signal(int signum)
{
  struct sigaction sa;
  sa.sa_handler = SIG_IGN;
  sa.sa_flags = 0;
  sigemptyset(&sa.sa_mask);
  if (0 != sigaction(signum, &sa, (struct sigaction*)NULL))
    {
      error(2, errno, "sigaction failed");
    }
}


static void handler(int sig)
{
  /* Actually does nothing. */
}

static void
catch_signal(int signum)
{
  struct sigaction sa;
  sa.sa_handler = handler;
  sa.sa_flags = 0;
  if (0 != sigaction(signum, &sa, (struct sigaction*)NULL))
    {
      error(2, errno, "sigaction failed");
    }
}

static void
run_child(char * const argv[], int errno_fd)
{
  int fd;
  close(0);

  fd = open("/dev/null", O_RDONLY);
  if (fd < 0)
    {
      error(2, errno, "failed to open /dev/null");
    }
  else if (fd != 0)
    {
      error(2, errno, "failed to close stdin");
    }

  execvp("xargs", argv);

  /* Exec failed, tell the parent why. */
  if (write(errno_fd, &errno, sizeof errno) != sizeof errno)
    {
      error (2, errno, "child failed to write errno value though pipe");
    }

  error(2, errno, "unable to exec xargs in child process");

  /*NOTREACHED*/
}

static void
set_close_on_exec(int fd)
{
  if (0 != fcntl(fd, F_SETFD, FD_CLOEXEC))
    {
      error(2, errno, "F_SETFD failed");
    }
}



struct status
{
  int retval;
  int fatalsig;
};

/* Run xargs and return its exit status */
static struct status
run_xargs(const char *option, const char *optarg, int send_signal)
{
  int i = 0;
  enum { ARGV_MAX = 9 };
  char *argv[ARGV_MAX];
  pid_t child, dead;
  int wstatus;
  struct status result = {0};
  int pipefd[2];
  int child_errno;

  argv[i++] = (char*)"xargs";
  if (option)
    {
      argv[i++] = (char*)option;
    }
  if (optarg)
    {
      argv[i++] = (char*)optarg;
    }
  argv[i++] = (char*)"sh";
  argv[i++] = (char*)"-c";
  argv[i++] = (char*)"touch \"$1\" && sleep 4";
  argv[i++] = (char*)"fnord";
  argv[i++] = flagfile_name;
  argv[i++] = NULL;
  assert(i <= ARGV_MAX);

  /* Create a pipe so that we can detect an exec call. */
  /* read end is pipefd[0], write end is pipefd[1]. */
  if (0 != pipe(pipefd))
    {
      error(2, errno, "pipe");
    }
  set_close_on_exec(pipefd[0]);
  set_close_on_exec(pipefd[1]);
  delete_flagfile();

  while ((child=fork()) < 0 && errno == EAGAIN)
    {
      perror("unable to fork yet, will try again");
      sleep(1);
    }

  switch (child)
    {
    case -1:
      error(EXIT_FAILURE, errno, "cannot fork");
      break;
    case 0:			/* child */
      close(pipefd[0]);		/* close read end */
      /* The child will close the write end of the pipe on successful exec. */
      run_child(argv, pipefd[1]);
      abort();
      break;
    default:			/* parent */
      close(pipefd[1]);		/* close write end */
      if (read(pipefd[0], &child_errno, sizeof child_errno) < sizeof child_errno)
	{
	  /* The exec succeded in the child, and its write end of the pipe was closed. */
	}
      else
	{
	  /* exec failed in the child and its errno value is now in child_errno. */
	  error(2, child_errno, "execvp failed in the child process");
	}
      break;
    }

  /* We now know that the exec succeeded and xargs is running.  We
   * should give it a short time to set up its signal handlers.
   */
  fputs("exec succeeded in the child...", stdout);
  fflush(stdout);
  /* Wait for the child xargs to launch its command (so we know it
     will have set any signal handlers it is going to set). */
  wait_for_flagfile();

  if (send_signal)
    {
      if (0 != kill (child, send_signal))
	{
	  error(2, errno, "kill failed");
	}
    }

  wstatus = 0;
  dead = waitpid(child, &wstatus, 0);

  if (dead < 0)
    {
      error(2, errno, "waitpid failed");
    }
  else if (dead == 0)
    {
      error(2, 0, "test unexpectedly has more than one child");
    }
  else
    {
      if (WIFEXITED(wstatus))
	{
	  result.retval = WEXITSTATUS(wstatus);
	}
      else if (WIFSIGNALED(wstatus))
	{
	  result.retval = -1;
	  result.fatalsig = WTERMSIG(wstatus);
	}
      else if (WIFSTOPPED(wstatus))
	{
	  error(2, 0, "child was unexpectedly stopped");
	}
      return result;
    }
  /*NOTREACHED*/
  abort();
}


static void
verify_signal_ignored(int signum)
{
  struct status status;
  printf("verifying that xargs can ignore signal %d...", signum);
  fflush(stdout);

  ignore_signal(signum);
  status = run_xargs(NULL, NULL, signum);
  if (status.fatalsig)
    {
      fprintf(stderr, "xargs should not have exited fatally on receipt of signal %d\n", signum);
      exit(EXIT_FAILURE);
    }
  if (status.retval)
    {
      fprintf(stderr, "xargs should not have returned a nonzero exit status %d\n", status.retval);
      exit(EXIT_FAILURE);
    }
  fputs("OK\n", stdout);
}

static void
verify_signal_is_fatal(int signum)
{
  struct status status;
  printf("verifying that signal %d will kill xargs (without -P) if it is not blocked when xargs starts...", signum);
  fflush(stdout);
  catch_signal(signum);
  status = run_xargs(NULL, NULL, signum);
  if (!status.fatalsig)
    {
      fprintf(stderr, "xargs should have exited fatally on receipt of signal %d\n", signum);
      exit(EXIT_FAILURE);
    }
  fputs("OK\n", stdout);
}

static void
verify_signal_is_nonfatal_with_p(int signum)
{
  struct status status;
  printf("verifying that signal %d will not kill xargs -P if it is not blocked when xargs starts...", signum);
  fflush(stdout);
  catch_signal(signum);
  status = run_xargs("-P", "5", signum);
  if (status.fatalsig)
    {
      fprintf(stderr, "xargs -P should not have exited fatally on receipt of signal %d\n", signum);
      exit(EXIT_FAILURE);
    }
  fputs("OK\n", stdout);
}

int
main(int argc, char *argv[])
{
  char tmpdir_tmpl[] = "/tmp/test-sigusr.XXXXXX";
  tmpdir = mkdtemp(tmpdir_tmpl);
  if (NULL == tmpdir)
    {
      error(2, errno, "failed to create temporary directory");
    }
  snprintf(flagfile_name, FLAGFILE_MAX, "%s/flagfile", tmpdir);
  atexit(remove_temporary_files);

  verify_signal_ignored(SIGUSR1);
  verify_signal_ignored(SIGUSR2);
  fputs("\n", stdout);

  verify_signal_is_fatal(SIGUSR1);
  verify_signal_is_fatal(SIGUSR2);
  fputs("\n", stdout);
  verify_signal_is_nonfatal_with_p(SIGUSR1);
  verify_signal_is_nonfatal_with_p(SIGUSR2);
  return 0;
}
