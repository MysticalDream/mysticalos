

#include "kernel.h"
#include <stdarg.h>
#include <stdio.h>

static char buf[1024];

PUBLIC int printfk(
        const char *fmt,
        ...
) {
    va_list ap;
    int len;


    va_start(ap, fmt);


    len = vsprintf(buf, fmt, ap);

    l_print(buf);


    va_end(ap);
    return len;
}



PUBLIC void bad_assertion(
        char *file,
        int line,
        char *what
) {

    printf("\n\n*==============================================================================*");
    printf("* panic at file://%s(%d): assertion \"%s\" failed\n",
           file, line, what);
    printf("*==============================================================================*\n");
    panic("bad assertion", NO_NUM);
}


PUBLIC void bad_compare(
        char *file,
        int line,
        int lhs,
        char *what,
        int rhs
) {

    printf("\n\n*==============================================================================*");
    printf("* panic at file://%s(%d): compare \"%s\" failed\n",
           file, line, what);
    printf("*==============================================================================*\n");
    panic("bad compare", NO_NUM);
}


