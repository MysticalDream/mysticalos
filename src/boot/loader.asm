; DB (Byte        1B)   8bit
; DW (DWord 	  2B) 	16bits
; DD (DDoubleWord 4B) 	32bits
;loader.bin最大63KiB
;90100h-9fc00h
org 0100h
    jmp START


%include "fat12hdr.inc"
%include "load.inc"
%include "pm.inc"


;段基址 段界限 段属性
LABEL_GDT: Descriptor 0,0,0 ;空描述符
LABEL_DESC_CODE: Descriptor	0,0xfffff,DA_32 | DA_CR | DA_LIMIT_4K	; 0~4G，32位可读代码段，粒度为4KB
LABEL_DESC_DATA: Descriptor  0,0xfffff,DA_32 | DA_DRW | DA_LIMIT_4K; 0~4G，32位可读写数据段，粒度为4KB
LABEL_DESC_VIDEO: Descriptor 0xb8000,0xfffff,DA_DRW | DA_DPL3 ; 视频段，特权级3（用户特权级）

GDTLen equ $ - LABEL_GDT                           ; GDT的长度
GDTPtr dw GDTLen - 1                               ; GDT指针.段界限
       dd LOADER_PHY_ADDR + LABEL_GDT              ; GDT指针.基地址


; GDT选择子 ------------------------------------------------------------------
SelectorCode equ LABEL_DESC_CODE - LABEL_GDT             ; 代码段选择子
SelectorData equ LABEL_DESC_DATA - LABEL_GDT             ; 数据段选择子
SelectorVideo equ LABEL_DESC_VIDEO - LABEL_GDT | SA_RPL3  ; 视频段选择子，特权级3（用户特权级）

STACK_BASE  equ	0fc00h

START:
    ;寄存器初始化
    mov ax,cs
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov sp,STACK_BASE

    mov si, loader_msg
    mov di, LOADER_MSG_LEN
    call PrintString

    xor ebx,ebx
    mov di,_MemChkBuf
.loop:
    mov eax,0e820h ; eax = 0000E820h
    mov ecx,20 ; ecx = 地址范围描述符结构的大小
    mov edx,0534D4150h ; edx = 'SMAP'
    int 015h
    ;cf 进位表示错误 CF=1
    jc MemChkFail
    ;CF=0表示成功
    add	di, 20
    inc	dword [_ddMCRCount]	; _ddMCRCount = ARDS 的个数
    cmp ebx,0
    jz MemChkComplete
    jmp .loop
    jmp $
MemChkFail:
    mov si,check_error_msg
    mov di,CHECK_ERROR_MSG_LEN
    call PrintString
    mov dword [_ddMCRCount], 0

MemChkComplete:
    mov si,success_msg
    mov di,SUCCESS_MSG_LEN
    call PrintString

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
    mov ax, KERNEL_SEG  ; es = KERNEL_SEG
    mov es, ax
    mov bx, KERNEL_OFFSET
    mov ax, [wSector]
    mov cl, 1
    call ReadSector
    mov si, KernelFileName      ; ds:si -> Loader的文件名称
    mov di, KERNEL_OFFSET       ; es:di -> KERNEL_SEG:KERNEL_OFFSET -> 加载到内存中的扇区数据
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
    mov si, KernelFileName
    jmp SEARCH_FOR_FILE     ; 重新开始在下一个目录项中查找文件并比较

NEXT_SECTOR_IN_ROOT_DIR:
    add word [wSector], 1   ; 准备开始读取下一个扇区
    jmp SEARCH_FILE_IN_ROOR_DIR_BEGIN

NO_FILE:
    mov si, no_kernel_msg
    mov di, NO_KERNEL_MSG_LEN
    call PrintString
    ; 死循环
    jmp $

FILENAME_FOUND:
    ; 准备参数，开始读取文件数据扇区
    mov ax, RootDirSectors      ; ax = 根目录占用空间（占用的扇区数）
    push eax                    ; 保存eax的值
    mov eax, [es:di + 0x1c]     ; FAT目录项第0x1c处偏移是文件大小
    mov dword [dwKernelSize], eax   ; 保存内核文件大小
    cmp eax, KERNEL_HAVE_SPACE  ; 看看内核文件大小有没有超过我们为其保留的大小
    ja KERNEL_FILE_TOO_LARGE    ; 超过了！ ja:无符号大于则跳转
    pop eax                     ; 恢复eax
    jmp FILE_START_LAOD         ; 没超过，准备开始加载内核文件
KERNEL_FILE_TOO_LARGE:          ; 内核文件太大了，超过了我们给它留的128KB
    mov si, too_larger_msg
    mov di, TOO_LARGER_MSG_LEN
    call PrintString
    jmp $                       ;
FILE_START_LAOD:
    and di, 0xfff0              ; di &= f0, 11111111 11110000，是为了让它指向本目录项条目的开始。
    add di, 0x1a                ; FAT目录项第0x1a处偏移是文件数据所在的第一个簇号
    mov cx, word [es:di]        ; cx = 文件数据所在的第一个簇号
    push cx                     ; 保存文件数据所在的第一个簇号
    ; 通过簇号计算它的真正扇区号
    add cx, ax
    add cx, DeltaSectorNo       ; 簇号 + 根目录占用空间 + 文件开始扇区号 == 文件数据的第一个扇区
    mov ax, KERNEL_SEG
    mov es, ax                  ; es <- KERNEL_SEG
    mov bx, KERNEL_OFFSET       ; bx <- KERNEL_OFFSET
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
    jc KERNEL_GREAT_64KB        ; 如果bx += 扇区字节量，产生了一个进位，说明已经读满64KB，内核文件大于64KB
    jmp CONTINUE_LOADING        ; 内核文件还在64KB内，继续正常加载
KERNEL_GREAT_64KB:
    ; es += 0x1000，es指向下一个段，准备继续加载
    push ax
    mov ax, es
    add ax, 0x1000
    mov es, ax
    pop ax
CONTINUE_LOADING:               ; 继续加载内核文件
    jmp LOADING_FILE
FILE_LOADED:
    call KillMotor  ; 关闭软驱马达
    mov si,kernel_find_msg
    mov di,KERNEL_FIND_MSG_LEN
    call PrintString
    ; 1 首先，进入保护模式必须有 GDT 全局描述符表，我们加载 gdtr（gdt地址指针）
    lgdt	[GDTPtr]
    ; 2 由于保护模式中断处理的方式和实模式不一样，所以我们需要先关闭中断，否则会引发错误
    cli
    ; 3 打开地址线A20，不打开也可以进入保护模式，但内存寻址能力受限（1MB）
    in al, 92h ;南桥芯片内的端口
    or al, 00000010b
    out 92h, al ;打开A20
    ; 4 进入16位保护模式，设置cr0的第0位：PE（保护模式标志）为1
    mov eax, cr0
    or 	eax, 1
    mov cr0, eax
    ; 5 真正进32位入保护模式！前面的4步已经进入了保护模式
    ; 	现在只需要跳入到一个32位代码段就可以真正进入32位保护模式了！
    ;0x0008:00090420
    jmp SelectorCode: dword LOADER_PHY_ADDR + PM_32_START
    ; 如果上面一切顺利，这一行永远不可能执行的到
    jmp $


wRootDirSizeLoop    dw      RootDirSectors  ; 根目录占用的扇区数，在循环中将被被逐步递减至0
wSector             dw      0               ; 要读取的扇区号
isOdd               db      0               ; 读取的FAT条目是不是奇数项
dwKernelSize        dd      0               ; 内核文件的大小

KernelFileName db "KERNEL  BIN",0

loader_msg:
    db 13,10
    db "Hello Loader..."

LOADER_MSG_LEN equ $-loader_msg

check_error_msg:
    db 13,10
    db "memory check error"
CHECK_ERROR_MSG_LEN equ $-check_error_msg


success_msg:
    db 13,10
    db "Memory check success!Start loading the kernel.bin"
SUCCESS_MSG_LEN equ $-success_msg

no_kernel_msg:
    db 13,10
    db "NO KERNEL!"
NO_KERNEL_MSG_LEN equ $-no_kernel_msg

kernel_find_msg:
    db 13,10
    db "finded and loaded kernel.bin"
KERNEL_FIND_MSG_LEN equ $-kernel_find_msg

too_larger_msg:
    db 13,10
    db "Too Large!"
TOO_LARGER_MSG_LEN equ $-too_larger_msg


;16位支持函数库
%include "loader_16lib.inc"
;   32位代码段
[section .code32]
align 32
[bits 32]
PM_32_START:            ; 跳转到这里，说明已经进入32位保护模式
    mov ax, SelectorData
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov ss, ax              ; ds = es = fs = ss = 数据段
    mov esp, TopOfStack     ; 设置栈顶
    mov ax, SelectorVideo
    mov gs, ax              ; gs = 视频段


    ;计算内存大小
    call MyCalcMemSize
    ;打印内存大小
    call PrintMemSize
    ; 启动分页机制
    call SetupPaging
    ;将程序复制到指定位置
    call CopyKernelProgram

    ;保存一些系统信息

    mov dword [BOOT_PARAM_ADDR+0],BOOT_PARAM_MAGIC;引导参数的魔数
    mov eax,[ddMemSize];内存大小
    mov dword[BOOT_PARAM_ADDR+4],eax;第一个引导参数
    mov eax,KERNEL_PHY_ADDR
    add eax,KERNEL_OFFSET
    mov dword[BOOT_PARAM_ADDR+8],eax;内核文件所在的物理地址

    ;跳到内核程序
    jmp SelectorCode:KERNEL_ENTRY_POINT_PHY_ADDR

    jmp $



;32位支持函数库
%include "loader_32lib.inc"


;   计算内存大小
;CalcMemSize:
;    push esi
;    push ecx
;    push edx
;    push edi
;
;    mov esi, MemChkBuf      ; ds:esi -> 缓冲区
;    mov ecx, [ddMCRCount]   ; ecx = 有多少个ARDS，记为i
;.loop:
;    mov edx, 5              ; ARDS有5个成员变量，记为j
;    mov edi, ARDS           ; ds:edi -> 一个ARDS结构
;.1: ; 将缓冲区中的第 i 个ARDS结构拷贝到ds:edi中的ARDS结构
;    push dword [esi]
;    pop eax                 ; ds:eax -> 缓冲区中的第一个ADRS结构
;    ;将eax的内容复制到es:edi的内存空间，复制四个字节，并将edi变化4个字节
;    stosd                   ; 将eax中的一个dword内容拷贝到es:edi中，填充ADRS结构
;    add esi, 4              ; ds:esi指向ARDS中的下一个成员变量
;    dec edx                 ; j--
;    cmp edx, 0
;    jnz .1                  ; j != 0，继续填充
;    ; j == 0，ARDS结构填充完毕
;    cmp dword [ddType], 1
;    jne .2                  ; 不是OS可使用的内存范围，直接进入下个外循环看下一个ARDS
;    ; 是OS可用的地址范围，我们计算这个ARDS的内存大小
;    mov eax, [ddBaseAddrLow]; eax = 基地址低32位
;    add eax, [ddLengthLow]  ; eax = 基地址低32位 + 长度低32位 --> 这个ARDS结构的指代的内存大小
;                            ; 为什么不算高32位？因为32位既可以表示0~4G的内存范围，而32位CPU也只能识别0~4G
;                            ; 我们编写的是32位操作系统，所以高32位是为64位操作系统做准备的，我们不需要。
;    cmp eax, [ddMemSize]
;    jb .2; 无符号小于则跳转
;    mov dword [ddMemSize], eax  ; 内存大小 = 最后一个基地址最大的ARDS的  基地址低32位 + 长度低32位
;.2:
;    loop .loop              ; jmp .loop, ecx--
;
;    pop edi
;    pop edx
;    pop ecx
;    pop esi
;    ret


MyCalcMemSize:
    push eax
    push ebx
    push ecx
    push esi


    ;stosd eax-> es:edi
    mov ecx,[ddMCRCount];ARDS的个数
    mov esi,MemChkBuf;ARDS存储的位置
.1:
    mov ebx,5;5个成员变量
    mov edi,ARDS; ARDS结构位置
.2:
    mov eax,dword [esi]
    stosd;eax->es:edi edi+4
    add esi,4;下一个成员
    dec ebx
    cmp ebx,0
    jne .2
    cmp dword [ddType],1
    jne .3
    mov ebx,[ddBaseAddrLow]
    add ebx,[ddLengthLow]
    cmp ebx,[ddMemSize]
    jb .3;小于跳转
    mov dword[ddMemSize],ebx
.3:
    sub ecx,1
    jnz .1 ;zf=0跳转

    pop esi
    pop ecx
    pop ebx
    pop eax

    ret

;打印内存大小(以KB显示)
PrintMemSize:
    push ebx
    push ecx

    xor edx, edx
    mov eax, [ddMemSize]    ; eax = 内存大小
    mov ebx, 1024
    div ebx                 ; eax / 1024 --> 内存大小(字节) / 1024 = 内存大小(KB)
                            ;被除数:EDX:EAX 商：EAX 余数:EDX

    push eax                ; 保存计算好的内存大小
    ; 显示一个字符串"Memory Size: "
    push strMemSize
;    call PrintStr
    call MyPrintStr
    add esp, 4

    ; 前面已压入eax
;    call PrintHex
    call MyPrintHex
    add esp, 4

    ; 打印"KB"
    push strKB
;    call PrintStr
    call MyPrintStr
    add esp, 4

    pop ecx
    pop ebx
    ret

;============================================================================
;   启动分页机制
; 根据内存的大小来计算应初始化多少的PDE以及多少PTE，我们给每页分4K大小(32位操作系统一般分4K，Windows 32也是如此)
; 注意：页目录表存放在1M(0x100000)~1M+4KB处(0x101000)
;      所有页表存放在1M+4KB(0x101000)~5M+4KB处(0x501000)
;----------------------------------------------------------------------------
SetupPaging:
    xor edx, edx            ; edx = 0
    mov eax, [ddMemSize]    ; eax = 内存大小
    mov ebx, 0x400000       ; 0x400000 = 4M = 4096（页大小） * 1024（页表项），即一个页表表示的内存大小
    div ebx                 ; 内存大小 / 4M
                            ;;被除数:EDX:EAX 商：EAX 余数:EDX
    mov ecx, eax            ; ecx = 需要的页表的个数，即 PDE 应该的页数
    test edx, edx
    jz .no_remainder        ; if(edx == 0) jmp .no_remainder，没有余数
    inc ecx                 ; else ecx++，有余数则需要多一个 PDE 去映射它
.no_remainder:
    push ecx                ; 保存页表个数
    ;为了简化处理，所有线性地址对应相等的物理地址，并且暂不考虑内存空洞
    ; 首先初始化页目录
    mov ax, SelectorData
    mov es, ax
    mov edi, PAGE_DIR_BASE  ; edi = 页目录存放的首地址
    xor eax, eax
    ; eax = PDE，PG_P（该页存在）、PG_US_U（用户级页）、PG_RW_W（可读、写、执行）
    mov eax, PAGE_TABLE_BASE | PG_P | PG_US_U | PG_RW_W
.SetupPDE:  ; 设置 PDE
    stosd                   ; 将eax中的一个dword内容拷贝到es:edi中，填充页目录项结构
                            ;eax->es:edi edi+4
    add eax, 4096           ; 所有页表在内存中连续，PTE 的高20基地址指向下一个要映射的物理内存地址
    loop .SetupPDE           ; 直到ecx = 0，才退出循环，ecx是需要的页表个数

    ; 现在开始初始化所有页表
    pop eax                 ; 取出页表个数
    mov ebx, 1024           ; 每个页表可以存放 1024 个 PTE
    mul ebx                 ; 页表个数 * 1024，得到需要多少个PTE
                            ;被乘数：EAX 乘数：EBX 乘积：EDX:EAX
    mov ecx, eax            ; eax = PTE个数，放在ecx里是因为准备开始循环设置 PTE
    mov edi, PAGE_TABLE_BASE; edi = 页表存放的首地址
    xor eax, eax
    ; eax = PTE，页表从物理地址 0 开始映射，所以0x0 | 后面的属性，该句可有可无，但是这样看着比较直观
    mov eax, 0x0 | PG_P | PG_US_U | PG_RW_W
.SetupPTE:  ; 设置 PTE
    stosd                   ; 将eax中的一个dword内容拷贝到es:edi中，填充页表项结构
    add eax, 4096           ; 每一页指向 4K 的内存空间
    loop .SetupPTE          ; 直到ecx = 0，才退出循环，ecx是需要的PTE个数

    ; 最后设置 cr3 寄存器和 cr0，开启分页机制
    mov eax, PAGE_DIR_BASE
    mov cr3, eax            ; cr3 -> 页目录表
    mov eax, cr0
    or eax, 0x80000000      ; 将 cr0 中的 PG位（分页机制）置位
    mov cr0, eax
    jmp short .SetupPGOK    ; 和进入保护模式一样，一个跳转指令使其生效，标明它是一个短跳转，其实不标明也OK
.SetupPGOK:
     nop                    ; 一个小延迟，给一点时间让CPU反应一下
     nop                    ; 空指令
     push strSetupPaging
     call MyPrintStr
     add esp, 4
     ret



;参数为指向字符串地址
MyPrintStr:
    push edi
    push eax
    push esi
    push edx
    push ebx

    mov edi,[ddDispPosition]
    mov ah,0fh
    mov esi,[esp+4*6]
.1:
    lodsb
    cmp al,0
    je .end
    cmp al,10
    je .ln
    mov [gs:edi],ax
    add edi,2
    jmp .1
.ln:;换行
    push eax
    xor edx,edx
    mov eax,edi
    mov ebx,160
    div ebx;被除数：EDX:EAX 商：EAX 余数：EDX
    inc eax ;行数++
    mov ebx, 160
    mul ebx;被乘数：EAX 乘数：EBX 乘积：EDX:EAX
    mov edi, eax
    pop eax
    jmp .1
.end:
    mov [ddDispPosition],edi;更新显示位置
    pop ebx
    pop edx
    pop esi
    pop eax
    pop edi
    ret
;.....


; 接受的参数是指向要打印的字符串，字符串以0结尾
;PrintStr:
;    push esi
;    push edi
;
;    mov esi, [esp + 4 * 3]      ; 得到字符串地址
;    mov edi, [ddDispPosition]   ; 得到显示位置
;    mov ah, 0xf                 ; 黑底白字
;.1:
;    lodsb                       ; ds:esi -> al, esi++
;    test al, al
;    jz .3                ; 遇到了0，结束打印
;    cmp al, 10
;    je .2
;    ; 如果不是0，也不是'\n'，那么我们认为它是一个可打印的普通字符
;    mov [gs:edi], ax
;    add edi, 2                  ; 指向下一列
;    jmp .1
;.2: ; 处理换行符'\n'
;    push eax
;    mov eax, edi                ; eax = 显示位置
;    mov bl, 160
;    div bl                      ; 显示位置 / 160，商eax就是当前所在行数
;    inc eax                     ; 行数++
;    mov bl, 160
;    mul bl                      ; 行数 * 160，得出这行的显示位置
;    mov edi, eax                ; edi = 新的显示位置
;    pop eax
;    jmp .1
;.3:
;    mov dword [ddDispPosition], edi ; 打印完毕，更新显示位置
;
;    pop edi
;    pop esi
;    ret


; 参数：将要打印的数字
MyPrintHex:
    push edi
    push ecx
    push edx
    push eax


    mov	ah, 0fh			; 0000b: 黑底    1111b: 白字
    mov	al, '0'
    mov	edi, [ddDispPosition];显示位置
    mov	[gs:edi], ax
    add edi, 2
    mov	al, 'x'
    mov	[gs:edi], ax
    add	edi, 2

    mov ecx,8;8个十六进制数字
    mov edx,[esp + 4*5];要打印的数字
.loop:
    rol edx,4
    mov ax,0f0fh
    and al,dl
    add al,'0'
    cmp al,'9'
    jbe .1 ;小于等于
    add al,7
.1:
    mov [gs:edi],ax
    add edi,2
    loop .loop
    mov [ddDispPosition],edi

    pop eax
    pop edx
    pop ecx
    pop edi
    ret



;显示 AL 中的数字
;PrintAl:
;	push ecx
;	push edx
;	push edi
;	push eax
;
;	mov edi, [ddDispPosition]	; 得到显示位置
;
;	mov ah, 0fh		; 0000b: 黑底	1111b: 白字
;	mov dl, al
;	shr al, 4
;	mov ecx, 2
;.start:
;	and al, 0fh
;	cmp al, 9
;	ja	.1
;	add al, '0'
;	jmp	.2
;.1:
;	sub al, 10
;	add al, 'A'
;.2:
;	mov [gs:edi], ax
;	add edi, 2
;
;	mov al, dl
;	loop .start
;
;	mov [ddDispPosition], edi	; 显示完毕后，设置新的显示位置
;
;    pop eax
;	pop edi
;	pop edx
;	pop ecx
;
;	ret

;参数为要打印的数字4字节
;作用:打印十六进制
;PrintHex:
;    mov	ah, 0Fh			; 0000b: 黑底    1111b: 白字
;    mov	al, '0'
;    push	edi
;    mov	edi, [ddDispPosition]
;    mov	[gs:edi], ax
;    add edi, 2
;    mov	al, 'x'
;    mov	[gs:edi], ax
;    add	edi, 2
;    mov	[ddDispPosition], edi	; 显示完毕后，设置新的显示位置
;    pop edi
;
;	mov	eax, [esp + 4]
;	shr	eax, 24
;	call	PrintAl
;
;	mov	eax, [esp + 4]
;	shr	eax, 16
;	call	PrintAl
;
;	mov	eax, [esp + 4]
;	shr	eax, 8
;	call	PrintAl
;
;	mov	eax, [esp + 4]
;	call	PrintAl
;
;	ret


;内存拷贝
;es:dest<-ds:src,size
;MemCpy(dest,src,size)
;返回值 eax为拷贝完成后的新地址
MemCpy:
    push esi
    push ebx
    push ecx

    mov eax,[esp+4*4];dest
    mov ebx,[esp+4*5];src
    mov esi,[esp+4*6];size
    test eax,eax
    jz .null
    test ebx,ebx
    jz .null
    cmp eax,ebx
    jbe .noOverlay
    lea edx,[ebx+esi]
    cmp eax,edx
    jae .noOverlay
    test esi,esi
    jz .final
    dec esi
.overlay:
    movzx ecx,byte [ebx+esi]
    mov byte[eax+esi],cl
    dec esi
    cmp esi,-1
    jnz .overlay
    jmp .final

.noOverlay:
    xor edx,edx
    test esi,esi
    jz .final
.cp:
    movzx ecx,byte [ebx+edx]
    mov byte [eax+edx], cl
    inc edx
    cmp edx,esi
    jnz .cp
.final:
    pop ecx
    pop ebx
    pop esi
    ret
.null:
    xor eax,eax
    pop ecx
    pop ebx
    pop esi
    ret



;============================================================================
;   初始化内核
; 将 KERNEL.BIN 的内容经过调整对齐之后放到内核挂载点处
; 我们通过遍历 Program Header，根据 Program Header 中的信息来确定把什么放入内存，放到什么位置，以及要放多少
;----------------------------------------------------------------------------
;InitKernelFile:
;    xor esi, esi
;    xor ecx, ecx
;    mov cx, word [KERNEL_PHY_ADDR + 44]     ; cx = e_phnum(Program Header的数量)
;    mov esi, [KERNEL_PHY_ADDR + 28]         ; esi = e_phoff(Program header table在文件中的偏移)
;    add esi, KERNEL_PHY_ADDR                ; ds:esi -> 第一个 Program header
;.Begin:
;    mov eax, [esi + 0]                      ; eax -> p_type(段类型)
;    cmp eax, 0
;    jz .NoAction                            ; p_type == 0，是一个不可用的段
;    ; p_type != 0，是一个可用的段
;    push dword [esi + 16]                   ; 压入p_filesz（段在文件中的长度），作为MemCpy的最后一个参数size
;    mov eax, [esi + 4]                      ; eax = p_offset，段的第一个字节在文件中的偏移
;    add eax, KERNEL_PHY_ADDR                ; eax -> 段第一个字节
;    push eax                                ; 压入段第一个字节的地址，作为MemCpy的src参数
;    push dword [esi + 8]                    ; 压入p_vaddr（段的第一个字节在内存中的虚拟地址），作为MemCpy的dest参数
;    call MemCpy                             ; 开始拷贝
;    add esp, 4 * 3                          ; 清理堆栈
;.NoAction:
;    add esi, 32                             ; esi += Program header结构大小
;    dec ecx
;    cmp ecx, 0
;    jnz .Begin                              ; 继续看下一个Program header
;
;    ret



CopyKernelProgram:
    xor ebx,ebx
    xor ecx,ecx
    xor esi,esi
    mov esi,[KERNEL_PHY_ADDR + 28];e_phoff 程序头表偏移
    add esi,KERNEL_PHY_ADDR;程序头的实际偏移
    mov bx,word [KERNEL_PHY_ADDR+42];e_phentsize 程序头表中一个条目的大小
    mov cx,word [KERNEL_PHY_ADDR + 44];e_phnum
.1:
    mov eax,[esi]
    cmp eax,0;p_type=0，元素未使用，其他成员的值未定义
    jz .2
    push dword [esi + 16] ;压入p_filesz（段在文件中的长度），作为MemCpy的最后一个参数size
    mov eax, [esi + 4];eax = p_offset，段的第一个字节在文件中的偏移
    add eax,KERNEL_PHY_ADDR
    push eax;压入段第一个字节的地址，作为MemCpy的src参数
    push dword [esi+8];压入p_vaddr（段的第一个字节在内存中的虚拟地址），作为MemCpy的dest参数
    call MemCpy
    add esp,4*3;还原栈
    ;TODO:这个是新增的代码
    ;填充bss
    mov edx,ecx;保存ecx
    mov eax,[esi+20];p_memsz
    sub eax,[esi+16];比较p_memsz和p_filesz大小
    jz .2
    mov edi,[esi+8];p_vaddr
    add edi,[esi+16];p_vaddr+p_filesz
    mov ecx,eax;需要置0的字节数

    and eax,3;判断是否可以被4整除
    jz .aligned
    ;否则需要先处理不足4字节的部分
    and ecx,0xFFFFFFFC;使得ecx为4的倍数
    cld ; 清空方向标志寄存器
    cmp eax, 1 ; 如果eax等于1，使用stosb指令存储单字节
    je .one_byte
    cmp eax, 2 ; 如果eax等于2，使用stosw指令存储2个字节
    je .two_bytes
    ; 如果eax等于3，使用stosw指令存储2个字节和stosb指令存储1个字节
    xor eax,eax
    stosw
.one_byte:
    xor eax,eax
    stosb ; 存储单字节
    jmp .aligned
.two_bytes:
    xor eax,eax
    stosw ; 存储2个字节
.aligned:
    shr ecx,2
    xor eax, eax ; 清空eax寄存器
    rep stosd ; 将ecx个四字节设置为0 eax->ds:edi , edi+=4
    mov ecx,edx;恢复ecx

.2:
    add esi,ebx
    loop .1
    ret





; 32位数据段
;===========================
;label可以在它们的前面有空格,或其他任何东西。
;label后面的冒号同样也是可选的。
;注意到，这意味着如果你想要写一行'lodsb'，但却错误地写成了'lodab'.
;这仍将是有效的一行，但这一行不做任何事情，只是定义了一个 label
;===========================
[section .data32]
align 32
DATA32:
;16位实模式下使用的符号
; 字符串 ---
_strMemSize:        db "The Memory Size: ", 0
_strKB:             db "KB", 10, 0
_strSetupPaging:    db "Setup paging.", 10, 0
; 变量 ---
_ddMCRCount:        dd 0        ; 检查完成的ARDS的数量，为0则代表检查失败
_ddMemSize:         dd 0        ; 内存大小
_ddDispPosition:    dd (80 * 6 + 0) * 2 ; 初始化显示位置为第 6 行第 0 列
; 地址范围描述符结构(Address Range Descriptor Structure) 20字节
_ARDS:
    _ddBaseAddrLow:  dd 0        ; 基地址低32位
    _ddBaseAddrHigh: dd 0        ; 基地址高32位
    _ddLengthLow:    dd 0        ; 内存长度（字节）低32位
    _ddLengthHigh:   dd 0        ; 内存长度（字节）高32位
    _ddType:         dd 0        ; ARDS的类型，用于判断是否可以被OS使用
_MemChkBuf:          times 256 db 0

;32位保护模式下使用的符号

strMemSize          equ LOADER_PHY_ADDR + _strMemSize
strKB               equ LOADER_PHY_ADDR + _strKB
strSetupPaging      equ LOADER_PHY_ADDR + _strSetupPaging

ddMCRCount          equ LOADER_PHY_ADDR + _ddMCRCount
ddMemSize           equ LOADER_PHY_ADDR + _ddMemSize
ddDispPosition      equ LOADER_PHY_ADDR + _ddDispPosition
ARDS                equ LOADER_PHY_ADDR + _ARDS
    ddBaseAddrLow   equ LOADER_PHY_ADDR + _ddBaseAddrLow
    ddBaseAddrHigh  equ LOADER_PHY_ADDR + _ddBaseAddrHigh
    ddLengthLow     equ LOADER_PHY_ADDR + _ddLengthLow
    ddLengthHigh    equ LOADER_PHY_ADDR + _ddLengthHigh
    ddType          equ LOADER_PHY_ADDR + _ddType
MemChkBuf           equ LOADER_PHY_ADDR + _MemChkBuf
; 堆栈就在数据段的末尾，一共给这个32位代码段堆栈分配4KB
StackSpace: times 0x1000    db 0
TopOfStack  equ LOADER_PHY_ADDR + $     ; 栈顶