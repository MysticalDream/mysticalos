; 函数: ReadSector
;从第 ax 个 Sector 开始, 将 cl 个 Sector 读入 es:bx 中
;es:bx
ReadSector:
	push	bp
	mov	bp, sp
	sub	esp, 2			; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

	mov	byte [bp-2], cl
	push	bx			; 保存 bx
	mov	bl, [BPB_SecPerTrk]	; bl: 除数
	div	bl			; y 在 al 中, z 在 ah 中
	inc	ah			; z ++
	mov	cl, ah			; cl <- 起始扇区号
	mov	dh, al			; dh <- y
	shr	al, 1			; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
	mov	ch, al			; ch <- 柱面号
	and	dh, 1			; dh & 1 = 磁头号
	pop	bx			; 恢复 bx
	mov	dl, [BS_DrvNum]		; 驱动器号 (0 表示 A 盘)
.GoOnReading:
	mov	ah, 2				; 读
	mov	al, byte [bp-2]		; 读 al 个扇区
	int	13h
	jc	.GoOnReading		; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

	add	esp, 2
	pop	bp

	ret

; 作用：找到簇号为 ax 在 FAT 中的条目，然后将结果放入 ax 中。
; 注意：中间我们需要加载 FAT表的扇区到es:bx处，所以我们需要先保存es:bx
GET_FATEntry:
    push es
    push bx

    ; 在加载的段地址处开辟出新的空间用于存放加载的FAT表
    push ax
    mov ax, KERNEL_SEG - 0x100
    mov es, ax
    pop ax

    ; 首先计算出簇号在FAT中的字节偏移量，然后还需要计算出该簇号的奇偶性、
    ; 偏移值: 簇号 * 3 / 2 的商，因为3个字节表示2个簇，所以字节和簇之间的比例就是3:2。
    mov byte [isOdd], 0     ; isOdd = FALSE
    mov bx, 3               ; bx = 3
    mul bx                  ; ax * 3 --> dx存放高8位，ax存放低8位
    mov bx, 2               ; bx = 2
    div bx                  ; dx:ax / 2 --> ax存放商，dx存放余数。
    cmp dx, 0
    je EVEN
    mov byte [isOdd], 1     ; isOdd = TRUE
EVEN:       ; 偶数
    ; FAT表占 9个扇区 ， 簇号 5 ， 5 / 512 -- 0 .. 5， FAT表中的0扇区， FAT表0扇区中这个簇号所在偏移是5
    ; 570   570 / 512 -- 1 .. 58， FAT表中的1扇区， FAT表1扇区中这个簇号所在偏移是58
    xor dx, dx              ; dx = 0
    mov bx, [BPB_BytsPerSec]; bx = 每扇区字节数
    div bx                  ; dx:ax / 每扇区字节数，ax(商)存放FAT项相对于FAT表中的扇区号，
                            ; dx(余数)FAT项在相对于FAT表中的扇区的偏移。
    push dx                 ; 保存FAT项在相对于FAT表中的扇区的偏移。
    mov bx, 0               ; bx = 0，es:bx --> (KERNEL_SEG - 0x100):0
    add ax, SectorNoOfFAT1  ; 此句执行之后的 ax 就是 FATEntry 所在的扇区号
    mov cl, 2               ; 读取两个扇区
    call ReadSector         ; 一次读两个，避免发生边界错误问题，因为一个FAT项可能会跨越两个扇区
    pop dx                  ; 恢复FAT项在相对于FAT表中的扇区的偏移。
    add bx, dx              ; bx += FAT项在相对于FAT表中的扇区的偏移，得到FAT项在内存中的偏移地址，因为已经将扇区读取到内存中
    mov ax, [es:bx]         ; ax = 簇号对应的FAT项，但还没完成
    cmp byte [isOdd], 1
    ;jne 不等于则跳转
    jne EVEN_2
    ; 奇数FAT项处理
    ;右移4位
    shr ax, 4               ; 需要将低四位清零（他是上一个FAT项的高四位）
    jmp GET_FATEntry_OK
EVEN_2:         ; 偶数FAT项处理
    and ax, 0fffh   ; 需要将高四位清零（它是下一个FAT项的低四位）
GET_FATEntry_OK:
	pop bx
	pop es
    ret

PrintString:
    push bp
    mov bp,sp
    ;读入光标位置
    mov ah,03h
    xor bh,bh
    int 10h
    ;字符串长度
    mov cx,di
    ;第 0 页，属性 7（正常）
    mov bx,0007h
    ;字符串msg
    mov bp,si
    ;es:bp 是显示字符串的地址
    mov ax,ds
    mov es,ax
    ;写入字符串，移动光标
    mov ax,1301h
    ;BIOS中断
    int 10h
    pop bp
    ret

;函数名: KillMotor
;作用:
;关闭软驱马达，有时候软驱读取完如果不关闭马达，马达会持续运行且发出声音
 KillMotor:
 	push dx
 	mov	dx, 03F2h
 	mov	al, 0
 	out	dx, al
 	pop	dx
 	ret