/*
 *
 * ansi标准函数memcmp实现。
 */
#include <string.h>

/*=========================================================================*
 *				memcmp				   *
 *			  比较两个内存区域
 *=========================================================================*/
int memcmp(const void *s1, const void *s2, size_t n)
{
    if ((s1 == 0) || (s2 == 0)) { /* 健壮性 */
        return (s1 - s2);
    }

    register const char *p1 = s1;
    register const char *p2 = s2;
    int i;
    for (i = 0; i < n; i++,p1++,p2++) {
        if (*p1 != *p2) {
            return (*p1 - *p2);
        }
    }
    return 0;
}

