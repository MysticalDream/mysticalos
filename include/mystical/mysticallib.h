/*
 * mystical的一些杂库
 */

#ifndef _MYSTICAL_FLYLIB_H
#define _MYSTICAL_FLYLIB_H

#ifndef _ANSI_H
#include <ansi.h>
#endif

/* 关于 BSD. */
_PROTOTYPE(void swab, (char *_from, char *_to, int _count));
_PROTOTYPE(char *itoa, (int _n));
_PROTOTYPE(char *getpass, (const char *_prompt));

/* 关于 mystical */


#endif //_MYSTICAL_FLYLIB_H
