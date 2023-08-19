#include "kernel.h"
#include "assert.h"
#include "logger.h"
#include "process.h"
#include "protect.h"
#include <mystical/common.h>

INIT_ASSERT

//unsigned int dp = (80 * 8 + 0) * 2;//第8行第0列开始

void l_print(char *str);

void mystical_main() {

    k_debug("enter kernel main\n");

    //除零异常
    //int a = 1 / 0;


//    printfk("test printk %d,%x\n", 123, 0xff);

//    clock_task();


    register Process_t *proc;
    register int logic_nr;
    for (proc = BEG_PROC_ADDR, logic_nr = -NR_TASKS; proc < END_PROC_ADDR; proc++, logic_nr++) {
        if (logic_nr > 0)
            strcpy(proc->name, "unused");
        proc->logic_nr = logic_nr;
        p_proc_addr[logic_nr_2_index(logic_nr)] = proc;
    }


    SysProc_t *sys_proc;
    reg_t sys_proc_stack_base = (reg_t) sys_proc_stack;
    u8_t privilege;
    u8_t rpl;
    for (logic_nr = -NR_TASKS; logic_nr <= LOW_USER; logic_nr++) {
        proc = proc_addr(logic_nr);
//        k_debug("proc addr:%p\n", proc);
        sys_proc = &sys_proc_table[logic_nr_2_index(logic_nr)];
        strcpy(proc->name, sys_proc->name);

        if (logic_nr < 0) {
            if (sys_proc->stack_size > 0) {

                proc->stack_guard_word = (reg_t *) sys_proc_stack_base;
                *proc->stack_guard_word = SYS_TASK_STACK_GUARD;
            }

            proc->priority = PROC_PRI_TASK;
            rpl = privilege = TASK_PRIVILEGE;
        } else {
            if (sys_proc->stack_size > 0) {

                proc->stack_guard_word = (reg_t *) sys_proc_stack_base;
                *proc->stack_guard_word = SYS_SERVER_STACK_GUARD;
            }
            proc->priority = PROC_PRI_SERVER;
            rpl = privilege = SERVER_PRIVILEGE;
        }

        sys_proc_stack_base += sys_proc->stack_size;


        proc->ldt[CS_LDT_INDEX] = gdt[TEXT_INDEX];
        proc->ldt[DS_LDT_INDEX] = gdt[DATA_INDEX];

        proc->ldt[CS_LDT_INDEX].access = (DA_CR | (privilege << 5));
        proc->ldt[DS_LDT_INDEX].access = (DA_DRW | (privilege << 5));

        proc->map.base = KERNEL_TEXT_SEG_BASE;
        proc->map.size = 0;

        proc->regs.cs = ((CS_LDT_INDEX << 3) | SA_TIL | rpl);
        proc->regs.ds = ((DS_LDT_INDEX << 3) | SA_TIL | rpl);
        proc->regs.es = proc->regs.fs = proc->regs.ss = proc->regs.ds;
        proc->regs.gs = (SELECTOR_KERNEL_GS & SA_RPL_MASK | rpl);
        proc->regs.eip = (reg_t) sys_proc->initial_eip;
        proc->regs.esp = sys_proc_stack_base;

//        k_debug("%x\n", sys_proc_stack_base);
        proc->regs.eflags = is_task_proc(proc) ? INIT_TASK_PSW : INIT_PSW;


        proc->flags = CLEAN_MAP;

        if (!is_idle_hardware(logic_nr)) ready(proc);
    }

//    curr_proc = proc_addr(-2);
//    printfk("A %ld sizeof(Process_t)=%ld\n", curr_proc, sizeof(Process_t));
//    restart();



//    curr_proc = proc_addr(IDLE_TASK);
    lock_pick();

    keyboard_init();

//    proc_dump();
//    map_dump();

    restart();

    while (1) {

    }

}


PUBLIC void panic(
        _CONST char *msg,
        int error_no
) {



    if (msg != NIL_PTR) {
        printf("\n$$$$$$$$$$ Mystical kernel panic: %s $$$$$$$$$$\n", msg);
        if (error_no != NO_NUM)
            printf("$$$$$$$$$$              error no: 0x%x        $$$$$$$$$$", error_no);
        printf("\n");
    }

    level0(down_run);
//    down_run();
}



PUBLIC void test_task_a(void) {
    int i, j, k;
    k = 0;
    while (TRUE) {
        for (i = 0; i < 100; i++)
            for (j = 0; j < 1000000; j++) {}
        printf("[A:%d]", k++);
    }
}


PUBLIC void test_task_b(void) {
    int i, j, k;
    k = 0;
    while (TRUE) {
        for (i = 0; i < 100; i++)
            for (j = 0; j < 1000000; j++) {}
        printf("[B:%d]", k++);
    }
}



PUBLIC void idle_task(void) {

    while (TRUE)
        level0(halt);
}
