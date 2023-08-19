org 07c00h

LOADER_OFF EQU 1
LOADER_CNTS EQU 4
LOADER_SEG EQU 09000h
LOADER_STACK_TOP EQU 09c000h


entry:
    mov ax, cs
	mov ds, ax
	mov ss, ax
	mov sp, 0
	mov ax, 0xb800
	mov es, ax

    call clean_screen

	;show 'BOOT'
	mov byte [es:0],'B'
	mov byte [es:1],0x07
	mov byte [es:2],'O'
	mov byte [es:3],0x07
	mov byte [es:4],'O'
	mov byte [es:5],0x07
	mov byte [es:6],'T'
	mov byte [es:7],0x07

    mov ax, LOADER_SEG
    mov dx, 0
    mov si, LOADER_OFF
    mov cx, LOADER_CNTS
    xor bx, bx
    call read_sectors
    jmp LOADER_SEG:0



clean_screen:
	mov ax, 0x02
	int 0x10
    ret

; function: read a sector data from floppy
; @input:
;       es: dx -> buffer seg: off
;       si     -> lba
floppy_read_sector:
	push ax
	push cx
	push dx
	push bx

    ;NS为每磁道扇区数，NH为磁头数
    ;C、H、S分别表示磁盘的柱面、磁头和扇区编号
    ;LBA表示逻辑扇区号
    ;C=(LBA div NS)div NH
    ;H=(LBA div NS) mod NH
    ;S=(LBA mod NS)+1
	mov ax, si
	xor dx, dx
	;每磁道扇区数
	mov bx, 18

   ;被除数:DX:AX 商:AX 余数:DX
	div bx
	inc dx
	;cl 物理扇区编号
	mov cl, dl
	xor dx, dx
	;磁头数为2
	mov bx, 2

	div bx
    ;dh 磁头
	mov dh, dl
	xor dl, dl
	;ch 柱面
	mov ch, al
	pop bx
.1:
    ;al 扇区数
	mov al, 0x01
	mov ah, 0x02
	int 0x13
	jc .1
	pop dx
	pop cx
	pop ax
	ret

read_sectors:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

.reply:
    mov es, ax
    call floppy_read_sector
    add bx, 512     ; next buffer

    inc si          ; next lba
    loop .reply
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

times 510-($-$$) db 0
dw 0xaa55

