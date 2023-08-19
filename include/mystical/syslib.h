/*
 * 包含了在操作系统内部调用以访问操作系统其他服务的C库函数原型。
 * 操作系统向外提供的系统调用，也是通过调用这些库函数去实现的。
 */

#ifndef _MYSTICAL_SYSLIB_H
#define _MYSTICAL_SYSLIB_H

#ifndef MYSTICAL_TYPES_H

#include <sys/types.h>

#endif


/* Mystical 用户和系统双用库 */
_PROTOTYPE(int send_rec, (int src, Message_t *io_msg));

_PROTOTYPE(int in_outbox, (Message_t * in_msg, Message_t * out_msg));

/* Mystical 系统库 */
_PROTOTYPE(int send, (int dest, Message_t* out_msg));

_PROTOTYPE(int receive, (int src, Message_t* in_msg));


#endif //_MYSTICAL_SYSLIB_H
