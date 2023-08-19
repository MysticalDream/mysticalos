

#ifndef MYSTICAL_CONST_H
#define MYSTICAL_CONST_H


#if (CHIP == INTEL)


#define K_STACK_BYTES   1024

#define INIT_PSW      0x202
#define INIT_TASK_PSW 0x1202

#define HCLICK_SHIFT    4
#define HCLICK_SIZE     16
#if CLICK_SIZE >= HCLICK_SIZE
#define click_to_hclick(n) ((n) << (CLICK_SHIFT - HCLICK_SHIFT))
#else
#define click_to_hclick(n) ((n) >> (HCLICK_SHIFT - CLICK_SHIFT))
#endif
#define hclick_to_physb(n) ((phys_bytes) (n) << HCLICK_SHIFT)
#define physb_to_hclick(n) ((n) >> HCLICK_SHIFT)


#define INT_VECTOR_BIOS_IRQ0        0x00
#define INT_VECTOR_BIOS_IRQ8        0x10
#define	INT_VECTOR_IRQ0				0x20    // 32
#define	INT_VECTOR_IRQ8				0x28    // 40


#define NR_IRQ_VECTORS      16

#define	CLOCK_IRQ		    0
#define	KEYBOARD_IRQ	    1
#define	CASCADE_IRQ		    2
#define	ETHER_IRQ		    3
#define	SECONDARY_IRQ	    3
#define	RS232_IRQ		    4
#define	XT_WINI_IRQ		    5
#define	FLOPPY_IRQ		    6
#define	PRINTER_IRQ		    7

#define REAL_CLOCK_IRQ      8
#define DIRECT_IRQ2_IRQ     9
#define RESERVED_10_IRQ     10
#define RESERVED_11_IRQ     11
#define MOUSE_IRQ           12
#define FPU_IRQ             13
#define	AT_WINI_IRQ		    14
#define RESERVED_15_IRQ     15


#define NR_SYS_CALL         0


#define WINI_0_PARM_VEC     0x41
#define WINI_1_PARM_VEC     0x46


#define INT_M_CTL           0x20
#define INT_M_CTLMASK       0x21
#define INT_S_CTL           0xA0
#define INT_S_CTLMASK       0xA1

#define EOI             0x20
#define DISABLE         0
#define ENABLE          EOI





#define BLACK   0x0
#define WHITE   0x7
#define RED     0x4
#define GREEN   0x2
#define BLUE    0x1
#define FLASH   0x80 << 8
#define BRIGHT  0x08 << 8
#define MAKE_COLOR(bg,fg) (((bg << 4) | fg) << 8)



#define NR_MEMORY_CLICK            6


#define PCR		0x65
#define PORT_B          0x61


#define INT_VECTOR_LEVEL0           0x66
#define INT_VECTOR_SYS_CALL         0x94

#endif





#define TASK_QUEUE             0
#define SERVER_QUEUE           1
#define USER_QUEUE             2
#define NR_PROC_QUEUE          3


#define printf  printfk


#define	vir2phys(vir) ((phys_bytes)(KERNEL_DATA_SEG_BASE) + (vir_bytes)(vir))


#define sec2ms(s) (s * 1000)

#define tick2ms(t)  (t * ONE_TICK_MILLISECOND)

#define tick2sec(t)   ((time_t)tick2ms(t) / 1000)

#define bytes2round_k(n)    ((unsigned) (((n + 512) >> 10)))


#define SEND_DEFAULT(n)              send(n, NIL_MESSAGE)
#define RECEIVE_DEFAULT(n)              receive(n, NIL_MESSAGE)
#define SEND_REC_DEFAULT(n)          send_rec(n, NIL_MESSAGE)
#define INIT_SAME_BOX(vir)         in_outbox(vir, vir);


#endif //MYSTICAL_CONST_H
