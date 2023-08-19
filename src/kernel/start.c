

#include "kernel.h"
#include "protect.h"
#include "assert.h"
#include "logger.h"

INIT_ASSERT

int test_int(int irq) {
    printf("i am new int handler!\n");
    return DISABLE;
}


PUBLIC void cstart(void) {


    //第1行第0列开始
    dp = (80 * 1 + 0) * 2;
//    l_print("cstart is called\n");
    k_debug("Start initializing the kernel");

    protect_init();


    interrupt_init();

//    put_irq_handler(3, test_int);
//    enable_irq(3);


    u32_t *p_boot_params = (u32_t *) BOOT_PARAM_ADDR;

    assert(p_boot_params[BP_MAGIC] == BOOT_PARAM_MAGIC);

    boot_params = (BootParams_t *) (BOOT_PARAM_ADDR + 4);

}




