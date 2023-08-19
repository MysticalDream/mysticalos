

#define _TABLE

#include "kernel.h"
#include <stdlib.h>
#include <termios.h>
#include <mystical/common.h>
#include "process.h"



#define SMALL_STACK (128 * sizeof(char*))

#define NORMAL_STACK (256 * sizeof(char*))


#define CLOCK_TASK_STACK    SMALL_STACK



//#define IDLE_TASK_STACK     (19 * sizeof(char*))
//TODO:需要研究一下为什么 clock_task 在SMALL_STACK会出现问题
#define IDLE_TASK_STACK     (120 * sizeof(char*))

#define HARDWARE_STACK      0


#define TOTAL_SYS_PROC_STACK    (  CLOCK_TASK_STACK + IDLE_TASK_STACK +HARDWARE_STACK)
//#define TOTAL_SYS_PROC_STACK    (  SMALL_STACK + SMALL_STACK )

//#define TOTAL_SYS_PROC_STACK (0)


PUBLIC char *sys_proc_stack[TOTAL_SYS_PROC_STACK / sizeof(char *)];


PUBLIC SysProc_t sys_proc_table[] = {


        {clock_task, CLOCK_TASK_STACK, "CLOCK"},

        {idle_task, IDLE_TASK_STACK, "IDLE"},//-2


        {0,         HARDWARE_STACK,  "HARDWARE"},//-1

//        {test_task_a, SMALL_STACK, "TEST_A"},
//        {test_task_b, SMALL_STACK, "TEST_B"},


};


//#define NKT (sizeof(task_table) / sizeof(Task_t) - (ORIGIN_PROC_NR + 1))
#define NKT ( sizeof(sys_proc_table) / sizeof(SysProc_t) )

//extern int dummy_task_table_check[NR_TASKS + NR_SERVERS == NKT ? 1 : -1];

