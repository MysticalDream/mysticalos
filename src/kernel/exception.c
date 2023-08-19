

#include "kernel.h"


PRIVATE char *exception_table[] = {
        "#DE Divide Error",
        "#DB RESERVED",
        "—   NMI Interrupt",
        "#BP Breakpoint",
        "#OF Overflow",
        "#BR BOUND Range Exceeded",
        "#UD Invalid Opcode (Undefined Opcode)",
        "#NM Device Not Available (No Math Coprocessor)",
        "#DF Double Fault",
        "    Coprocessor Segment Overrun (reserved)",
        "#TS Invalid TSS",
        "#NP Segment Not Present",
        "#SS Stack-Segment Fault",
        "#GP General Protection",
        "#PF Page Fault",
        "—   (Intel reserved. Do not use.)",
        "#MF x87 FPU Floating-Point Error (Math Fault)",
        "#AC Alignment Check",
        "#MC Machine Check",
        "#XF SIMD Floating-Point Exception",
};


PUBLIC void exception_handler(
        int int_vector,
        int error_no
) {


    if (int_vector == 2) {
        printfk("!********** Got spurious NMI! **********!\n");
//        l_print("!********** Got spurious NMI! **********!\n");
        return;
    }


    if (exception_table[int_vector] == NIL_PTR) {
        panic("Fount a exception, but it not in table!", NO_NUM);
//        printfk("\n%s\n", "!********** exception exit **********!");
    } else {
        panic(exception_table[int_vector], error_no != 0xffffffff ? error_no : NO_NUM);
//        printfk("\ninfo:%s\n", exception_table[int_vector]);
    }

//    if (error_no != 0xffffffff) {
//        printfk("error no->[dec:%d][hex:%x]\n", error_no, error_no);
//    }
//
//    printfk("mysticalos has down run! please reboot\n");

}


