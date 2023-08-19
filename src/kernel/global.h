

#ifndef MYSTICAL_GLOBAL_H
#define MYSTICAL_GLOBAL_H


#ifdef _TABLE
#undef EXTERN
#define EXTERN
#endif


extern SegDescriptor_t gdt[];
EXTERN u8_t gdt_ptr[6];
EXTERN u8_t idt_ptr[6];
EXTERN int dp;


EXTERN irq_handler_t irq_handler_table[NR_IRQ_VECTORS];
EXTERN struct process_s *held_head;
EXTERN struct process_s *held_tail;


EXTERN MemoryMap_t kernel_map;


EXTERN struct process_s *curr_proc;
extern SysProc_t sys_proc_table[];
extern char *sys_proc_stack[];


EXTERN BootParams_t* boot_params;
EXTERN u8_t kernel_reenter;
EXTERN mystical_syscall_t level0_func;

EXTERN unsigned int lost_ticks;
EXTERN clock_t tty_timeout;


#endif // MYSTICAL_GLOBAL_H
