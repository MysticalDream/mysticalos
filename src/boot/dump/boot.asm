org 0x7c00
    jmp START
    nop

StackBase equ 0x7c00

BootMessage db "Booting..."

START:
   mov ax,cs
   mov ds,ax
   mov ss,ax
   mov sp,StackBase
   ;打印字符串 Booting...
   mov al,1
   mov bh,0
   mov bl,0x07;黑底白字
   mov cx,10
   mov dh,0
   mov dl,0
   ;es=ds
   push ds
   pop es
   mov bp,BootMessage
   mov ah,0x13
   int 0x10

   jmp $

;time n m n:重复多少次，m:定义的数据
times 510-($-$$) db 0
dw 0xaa55 ;主引导扇区的结尾
