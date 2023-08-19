/**
  ******************************************************************************
  * @file           : test.c
  * @author         : MysticalDream
  ******************************************************************************
  */

#include <stdio.h>

void *my_memcpy(void *dst, const void *src, size_t len) {
    if (NULL == dst || NULL == src) {
        return NULL;
    }

    void *ret = dst;

    if (dst <= src || (char *) dst >= (char *) src + len) {
        //没有内存重叠，从低地址开始复制
        while (len--) {
            *(char *) dst = *(char *) src;
            dst = (char *) dst + 1;
            src = (char *) src + 1;
        }
    } else {
        //有内存重叠，从高地址开始复制
        src = (char *) src + len - 1;
        dst = (char *) dst + len - 1;
        while (len--) {
            *(char *) dst = *(char *) src;
            dst = (char *) dst - 1;
            src = (char *) src - 1;
        }
    }
    return ret;
}
