

#ifndef MYSTICAL_TYPE_H
#define MYSTICAL_TYPE_H

typedef _PROTOTYPE( void task_t, (void) );
typedef _PROTOTYPE( void (*WatchDog), (void) );


typedef struct sys_proc {
    task_t *initial_eip;
    int     stack_size;
    char    name[16];
} SysProc_t;


typedef struct memory_s {
    phys_clicks base;
    phys_clicks size;
} Memory_t;

#if (CHIP == INTEL)

typedef unsigned port_t;


typedef unsigned reg_t;


typedef struct stackframe_s {


    reg_t	gs;
    reg_t	fs;
    reg_t	es;
    reg_t	ds;

    //pushad顺序
//    EAX
//    ECX
//    EDX
//    EBX
//    原始 ESP (非压入的 ESP)
//    EBP
//    ESI
//    EDI
    reg_t	edi;
    reg_t	esi;
    reg_t	ebp;
    reg_t	kernel_esp;
    reg_t	ebx;
    reg_t	edx;
    reg_t	ecx;
    reg_t	eax;

    reg_t	ret_addr;

    reg_t	eip;
    reg_t	cs;
    reg_t	eflags;
    reg_t	esp;
    reg_t   ss;


} Stackframe_t;


typedef struct seg_descriptor_s {
    u16_t limit_low;
    u16_t base_low;
    u8_t base_middle;
    u8_t access;
    u8_t granularity;
    u8_t base_high;
} SegDescriptor_t;


typedef _PROTOTYPE( void (*int_handler_t), (void) );

typedef _PROTOTYPE( int (*irq_handler_t), (int irq) );

typedef _PROTOTYPE( void (*mystical_syscall_t),  (void) );

#endif

#endif //MYSTICAL_TYPE_H
