

#include "kernel.h"
#include "assert.h"
#include "logger.h"

INIT_ASSERT


FORWARD _PROTOTYPE(int default_irq_handler, (int irq));


PUBLIC void interrupt_init(void) {

//    printf("interrupt_init\n");
    k_debug("interrupt_init have been called");

    interrupt_lock();


    out_byte(INT_M_CTL, 17);
    out_byte(INT_S_CTL, 17);


    out_byte(INT_M_CTLMASK, INT_VECTOR_IRQ0);
    out_byte(INT_S_CTLMASK, INT_VECTOR_IRQ8);


    out_byte(INT_M_CTLMASK, 4);
    out_byte(INT_S_CTLMASK, 2);


    out_byte(INT_M_CTLMASK, 1);
    out_byte(INT_S_CTLMASK, 1);


    out_byte(INT_M_CTLMASK, 0xff);
    out_byte(INT_S_CTLMASK, 0xff);


    int i = 0;
    for (; i < NR_IRQ_VECTORS; i++) {
        irq_handler_table[i] = default_irq_handler;
    }

    //测试
//    interrupt_unlock();

}


PUBLIC void put_irq_handler(int irq, irq_handler_t handler) {



    assert(irq >= 0 && irq < NR_IRQ_VECTORS);


    if (irq_handler_table[irq] == handler) return;


    assert(irq_handler_table[irq] == default_irq_handler);


    disable_irq(irq);
    irq_handler_table[irq] = handler;


}


PRIVATE int default_irq_handler(int irq) {
    printf("I am a interrupt, my name is int %d\n", irq);
    return DISABLE;
}



