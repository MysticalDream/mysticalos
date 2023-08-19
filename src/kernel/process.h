

#ifndef _MYSTICAL_PROCESS_H
#define _MYSTICAL_PROCESS_H


typedef struct process_s {


    Stackframe_t regs;
    reg_t ldt_sel;
    SegDescriptor_t ldt[2];




    reg_t *stack_guard_word;


    MemoryMap_t map;



    int flags;
    pid_t pid;
    u8_t priority;
    struct process_s *next_ready;
    int logic_nr;
    bool_t int_blocked;
    bool_t int_held;
    struct process_s *next_held;


    clock_t user_time;
    clock_t sys_time;
    clock_t child_user_time;
    clock_t child_sys_time;
    clock_t alarm;


    Message_t *inbox;
    Message_t *outbox;
    Message_t *transfer;
    int get_from;
    int send_to;


    struct process_s *waiter_head;
    struct process_s *next_waiter;

    char name[32];
} Process_t;


#define SYS_TASK_STACK_GUARD    ((reg_t) (sizeof(reg_t) == 2 ? 0xBEEF : 0xDEADBEEF))
#define SYS_SERVER_STACK_GUARD    ((reg_t) (sizeof(reg_t) == 2 ? 0xBFEF : 0xDEADCEEF))


#define CLEAN_MAP       0
#define NO_MAP            0x01
#define SENDING            0x02
#define RECEIVING        0x04


#define PROC_PRI_NONE    0
#define PROC_PRI_TASK    1
#define PROC_PRI_SERVER    2
#define PROC_PRI_USER    3
#define PROC_PRI_IDLE    4


#define BEG_PROC_ADDR       (&proc_table[0])
#define END_PROC_ADDR       (&proc_table[NR_TASKS + NR_SERVERS + NR_PROCS])
#define END_TASK_ADDR       (&proc_table[NR_TASKS])
#define BEG_SERVER_ADDR     (&proc_table[NR_TASKS + NR_SERVERS])
#define BEG_USER_PROC_ADDR  (&proc_table[NR_TASKS + NR_SERVERS +LOW_USER])


#define NIL_PROC          ((Process_t *) 0)
#define logic_nr_2_index(n) (NR_TASKS + n)
#define is_idle_hardware(n) ((n) == IDLE_TASK || (n) == HARDWARE)
#define is_ok_proc_nr(n)      ((unsigned) ((n) + NR_TASKS) < NR_PROCS + NR_TASKS + NR_SERVERS)
#define is_ok_src_dest(n)   (is_ok_proc_nr(n) || (n) == ANY)
#define is_any_hardware(n)   ((n) == ANY || (n) == HARDWARE)
#define is_sys_server(n)      ((n) == FS_PROC_NR || (n) == MM_PROC_NR || (n) == MYSTICAL_PROC_NR)
#define is_empty_proc(p)       ((p)->priority == PROC_PRI_NONE)
#define is_sys_proc(p)         ((p)->priority != PROC_PRI_USER)
#define is_task_proc(p)        ((p)->priority == PROC_PRI_TASK)
#define is_serv_proc(p)        ((p)->priority == PROC_PRI_SERVER)
#define is_user_proc(p)        ((p)->priority == PROC_PRI_USER)


#define proc_addr(n)      (p_proc_addr + NR_TASKS)[(n)]
#define cproc_addr(n)     (&(proc_table + NR_TASKS)[(n)])

#define proc_vir2phys(p, vir) \
    ((phys_bytes)(p)->map.base + (vir_bytes)(vir))


EXTERN Process_t proc_table[NR_TASKS + NR_SERVERS + NR_PROCS];
EXTERN Process_t *p_proc_addr[NR_TASKS + NR_SERVERS + NR_PROCS];



EXTERN Process_t *bill_proc;


EXTERN Process_t *ready_head[NR_PROC_QUEUE];
EXTERN Process_t *ready_tail[NR_PROC_QUEUE];

#endif //_MYSTICAL_PROCESS_H
