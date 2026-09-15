/* argvwipe.so -- keep the Apple ID password out of /proc/<pid>/cmdline.
 *
 * AltServer-Linux only accepts the Apple ID password as a command-line argument (-p)
 * and does not prompt for it. /proc/<pid>/cmdline is world-readable, so the password
 * would be visible to any process (and any user) on the machine for the whole run.
 *
 * This shim wraps the option-parsing entry points. As soon as the program finishes
 * parsing its arguments (getopt* returns -1), the secret named by the
 * SIGN_ARGV_SECRET environment variable is overwritten in place in the argv memory
 * region -- which is precisely what /proc/<pid>/cmdline reads -- and the variable is
 * unset so it cannot be inherited by children.
 *
 * /proc/<pid>/environ is mode 0400 and readable only by the owning user, so the
 * secret exists only there, only briefly, instead of in a world-readable argv.
 *
 * Build:  gcc -shared -fPIC -O2 -o argvwipe.so argvwipe.c
 * Use:    SIGN_ARGV_SECRET=<secret> LD_PRELOAD=/path/argvwipe.so prog -p <secret> ...
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <getopt.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void wipe_argv(int argc, char *const argv[])
{
    const char *secret = getenv("SIGN_ARGV_SECRET");
    if (secret == NULL || *secret == '\0')
        return;

    for (int i = 0; i < argc; i++) {
        if (argv[i] != NULL && strcmp(argv[i], secret) == 0)
            memset((void *)argv[i], '*', strlen(argv[i]));
    }

    unsetenv("SIGN_ARGV_SECRET");
}

int getopt(int argc, char *const argv[], const char *optstring)
{
    static int (*real)(int, char *const[], const char *) = NULL;
    if (real == NULL)
        real = dlsym(RTLD_NEXT, "getopt");

    int r = real(argc, argv, optstring);
    if (r == -1)
        wipe_argv(argc, argv);
    return r;
}

int getopt_long(int argc, char *const argv[], const char *optstring,
                const struct option *longopts, int *longindex)
{
    static int (*real)(int, char *const[], const char *, const struct option *, int *) = NULL;
    if (real == NULL)
        real = dlsym(RTLD_NEXT, "getopt_long");

    int r = real(argc, argv, optstring, longopts, longindex);
    if (r == -1)
        wipe_argv(argc, argv);
    return r;
}

int getopt_long_only(int argc, char *const argv[], const char *optstring,
                     const struct option *longopts, int *longindex)
{
    static int (*real)(int, char *const[], const char *, const struct option *, int *) = NULL;
    if (real == NULL)
        real = dlsym(RTLD_NEXT, "getopt_long_only");

    int r = real(argc, argv, optstring, longopts, longindex);
    if (r == -1)
        wipe_argv(argc, argv);
    return r;
}
