/* argvtest.c -- unit test for argvwipe.so.
 *
 * Parses -p like AltServer does, then idles so /proc/<pid>/cmdline can be inspected.
 * With the shim loaded, the option's value must be masked in the cmdline output while
 * the program still holds a usable (unmasked-length) view of the argument.
 *
 * Build: gcc -O2 -o argvtest argvtest.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    int opt;
    const char *pw = NULL;

    while ((opt = getopt(argc, argv, "p:")) != -1) {
        if (opt == 'p')
            pw = optarg;
    }

    printf("parsed -p length: %zu\n", pw ? strlen(pw) : 0UL);
    fflush(stdout);
    sleep(6);
    printf("still running, -p length: %zu\n", pw ? strlen(pw) : 0UL);
    return 0;
}
