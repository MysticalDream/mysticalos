

#ifndef MYSTICAL_PROTOTYPE_H
#define MYSTICAL_PROTOTYPE_H


struct process_s;
struct rtc_time;





_PROTOTYPE(void down_run, (void));

_PROTOTYPE(void restart, (void));

_PROTOTYPE(void, halt(void));

_PROTOTYPE(void level0_sys_call, (void));

_PROTOTYPE(void mystical_386_sys_call, (void));




_PROTOTYPE(void cstart, (void));




_PROTOTYPE(void panic, (const char* msg, int error_no ));

_PROTOTYPE(void idle_task, (void));

_PROTOTYPE( void test_task_a, (void) );
_PROTOTYPE( void test_task_b, (void) );




_PROTOTYPE(void init_segment_desc, (SegDescriptor_t * p_desc, phys_bytes base, phys_bytes limit, u16_t attribute));

_PROTOTYPE(phys_bytes seg2phys, (U16_t seg));

_PROTOTYPE(void protect_init, (void));




_PROTOTYPE(void phys_copy, (phys_bytes _src, phys_bytes _dest, phys_bytes _size));

_PROTOTYPE(void l_print, (char* _str));

_PROTOTYPE(u8_t in_byte, (port_t port));

_PROTOTYPE(void out_byte, (port_t port, U8_t value));

_PROTOTYPE(u16_t in_word, (port_t port));

_PROTOTYPE(void out_word, (port_t port, U16_t value));

_PROTOTYPE(void interrupt_lock, (void));

_PROTOTYPE(void interrupt_unlock, (void));

_PROTOTYPE(int disable_irq, (int int_request));

_PROTOTYPE(void enable_irq, (int int_request));

_PROTOTYPE(void level0, (mystical_syscall_t level0_func));

_PROTOTYPE(void msg_copy, (phys_bytes msg_phys, phys_bytes dest_phys));

_PROTOTYPE(u8_t cmos_read, (u8_t addr));




_PROTOTYPE(void interrupt_init, (void));

_PROTOTYPE(void put_irq_handler, (int irq, irq_handler_t handler));




_PROTOTYPE(int printfk, (const char* fmt, ...));

_PROTOTYPE(void bad_assertion, ( char *file, int line, char *what));

_PROTOTYPE(void bad_compare, (char *file, int line, int lhs, char *what, int rhs));




_PROTOTYPE(void clock_task, (void));

_PROTOTYPE(void get_rtc_time, (struct rtc_time *p_time));

_PROTOTYPE(void milli_delay, (time_t delay_ms));





_PROTOTYPE(void read_rtc, (struct rtc_time *p_time));






_PROTOTYPE(void lock_schedule, (void));

_PROTOTYPE(void lock_unready, (struct process_s *proc));

_PROTOTYPE(void lock_ready, (struct process_s *proc));

_PROTOTYPE(void lock_pick, (void));

_PROTOTYPE(void schedule_stop, (void ));

_PROTOTYPE(void ready, (struct process_s *proc));

_PROTOTYPE(void unready, (struct process_s *proc));

_PROTOTYPE(void interrupt, (int task));

_PROTOTYPE(void unhold, (void));




_PROTOTYPE(int mystical_send, (struct process_s *caller, int dest, Message_t *msg_phys));

_PROTOTYPE(int mystical_receive, (struct process_s *caller, int src, Message_t *msg_phys));




_PROTOTYPE(void proc_dump, (void));

_PROTOTYPE(void map_dump, (void));




_PROTOTYPE(void keyboard_init, (void));




_PROTOTYPE(void divide_error, (void));

_PROTOTYPE(void single_step_exception, (void));

_PROTOTYPE(void nmi, (void));

_PROTOTYPE(void breakpoint_exception, (void));

_PROTOTYPE(void overflow, (void));

_PROTOTYPE(void bounds_check, (void));

_PROTOTYPE(void inval_opcode, (void));

_PROTOTYPE(void copr_not_available, (void));

_PROTOTYPE(void double_fault, (void));

_PROTOTYPE(void inval_tss, (void));

_PROTOTYPE(void copr_not_available, (void));

_PROTOTYPE(void segment_not_present, (void));

_PROTOTYPE(void stack_exception, (void));

_PROTOTYPE(void general_protection, (void));

_PROTOTYPE(void page_fault, (void));

_PROTOTYPE(void copr_seg_overrun, (void));

_PROTOTYPE(void copr_error, (void));
//_PROTOTYPE( void divide_error, (void) );



_PROTOTYPE(void hwint00, (void));

_PROTOTYPE(void hwint01, (void));

_PROTOTYPE(void hwint02, (void));

_PROTOTYPE(void hwint03, (void));

_PROTOTYPE(void hwint04, (void));

_PROTOTYPE(void hwint05, (void));

_PROTOTYPE(void hwint06, (void));

_PROTOTYPE(void hwint07, (void));

_PROTOTYPE(void hwint08, (void));

_PROTOTYPE(void hwint09, (void));

_PROTOTYPE(void hwint10, (void));

_PROTOTYPE(void hwint11, (void));

_PROTOTYPE(void hwint12, (void));

_PROTOTYPE(void hwint13, (void));

_PROTOTYPE(void hwint14, (void));

_PROTOTYPE(void hwint15, (void));

#endif //MYSTICAL_PROTOTYPE_H

