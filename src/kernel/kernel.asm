%include "asm_const.inc"
;数据段
[section .data]
trap_errno dd 0xffffffff
tip_msg db "t",0
bits 32
    nop
;堆栈段
[section .bss]
StackSpace: resb 4*1024;4kb栈空间
StackTop:

;文本段
[section .text]

extern l_print

; 导入函数
extern cstart                       ; 初始化一些事情，主要是改变gdt_ptr，让它指向新的GDT
extern mystical_main                ; 内核主函数
extern exception_handler            ; 异常统一处理例程
extern sys_call                     ; 系统调用处理函数
extern unhold                       ; 处理挂起的中断

; 导入变量
extern gdt_ptr                      ; GDT指针
extern idt_ptr                      ; IDT指针
extern tss                          ; 任务状态段
extern irq_handler_table            ; 硬件中断请求处理例程表
extern curr_proc                    ; 当前执行进程
extern kernel_reenter               ; 记录内核重入次数
extern level0_func                  ; 存放提权成功的函数指针
extern  held_head           ; 导入挂起的中断进程队列

; 导出函数
global  _start                      ;必须为链接器(ld)声明
global down_run                     ; 系统进入宕机
global restart                      ; 进程恢复
global halt                         ; 待机
global level0_sys_call              ; 提权调用函数
global mystical_386_sys_call          ; 系统调用函数
; 所有的异常处理入口
global divide_error
global single_step_exception
global nmi
global breakpoint_exception
global overflow
global bounds_check
global inval_opcode
global copr_not_available
global double_fault
global copr_seg_overrun
global inval_tss
global segment_not_present
global stack_exception
global general_protection
global page_fault
global copr_error
; 所有中断处理入口，一共16个(两个8259A)
global	hwint00
global	hwint01
global	hwint02
global	hwint03
global	hwint04
global	hwint05
global	hwint06
global	hwint07
global	hwint08
global	hwint09
global	hwint10
global	hwint11
global	hwint12
global	hwint13
global	hwint14
global	hwint15


_start:;告诉链接器入口 内核入口
    mov ax,ds
    mov es,ax
    mov ss,ax
    mov fs,ax
    mov esp,StackTop


    sgdt [gdt_ptr]          ; 将GDT指针保存到gdt_ptr中
    call cstart
    lgdt [gdt_ptr]          ; 使用新的GDT
    lidt [idt_ptr]          ; 加载idt指针，在cstart函数中已经将idt_ptr指向新的中断表了
     ; 一个跳转指令，让以上设置及时生效
    jmp SELECTOR_KERNEL_CS:csinit
csinit:
    ; 加载任务状态段 TSS
    xor eax, eax
    mov ax, SELECTOR_TSS
    ltr ax

;    jmp 0x40:0  ;跳转到一个不存在的选择子,触发GP异常
;    ud2;使用非法指令，触发无效的操作码异常
;    int 48
    jmp mystical_main

    jmp $
;============================================================================
;   硬件中断处理
;----------------------------------------------------------------------------
; 为 主从两个8259A 各定义一个中断处理模板
;----------------------------------------------------------------------------
%macro  hwint_master 1
    ; 0 为了支持多进程，发生中断，先保存之前运行进程的状态信息
    call save
    ; 1 在调用对于中断的处理例程前，先屏蔽当前中断，防止短时间内连续发生好几次同样的中断
    in al, INT_M_CTLMASK    ; 取出 主8259A 当前的屏蔽位图
    or al, (1 << %1)        ; 将该中断的屏蔽位置位，表示屏蔽它
    out INT_M_CTLMASK, al   ; 输出新的屏蔽位图，屏蔽该中断

    ; 2 重新启用 主8259A 和中断响应；CPU 响应一个中断后会自动关闭中断，同时 8259A 也会自动关闭自己
    ;   重新启用中断响应是为了及时的响应其他中断，很简单的道理：你在敲键盘的时候？就不允许磁盘中断响应操作磁盘了么？
    mov al, EOI
    out INT_M_CTL, al       ; 设置 EOI 位，重新启用 主8259A
    nop
    sti                     ; 重新启动中断响应

    ; 3 现在调用中断处理例程
    push %1                 ; 压入中断向量号作为参数
    call [irq_handler_table + (4 * %1)] ; 调用中断处理程序表中的相应处理例程，返回值存放在 eax 中
;    add esp, 4              ; 清理堆栈
    pop ecx

    ; 4 最后，判断用户的返回值，如果是DISABLE(0)，我们就直接结束；如果不为0，那么我们就重新启用当前中断
    cli                     ; 先将中断响应关闭，这个时候不允许其它中断的干扰
    cmp eax, DISABLE
    je .0                   ; 返回值 == DISABLE，直接结束中断处理
    ; 返回值 != DISABLE，重新启用当前中断
    in al, INT_M_CTLMASK    ; 取出 主8259A 当前的屏蔽位图
    and al, ~(1 << %1)      ; 将该中断的屏蔽位复位，表示启用它
    out INT_M_CTLMASK, al   ; 输出新的屏蔽位图，启用该中断
;    sti
.0:
    ; 这个 ret 指令将会跳转到我们 save 中手动保存的地址，restart 或 restart_reenter
    ret
;    iretd
%endmacro
align	16
hwint00:		; Interrupt routine for irq 0 (the clock)，时钟中断
 	hwint_master	0

align	16
hwint01:		; Interrupt routine for irq 1 (keyboard)，键盘中断
 	hwint_master	1

align	16
hwint02:		; Interrupt routine for irq 2 (cascade!)
 	hwint_master	2

align	16
hwint03:		; Interrupt routine for irq 3 (second serial)
 	hwint_master	3

align	16
hwint04:		; Interrupt routine for irq 4 (first serial)
 	hwint_master	4

align	16
hwint05:		; Interrupt routine for irq 5 (XT winchester)
 	hwint_master	5

align	16
hwint06:		; Interrupt routine for irq 6 (floppy)，软盘中断
 	hwint_master	6

align	16
hwint07:		; Interrupt routine for irq 7 (printer)，打印机中断
 	hwint_master	7
;----------------------------------------------------------------------------
%macro  hwint_slave 1
    ; 0 为了支持多进程，发生中断，先保存之前运行进程的状态信息
    call save

    ; 1 在调用对于中断的处理例程前，先屏蔽当前中断，防止短时间内连续发生好几次同样的中断
    in al, INT_S_CTLMASK    ; 取出从8259A 当前的屏蔽位图
    or al, (1 << (%1 - 8)) ; 将该中断的屏蔽位置位，表示屏蔽它
    out INT_S_CTLMASK, al   ; 输出新的屏蔽位图，屏蔽该中断

    ; 2 重新启用 主从8259A 和中断响应；因为 从8259A 的中断会级联导致 主8259A也被关闭，所以需要两个都重新启用
    mov al, EOI
    out INT_M_CTL, al       ; 设置 EOI 位，重新启用 主8259A
    nop
    out INT_S_CTL, al       ; 设置 EOI 位，重新启用 从8259A
    sti                     ; 重新启动中断响应

    ; 3 现在调用中断处理例程
    push %1                 ; 压入中断向量号作为参数
    call [irq_handler_table + (4 * %1)] ; 调用中断处理程序表中的相应处理例程，返回值存放在 eax 中
    add esp, 4              ; 清理堆栈

    ; 4 最后，判断用户的返回值，如果是DISABLE(0)，我们就直接结束；如果不为0，那么我们就重新启用当前中断
    cli                     ; 先将中断响应关闭，这个时候不允许其它中断的干扰
    cmp eax, DISABLE
    je .0                   ; 返回值 == DISABLE，直接结束中断处理
    ; 返回值 != DISABLE，重新启用当前中断
    in al, INT_S_CTLMASK    ; 取出 从8259A 当前的屏蔽位图
    and al, ~(1 <<(%1 - 8))      ; 将该中断的屏蔽位复位，表示启用它
    out INT_S_CTLMASK, al   ; 输出新的屏蔽位图，启用该中断
;    sti
.0:
    ; 这个 ret 指令将会跳转到我们 save 中手动保存的地址，restart 或 restart_reenter
    ret
%endmacro

; ---------------------------------
;%macro	hwint_slave	1		; 从中断处理模板
;;	call save				; 调用保存函数,保存当前正在运行的进程的上下文
;
;    in al, INT_S_CTLMASK	; @
;    or al, (1 << (%1 - 8))		; #-> 屏蔽当前中断
;    out INT_S_CTLMASK, al	; @
;
;    mov al, EOI				; @
;    out INT_M_CTL, al		; #-> 置 EOI 位，并重新启用主8259
;    nop                     ; 一些小小的延迟
;    nop
;    out INT_S_CTL, al       ; 重新启用从8259
;    sti                     ; CPU 在响应中断时会自动关闭中断，这句之后就允许响应别的中断
;                            ; 但因为上边已经屏蔽了当前中断，所以当前中断再次发生将不会响应
;    push %1
;    call [irq_handler_table + 4 * %1]	; 执行中断处理程序
;    pop ecx
;    cli
;    test    eax, eax            ; 测试中断处理程序返回值，如果为0，不允许再发送中断
;    jz .0
;    in al, INT_S_CTLMASK		; @
;    and al, ~(1 << (%1 - 8))	; #-> 再次允许发生当前中断，因为上边已经执行完中断处理程序了嘛～
;    out INT_S_CTLMASK, al		; @
;.0:	ret
;%endmacro
; ---------------------------------

;----------------------------------------------------------------------------
align	16
hwint08:		; Interrupt routine for irq 8 (realtime clock).
 	hwint_slave	8

align	16
hwint09:		; Interrupt routine for irq 9 (irq 2 redirected)
 	hwint_slave	9

align	16
hwint10:		; Interrupt routine for irq 10
 	hwint_slave	10

align	16
hwint11:		; Interrupt routine for irq 11
 	hwint_slave	11

align	16
hwint12:		; Interrupt routine for irq 12
 	hwint_slave	12

align	16
hwint13:		; Interrupt routine for irq 13 (FPU exception)
 	hwint_slave	13

align	16
hwint14:		; Interrupt routine for irq 14 (AT winchester)
 	hwint_slave	14

align	16
hwint15:		; Interrupt routine for irq 15
 	hwint_slave	15



;============================================================================
;   异常处理
;----------------------------------------------------------------------------
divide_error:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	0		    ; 中断向量号	= 0
	jmp	exception
single_step_exception:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	1		    ; 中断向量号	= 1
	jmp	exception
nmi:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	2		    ; 中断向量号	= 2
	jmp	exception
breakpoint_exception:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	3		    ; 中断向量号	= 3
	jmp	exception
overflow:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	4		    ; 中断向量号	= 4
	jmp	exception
bounds_check:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	5		    ; 中断向量号	= 5
	jmp	exception
inval_opcode:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	6		    ; 中断向量号	= 6
	jmp	exception
copr_not_available:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	7		    ; 中断向量号	= 7
	jmp	exception
double_fault:
    pop dword[trap_errno]
    call save
    push dword[trap_errno]
	push	8		    ; 中断向量号	= 8 错误码0
	jmp	exception
copr_seg_overrun:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	9		    ; 中断向量号	= 9
	jmp	exception
inval_tss:
    pop dword[trap_errno]
    call save
    push dword[trap_errno]
	push	10		    ; 中断向量号	= 10
	jmp	exception
segment_not_present:
    pop dword[trap_errno]
    call save
    push dword[trap_errno]
	push	11		    ; 中断向量号	= 11 错误码：导致 #NP 异常的段描述符的段选择子索引
	jmp	exception
stack_exception:
    pop dword[trap_errno]
    call save
    push dword[trap_errno]
	push	12		    ; 中断向量号	= 12
	jmp	exception
general_protection:
    pop dword[trap_errno]
    call save
    push dword[trap_errno]
	push	13		    ; 中断向量号	= 13 错误码：如果 #GP 是由于段描述符访问引起的，则报告选择器索引作为错误代码。在所有其他情况下，将返回错误代码0。
	jmp	exception
page_fault:
    pop dword[trap_errno]
    call save
    push dword[trap_errno]
	push	14		    ; 中断向量号	= 14
	jmp	exception
copr_error:
    call save
	push	0xffffffff	; 没有错误代码，用0xffffffff表示
	push	16		    ; 中断向量号	= 16
	jmp	exception

exception:
	call	exception_handler
	add	esp, 4 * 2	    ; 让栈顶指向 EIP，堆栈中从顶向下依次是：EIP、CS、EFLAGS
	cli
    ret                 ; 系统已将异常解决，继续运行！

;============================================================================
;   系统进入宕机
;----------------------------------------------------------------------------
down_run:
    hlt
    jmp down_run
;============================================================================
;   保存所有寄存器，即栈帧；然后做一些堆栈切换的工作
; 执行中断或切换程序时，执行 save 保存 CPU 当前状态，保证之前的程序上下文环境
;----------------------------------------------------------------------------
align 16
save:
    cld
    ; 将所有的32位通用寄存器压入堆栈
    pushad
    ; 然后是特殊段寄存器
    push ds
    push es
    push fs
    push gs
    ; 注意：以上的操作都是在操作进程自己的堆栈

    ; ss 是内核数据段，设置 ds 和 es
    mov dx, ss
    mov ds, dx
    mov es, dx
    mov eax, esp    ; eax 指向进程的栈帧开始处

    inc byte [kernel_reenter]  ; 发生了一次中断，中断重入计数++
    ; 现在判断是不是嵌套中断，是的话就无需切换堆栈到内核栈了
    jnz .reenter                ; 嵌套中断
    ; 从一个进程进入的中断，需要切换到内核栈
    mov esp, StackTop
    push restart                ; 压入 restart 例程，以便一会中断处理完毕后恢复，注意这里压入到的是内核堆栈
    xor ebp,ebp
    jmp [eax + RETADDR - P_STACKBASE]   ; 回到 call save() 之后继续处理中断
align 4
.reenter:
    ; 嵌套中断，已经处于内核栈，无需切换
    push restart_reenter        ; 压入 restart_reenter 地址，以便一会中断处理完毕后恢复，注意这里压入到的是内核堆栈
    jmp [eax + RETADDR - P_STACKBASE]   ; 回到 call save() 之后继续处理中断

;============================================================================
;   mystical的系统调用
; 函数原型：void mystical_386_sys_call(void);
; 系统调用流程：进程A进行系统调用（发送或接收一条消息），系统调用完成后，CPU控制权还是回到进程A手中，除非被调度程序调度。
;----------------------------------------------------------------------------
mystical_386_sys_call:
    ; 这一部分是 save 函数的精简版，为了效率；但其实直接 call save 也没有任何问题
    cld
    sub	esp, 6*4
    push	ebp
   	push	esi
   	push	edi
    push ds
    push es
    push fs
    push gs
    mov dx, ss
    mov ds, dx
    mov es, dx
    mov esi, esp                ; esi 指向进程的栈帧开始处
    inc byte [kernel_reenter]  ; 发生了一次中断，中断重入计数++
    mov esp, StackTop
    ; 重新开启中断
    sti
    ; 进行调用前，先保存进程的栈帧开始地址
    push esi
    ; 这里是重点，将所需参数压入栈中（现在处于核心栈），然后调用 sys_call 去真正调用实际的系统调用例程
    push ebx        ; m_ptr
    push eax        ; src_dest
    push ecx        ; function
    call sys_call
    add esp, 4 * 3  ; clean

    ; 在完成进程恢复之前，关闭中断以保护即将被再次启动的进程的栈帧结构
    pop esi
    mov [esi + EAXREG - P_STACKBASE], eax   ; 将返回值放到调用进程的栈帧结构中的 eax 中
    cli
; 在这里，直接陷入 restart 的代码以重新启动进程/任务运行，这就是我们不需要完整 save 的原因
;============================================================================
;   中断处理完毕，回复之前挂起的进程
;----------------------------------------------------------------------------
restart:
    ; 如果检测到存在被挂起的中断，这些中断是在处理其他中断期间到达的，
    ; 则调用 unhold，这样就允许在任何进程被重新启动之前将所有挂起的中断转换为消息。
    ; 这将暂时地重新关闭中断，但在 unhold 返回之前将再次打开中断。
     cmp dword [held_head], 0      ; 检查该进程的中断挂起队列
     jz  over_unhold         ; 如果该队列是空的，说明进程没有挂起的中断，直接跳转到over_unhold代码处进行进程的切换恢复
     call    unhold          ; 处理挂起的中断队列
over_unhold:
;    push tip_msg
;    call l_print
;    add esp, 4
	mov esp, [curr_proc - P_STACKBASE]	; 离开内核栈，指向运行进程的栈帧，现在的位置是 gs
	lldt [esp + P_LDT_SEL]	            ; 每个进程有自己的 LDT，所以每次进程的切换都需要加载新的ldtr
	; 把该进程栈帧外 ldt_sel 的地址保存到 tss3.sp0 中，下次的 save 将保存所有寄存器到该进程的栈帧中
	lea eax, [esp + P_STACKTOP]
	mov dword [tss + TSS3_S_SP0], eax
restart_reenter:
	; 在这一点上，kernel_reenter 被减1，因为一个中断已经处理完毕
	dec byte [kernel_reenter]
	; 将该进程的栈帧中的所有寄存器信息恢复
    pop gs
    pop fs
    pop es
    pop ds
	popad
	;* 修改栈指针，这样使调用 save 时压栈的地址被忽略。
	add esp, 4
	; 中断返回：恢复eip cs eflags esp ss
	iretd
;============================================================================
;                  CPU 待机
;----------------------------------------------------------------------------
; 本 halt 例程使用指令 hlt 让 CPU 闲置进入待机状态
halt:
    sti                 ; 开中断，为了在待机下快速响应用户事件
    hlt                 ; 处理器休眠，中断可以打断该状态
;    push tip_msg
;    call l_print
;    add esp, 4
    cli                 ; 关中断
    ret
;============================================================================
;   系统提权调用，只能给系统任务使用
; 函数原型：void level0_sys_call(void);
;----------------------------------------------------------------------------
level0_sys_call:
    call save
    jmp [level0_func]       ; 好的，提权成功，我们现在已经处于内核代码段，直接跳转到需要提权的函数执行它
    ret


