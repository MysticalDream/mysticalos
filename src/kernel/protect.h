

#ifndef MYSTICAL_PROTECT_H
#define MYSTICAL_PROTECT_H




typedef struct descriptor_s {
    char limit[sizeof(u16_t)];
    char base[sizeof(u32_t)];
} Descriptor_t;




typedef struct gate_s
{
    u16_t	offset_low;
    u16_t	selector;
    u8_t	dcount;

    u8_t	attr;
    u16_t	offset_high;
} Gate_t;




typedef struct tss_s
{
    reg_t   backlink;
    reg_t	esp0;
    reg_t	ss0;
    reg_t	esp1;
    reg_t	ss1;
    reg_t	esp2;
    reg_t	ss2;
    reg_t   cr3;
    reg_t	eip;
    reg_t	flags;
    reg_t	eax;
    reg_t	ecx;
    reg_t	edx;
    reg_t	ebx;
    reg_t	esp;
    reg_t	ebp;
    reg_t	esi;
    reg_t	edi;
    reg_t	es;
    reg_t	cs;
    reg_t	ss;
    reg_t	ds;
    reg_t   fs;
    reg_t   gs;
    reg_t	ldt;
    u16_t trap;
    u16_t iobase;

} Tss_t;




#define GDT_SIZE (LDT_FIRST_INDEX + NR_TASKS + NR_PROCS)
#define IDT_SIZE (INT_VECTOR_SYS_CALL + 1)
#define LDT_SIZE         2




#define DUMMY_INDEX         0
#define TEXT_INDEX          1
#define DATA_INDEX          2
#define VIDEO_INDEX         3

#define TSS_INDEX           4
#define LDT_FIRST_INDEX     5



#define SELECTOR_DUMMY      DUMMY_INDEX * DESCRIPTOR_SIZE
#define SELECTOR_TEXT       TEXT_INDEX * DESCRIPTOR_SIZE
#define SELECTOR_DATA       DATA_INDEX * DESCRIPTOR_SIZE
#define SELECTOR_VIDEO      VIDEO_INDEX * DESCRIPTOR_SIZE | SA_RPL3

#define SELECTOR_TSS        TSS_INDEX * DESCRIPTOR_SIZE
#define SELECTOR_LDT_FIRST  LDT_FIRST_INDEX * DESCRIPTOR_SIZE

#define SELECTOR_KERNEL_CS  SELECTOR_TEXT
#define SELECTOR_KERNEL_DS  SELECTOR_DATA
#define SELECTOR_KERNEL_GS  SELECTOR_VIDEO



#define CS_LDT_INDEX     0
#define DS_LDT_INDEX     1




#define KERNEL_PRIVILEGE    0
#define TASK_PRIVILEGE      1
#define SERVER_PRIVILEGE    2
#define USER_PRIVILEGE      3




#define SA_RPL_MASK         0xFFFC
#define SA_RPL0             0
#define SA_RPL1             1
#define SA_RPL2             2
#define SA_RPL3             3

#define SA_TI_MASK          0xFFFB
#define SA_TIG              0
#define SA_TIL              4




#define	DA_32			    0x4000
#define	DA_LIMIT_4K		    0x8000
#define	LIMIT_4K_SHIFT	    12
#define	DA_DPL0			    0x00
#define	DA_DPL1			    0x20
#define	DA_DPL2			    0x40
#define	DA_DPL3			    0x60


#define	DA_DR			    0x90
#define	DA_DRW			    0x92
#define	DA_DRWA			    0x93
#define	DA_C			    0x98
#define	DA_CR			    0x9A
#define	DA_CCO			    0x9C
#define	DA_CCOR			    0x9E


#define	DA_LDT			    0x82
#define	DA_TaskGate		    0x85
#define	DA_386TSS		    0x89
#define	DA_386CGate		    0x8C
#define	DA_386IGate		    0x8E
#define	DA_386TGate		    0x8F

#define DESCRIPTOR_SIZE             8


#define	INT_VECTOR_DIVIDE		    0x0
#define	INT_VECTOR_DEBUG		    0x1
#define	INT_VECTOR_NMI			    0x2
#define	INT_VECTOR_BREAKPOINT		0x3
#define	INT_VECTOR_OVERFLOW		    0x4
#define	INT_VECTOR_BOUNDS		    0x5
#define	INT_VECTOR_INVAL_OP		    0x6
#define	INT_VECTOR_COPROC_NOT		0x7
#define	INT_VECTOR_DOUBLE_FAULT		0x8
#define	INT_VECTOR_COPROC_SEG		0x9
#define	INT_VECTOR_INVAL_TSS		0xA
#define	INT_VECTOR_SEG_NOT		    0xB
#define	INT_VECTOR_STACK_FAULT		0xC
#define	INT_VECTOR_PROTECTION		0xD
#define	INT_VECTOR_PAGE_FAULT		0xE
#define	INT_VECTOR_COPROC_ERR		0x10


#define	reassembly(high, high_shift, mid, mid_shift, low)	\
	(((high) << (high_shift)) |				\
	 ((mid)  << (mid_shift)) |				\
	 (low))

#endif //MYSTICAL_PROTECT_H
