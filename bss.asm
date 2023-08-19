[section .data]
trap_errno dd 0xffffffff

[section .bss]
StackSpace: resb 4*1024;4kb栈空间
StackTop:


[section .text]
global _start

_start:
    mov ax,ds

