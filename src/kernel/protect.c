

#include "kernel.h"
#include "protect.h"
#include "process.h"
#include "logger.h"


PUBLIC SegDescriptor_t gdt[GDT_SIZE];

PRIVATE Gate_t idt[IDT_SIZE];

PUBLIC Tss_t tss;


struct gate_desc_s {
    u8_t vector;
    int_handler_t handler;
    u8_t privilege;
};

_PROTOTYPE(PRIVATE void test_software_interrupt, (void));


struct gate_desc_s int_gate_table[] = {

        {INT_VECTOR_DIVIDE,       divide_error,            KERNEL_PRIVILEGE},
        {INT_VECTOR_DEBUG,        single_step_exception,   KERNEL_PRIVILEGE},
        {INT_VECTOR_NMI,          nmi,                     KERNEL_PRIVILEGE},
        {INT_VECTOR_BREAKPOINT,   breakpoint_exception,    KERNEL_PRIVILEGE},
        {INT_VECTOR_OVERFLOW,     overflow,                KERNEL_PRIVILEGE},
        {INT_VECTOR_BOUNDS,       bounds_check,            KERNEL_PRIVILEGE},
        {INT_VECTOR_INVAL_OP,     inval_opcode,            KERNEL_PRIVILEGE},
        {INT_VECTOR_COPROC_NOT,   copr_not_available,      KERNEL_PRIVILEGE},
        {INT_VECTOR_DOUBLE_FAULT, double_fault,            KERNEL_PRIVILEGE},
        {INT_VECTOR_COPROC_SEG,   copr_seg_overrun,        KERNEL_PRIVILEGE},
        {INT_VECTOR_INVAL_TSS,    inval_tss,               KERNEL_PRIVILEGE},
        {INT_VECTOR_SEG_NOT,      segment_not_present,     KERNEL_PRIVILEGE},
        {INT_VECTOR_STACK_FAULT,  stack_exception,         KERNEL_PRIVILEGE},
        {INT_VECTOR_PROTECTION,   general_protection,      KERNEL_PRIVILEGE},
        {INT_VECTOR_PAGE_FAULT,   page_fault,              KERNEL_PRIVILEGE},
        {INT_VECTOR_COPROC_ERR,   copr_error,              KERNEL_PRIVILEGE},

        {INT_VECTOR_IRQ0 + 0, hwint00, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 1, hwint01, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 2, hwint02, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 3, hwint03, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 4, hwint04, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 5, hwint05, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 6, hwint06, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ0 + 7, hwint07, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 0, hwint08, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 1, hwint09, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 2, hwint10, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 3, hwint11, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 4, hwint12, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 5, hwint13, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 6, hwint14, KERNEL_PRIVILEGE},
        {INT_VECTOR_IRQ8 + 7, hwint15, KERNEL_PRIVILEGE},

        {INT_VECTOR_LEVEL0,       level0_sys_call,         TASK_PRIVILEGE},
        {INT_VECTOR_SYS_CALL,     mystical_386_sys_call,   USER_PRIVILEGE},
};

PRIVATE void test_software_interrupt(void) {
    printfk("soft interrupt!!!\n");
}


FORWARD _PROTOTYPE(void init_gate, (u8_t vector, u8_t desc_type, int_handler_t handler, u8_t privilege));


#if defined(TEST_GP_EXCEPTION)
#define GDT_INDEX 7

PRIVATE void init_gate2(
        u8_t vector,
        u8_t desc_type,
        int_handler_t handler,
        u8_t privilege
) {
    // 得到中断向量对应的门结构
    Gate_t *p_gate = &idt[vector];
    // 取得处理函数的基地址
    u32_t base_addr = (u32_t) handler;
    // 一一赋值
    p_gate->offset_low = base_addr & 0xFFFF;
    p_gate->selector = GDT_INDEX * DESCRIPTOR_SIZE;
    p_gate->dcount = 0;
    p_gate->attr = desc_type | (privilege << 5);
#if _WORD_SIZE == 4
    p_gate->offset_high = (base_addr >> 16) & 0xFFFF;
#endif
}

#endif



PUBLIC void protect_init(void) {

    k_debug("descriptor initialization...");


    phys_copy(*((u32_t *) vir2phys(&gdt_ptr[2])),            // src:LOADER中旧的GDT基地址
              vir2phys(&gdt),                                // dest:新的GDT基地址
              *((u16_t *) vir2phys(&gdt_ptr[0])) + 1           // size:旧GDT的段界限 + 1
    );

    u16_t *p_gdt_limit = (u16_t *) vir2phys(&gdt_ptr[0]);
    u32_t *p_gdt_base = (u32_t *) vir2phys(&gdt_ptr[2]);
    *p_gdt_limit = GDT_SIZE * DESCRIPTOR_SIZE - 1;
    *p_gdt_base = vir2phys(&gdt);

    u16_t *p_idt_limit = (u16_t *) vir2phys(&idt_ptr[0]);
    u32_t *p_idt_base = (u32_t *) vir2phys(&idt_ptr[2]);
    *p_idt_limit = IDT_SIZE * sizeof(Gate_t) - 1;
    *p_idt_base = vir2phys(&idt);

#if defined(TEST_GP_EXCEPTION)
    //测试
    init_segment_desc(&gdt[GDT_INDEX], 0, 0xfffff, DA_32 | DA_CR | DA_LIMIT_4K | DA_DPL3);
#endif


    struct gate_desc_s *current_gate = int_gate_table;
    int gate_table_size = sizeof(int_gate_table) / sizeof(struct gate_desc_s);
    struct gate_desc_s *end_gate = int_gate_table + gate_table_size;
    for (; current_gate < end_gate; current_gate++) {
        init_gate(current_gate->vector, DA_386IGate, current_gate->handler, current_gate->privilege);
    }
#if defined(TEST_GP_EXCEPTION)
    init_gate2(48, DA_386IGate, test_software_interrupt, 0);
#endif


    memset(&tss, 0, sizeof(tss));
    tss.ss0 = SELECTOR_KERNEL_DS;
    init_segment_desc(&gdt[TSS_INDEX], vir2phys(&tss), sizeof(tss) - 1, DA_386TSS);
    tss.iobase = sizeof(tss);


    Process_t *proc = BEG_PROC_ADDR;
    int ldt_idx = LDT_FIRST_INDEX;
    for(; proc < END_PROC_ADDR; proc++, ldt_idx++) {
        memset(proc, 0, sizeof(Process_t));
        init_segment_desc(&gdt[ldt_idx], vir2phys(proc->ldt), sizeof(proc->ldt) - 1, DA_LDT);
        proc->ldt_sel = ldt_idx * DESCRIPTOR_SIZE;
    }

}


PUBLIC void init_segment_desc(
        SegDescriptor_t *p_desc,
        phys_bytes base,
        phys_bytes limit,
        u16_t attribute
) {

    p_desc->limit_low = limit & 0x0FFFF;
    p_desc->base_low = base & 0x0FFFF;
    p_desc->base_middle = (base >> 16) & 0x0FF;
    p_desc->access = attribute & 0xFF;
    p_desc->granularity = ((limit >> 16) & 0x0F) |
                          ((attribute >> 8) & 0xF0);
    p_desc->base_high = (base >> 24) & 0x0FF;
}


PRIVATE void init_gate(
        u8_t vector,
        u8_t desc_type,
        int_handler_t handler,
        u8_t privilege
) {
    // 得到中断向量对应的门结构
    Gate_t *p_gate = &idt[vector];
    // 取得处理函数的基地址
    u32_t base_addr = (u32_t) handler;
    // 一一赋值
    p_gate->offset_low = base_addr & 0xFFFF;
    p_gate->selector = SELECTOR_KERNEL_CS;
    p_gate->dcount = 0;
    p_gate->attr = desc_type | (privilege << 5);
#if _WORD_SIZE == 4
    p_gate->offset_high = (base_addr >> 16) & 0xFFFF;
#endif
}






PUBLIC phys_bytes seg2phys(U16_t seg) {
    SegDescriptor_t *p_dest = &gdt[seg >> 3];
    return (p_dest->base_high << 24 | p_dest->base_middle << 16 | p_dest->base_low);
}

