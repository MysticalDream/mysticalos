; DB (Byte        1B)   8bit
; DW (DWord 	  2B) 	16bits
; DD (DDoubleWord 4B) 	32bits

;%define	_BOOT_DEBUG_
%ifdef	_BOOT_DEBUG_
	org  100h			; 调试状态, 做成 .COM 文件, '.COM'文件预期被装载到它们所在段的'100h'偏移处(尽管段可能会变)。然后从100h处开始执行
%else
	org  07c00h			; Boot 状态, 指示编译器下面的偏移地址将加上这个值
%endif

%ifdef	_BOOT_DEBUG_
    STACK_BASE		equ	100h	; 调试状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%else
    STACK_BASE		equ	0h	; Boot状态下堆栈基地址(栈底, 从这个位置向低地址生长)
%endif

; LOADER加载到的段地址
LOADER_SEG      equ 09000h
; LOADER加载到的偏移地址
LOADER_OFFSET   equ 0100h

BS_jmpBoot:
    jmp short LABEL_START
    nop
    ; 导入FAT12头以及相关常量信息
    %include "fat12hdr.inc"

; 程序主体
LABEL_START:
    ;寄存器初始化
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,STACK_BASE


;    ; 清屏,清理BIOS的输出
;    mov	ax, 0x0600		; AH = 6,  AL = 0h
;    mov	bx, 0x0700		; 黑底白字(BH = 07h)
;    mov	cx, 0			; 左上角: (0, 0)
;    mov	dx, 0x0184f		; 右下角: (24, 79)
;    int	0x10				; int 10h
;    ;设置光标位置
;    mov ax,0x0200
;    mov bx,0
;    mov dx,0
;    int 0x10

    ;置显示模式达到清屏效果
    mov ah, 00h  ; 0x00表示清屏
    mov al, 03h  ; 0x03表示清除整个屏幕
    int 10h      ; 调用10h中断，清屏


    ;显示字符串 "Hello MysticalOS..."
    ;字符串msg1偏移地址
    mov si,msg1
    ;字符串msg1长度
    mov di, MSG1_LEN
    ;打印字符串msg1
    call PrintString
    add sp,4

    ;操作软盘前，现将软驱复位
    xor ah, ah
    xor dl, dl
    int 13h

    ;在软盘A中开始寻找文件
    ;SectorNoOfRootDirectory:Root Directory 的第一个扇区号
    mov word [wSector], SectorNoOfRootDirectory     ; 读取软盘的根目录扇区号
SEARCH_FILE_IN_ROOR_DIR_BEGIN:
    cmp word [wRootDirSizeLoop], 0
    jz NO_FILE
    dec word [wRootDirSizeLoop] ; wRootDirSizeLoop--

    ; 读取扇区
    mov ax, LOADER_SEG  ; es = LOADER_SEG
    mov es, ax
    mov bx, LOADER_OFFSET
    mov ax, [wSector]
    mov cl, 1
    call ReadSector
    mov si, LOADER_FILENAME      ; ds:si -> Loader的文件名称
    mov di, LOADER_OFFSET       ; es:di -> LOADER_SEG:LOADER_OFFSET -> 加载到内存中的扇区数据
    ;将方向标志位清零
    cld     ; DF=0向内存地址增大的方向(si++,di++)
    ; 开始在扇区中寻找文件，比较文件名
    mov dx, 16                  ; 一个扇区512字节，FAT目录项占用32个字节，512/32 = 16，所以一个扇区有16个目录项

SEARCH_FOR_FILE:
    cmp dx, 0
    jz NEXT_SECTOR_IN_ROOT_DIR                 ; 读完整个扇区，依旧没找到，准备加载下一个扇区
    dec dx              ; dx--
    ; 应该开始比较目录项中的文件名了
    mov cx, 11
CMP_FILENAME:
    cmp cx, 0
    jz FILENAME_FOUND           ; cx = 0，整个文件名里的字符都匹配上了，我们发现它了
    dec cx          ; cx--
    lodsb           ; ds:si -> al, si++
    cmp al, byte [es:di]    ; 比较字符
    je GO_ON                ; 字符相同，准备继续比较下一个
    jmp DIFFERENT           ; 只要有一个字符不相同，就表明本目录项不是我们要寻找的文件的目录项

GO_ON:
    inc di
    jmp  CMP_FILENAME
DIFFERENT:
    and di, 0xfff0      ; di &= f0, 11111111 11110000，是为了让它指向本目录项条目的开始。
    add di, 32          ; di += 32， 让di指向下一个目录项
    mov si, LOADER_FILENAME
    jmp SEARCH_FOR_FILE     ; 重新开始在下一个目录项中查找文件并比较

NEXT_SECTOR_IN_ROOT_DIR:
    add word [wSector], 1   ; 准备开始读取下一个扇区
    jmp SEARCH_FILE_IN_ROOR_DIR_BEGIN

NO_FILE:
    mov si, msg2
    mov di, MSG2_LEN
    call PrintString
    ; 死循环
    jmp $

FILENAME_FOUND:
    ; 准备参数，开始读取文件数据扇区
    mov ax, RootDirSectors      ; ax = 根目录占用空间（占用的扇区数）
    and di, 0xfff0              ; di &= f0, 11111111 11110000，是为了让它指向本目录项条目的开始。
    add di, 0x1a                ; FAT目录项第0x1a处偏移是文件数据所在的第一个簇号
    mov cx, word [es:di]        ; cx = 文件数据所在的第一个簇号
    push cx                     ; 保存文件数据所在的第一个簇号
    ; 通过簇号计算它的真正扇区号
    add cx, ax
    add cx, DeltaSectorNo       ; 簇号 + 根目录占用空间 + 文件开始扇区号 == 文件数据的第一个扇区
    mov ax, LOADER_SEG
    mov es, ax                  ; es <- LOADER_SEG
    mov bx, LOADER_OFFSET       ; bx <- LOADER_OFFSET
    mov ax, cx                  ; ax = 文件数据的第一个扇区

LOADING_FILE:
    ; 我们每读取一个数据扇区，就在后接着打印一个点，形成一种动态加载的动画。
    ; 0x10中断，0xe功能 --> 在光标后打印一个字符
    push ax
    push bx
    mov ah, 0xe
    mov al, '.'
    mov bl, 0xf
    int 0x10
    pop bx
    pop ax

    mov cl, 1                   ; 读1个
    call ReadSector             ; 读取
    pop ax                      ; 取出前面保存的文件的的簇号
    call GET_FATEntry           ; 通过簇号获得该文件的下一个FAT项的值
    cmp ax, 0xff8
    ;无符号大于等于则跳转
    jae FILE_LOADED             ; 加载完成...
    ; FAT项的值 < 0xff8，那么我们继续设置下一次要读取的扇区的参数
    ; 通过簇号计算它的真正扇区号
    push ax                     ; 保存簇号
    mov dx, RootDirSectors
    add ax, dx
    add ax, DeltaSectorNo       ; 簇号 + 根目录占用空间 + 文件开始扇区号 == 文件数据的扇区
    add bx, [BPB_BytsPerSec]    ; bx += 扇区字节量
    jmp LOADING_FILE
FILE_LOADED:
    mov si, msg3
    mov di, MSG3_LEN
    call PrintString
    jmp LOADER_SEG:LOADER_OFFSET    ; 跳转到Loader程序，至此我们的引导程序使命结束


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
    mov ax, LOADER_SEG - 0x100
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
    mov bx, 0               ; bx = 0，es:bx --> (LOADER_SEG - 0x100):0
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

;PrintString函数
;si-->字符串偏移 di-->字符串长度
;下面不可使用的寄存器 ax bx cx dx
PrintString:
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
    ret



wRootDirSizeLoop    dw      RootDirSectors  ; 根目录占用的扇区数，在循环中将被被逐步递减至0
wSector             dw      0               ; 要读取的扇区号
isOdd               db      0               ; 读取的FAT条目是不是奇数项

LOADER_FILENAME db "LOADER  BIN" ,0

msg1:
    db 13,10
    db "Hello MysticalOS..."
MSG1_LEN equ $-msg1

msg2:
    db 13,10
    db "NO LOADER!"
MSG2_LEN equ $-msg2

msg3:
    db 13,10
    db "Loaded!"
MSG3_LEN equ $-msg3
    ; 必须在最后两个字节 $:表示是的当前行 $$代表本节section的起始地址
    times 510-($-$$) db 0
    ; 设置引导扇区标记 0xAA55
    ; 必须有它，才能引导
    dw   0AA55h

