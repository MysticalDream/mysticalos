section .text
    ; 设置入口点为_start
    global _start

_start:
    ; 读取光标位置
    mov ah, 0x03
    xor bh, bh
    int 0x10

    ; 设置字符串msg1长度
    mov cx, 378
    ; 设置属性为正常显示
    mov bx, 0x0007
    ; 设置字符串msg1的地址
    mov bp, msg1
    ; 设置es寄存器为0x07c0，es:bp是显示字符串的地址
    mov ax, 0x07c0
    mov es, ax
    ; 写入字符串，移动光标
    mov ax, 0x1301
    int 0x10

inf_loop:
    jmp inf_loop

msg1:
    db 13, 10
    db "#     #"
    db 13, 10
    db "##   ##   #   #   ####    #####     #     ####     ##    #"
    db 13, 10
    db "# # # #    # #   #          #       #    #    #   #  #   #"
    db 13, 10
    db "#  #  #     #     ####      #       #    #       #    #  #"
    db 13, 10
    db "#     #     #         #     #       #    #       ######  #"
    db 13, 10
    db "#     #     #    #    #     #       #    #    #  #    #  #"
    db 13, 10
    db "#     #     #     ####      #       #     ####   #    #  ######"
    db 13, 10, 13, 10

    ;设置引导扇区标记0xAA55，才能引导
    times 510 - ($ - $$) db 0
    dw 0xAA55
