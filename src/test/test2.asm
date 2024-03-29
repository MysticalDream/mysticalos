;基地址 段界限 段属性
;32bit  20bit 12bit
;段界限:最大表示1Mib
;总共8字节64位
;第一个32位
; [0,15]:段界限
;[16,31]:基地址
;第二个32位:
;[0,7]:基地址
;[8,11]:Type
;[12]:S
;[13,14]:DPL
;[15]:P
;[16,19]:段界限
;[20]:AVL
;[21]:0
;[22]:D/B
;[23]:G tip:为0，单位就是1字节 一个段最大1MiB;为1 ，单位是4096字节，一个段最大 1MiB*4096=4GB
;[24,31]:基地址

;段基址 段界限 段属性
%macro Descriptor 3
    dw %2 & 0FFFFh                          ;段界限1(2字节)
    dw %1 & 0FFFFh                          ;段基址1 (2字节)
    db (%1 >> 16) & 0FFh                    ;段基址2 (1字节)
    dw ((%2 >>8) & 0F00h) | (%3 & 0F0FFh)   ;属性1 + 段界限2 + 属性2 ( 2 字节)
    db (%1 >> 24) & 0FFh                    ;段基址 3 (1字节)
%endmacro ; 共 8 字节


;============================================================================
;   GDT全局描述符表相关信息以及堆栈信息
;----------------------------------------------------------------------------
; 描述符                        基地址        段界限       段属性
LABEL_GDT:			Descriptor	0,          0,          0							; 空描述符，必须存在，不然CPU无法识别GDT
LABEL_DESC_CODE:	Descriptor	0,          0xfffff,    DA_32 | DA_CR | DA_LIMIT_4K	; 0~4G，32位可读代码段，粒度为4KB
LABEL_DESC_DATA:    Descriptor  0,          0xfffff,    DA_32 | DA_DRW | DA_LIMIT_4K; 0~4G，32位可读写数据段，粒度为4KB
LABEL_DESC_VIDEO:   Descriptor  0xb8000,    0xfffff,    DA_DRW | DA_DPL3            ; 视频段，特权级3（用户特权级）
; GDT全局描述符表 -------------------------------------------------------------
GDTLen              equ $ - LABEL_GDT                           ; GDT的长度
GDTPtr:             dw GDTLen - 1                               ; GDT指针.段界限
                    dd LOADER_PHY_ADDR + LABEL_GDT              ; GDT指针.基地址


; LOADER.BIN 被加载的位置　--- 段地址
LOADER_SEG        equ     0x9000
; LOADER.BIN 被加载的位置　--- 偏移地址
LOADER_OFFSET      equ     0x100
; LOADER.BIN 被加载到的位置　--- 物理地址　(= LOADER_SEG * 10h)
LOADER_PHY_ADDR     equ LOADER_SEG * 10h

;----------------------------------------------------------------------------
; 描述符类型值说明
; 其中:
;       DA_  : Descriptor Attribute
;       D    : 数据段
;       C    : 代码段
;       S    : 系统段
;       R    : 只读
;       RW   : 读写
;       A    : 已访问
;       其它 : 可按照字面意思理解
;----------------------------------------------------------------------------
DA_32           equ 4000h       ; 32 位段
DA_LIMIT_4K     equ 8000h       ; 段界限粒度为4K字节

DA_DPL0         equ 10h         ; 特权级0
DA_DPL1         equ 20h         ; 特权级1
DA_DPL2         equ 40h         ; 特权级2
DA_DPL3         equ 60h         ; 特权级3
;----------------------------------------------------------------------------
; 存储段描述符类型值说明
;----------------------------------------------------------------------------
DA_DR           equ 90h         ; 存在的只读数据段属性值
DA_DRW          equ 92h         ; 存在的可读写的数据段属性值
DA_DRWA         equ 93h         ; 存在的已访问可读写数据段属性值
DA_C            equ 98h         ; 存在的只执行代码段属性值
DA_CR           equ 9Ah         ; 存在的可执行可读代码段属性值
DA_CC0          equ 9Ch         ; 存在的可执行一致代码段属性值
DA_CC0R         equ 9Eh         ; 存在的可执行可读一致代码段属性值
;----------------------------------------------------------------------------
; 系统段描述符类型值说明
;----------------------------------------------------------------------------
DA_LDT          equ 82h         ; 局部描述符表段类型值
DA_TaskGate     equ 85h         ; 任务门类型值
DA_386TSS       equ 89h         ; 可用386任务状态段类型值
DA_386CGate     equ 8Ch         ; 386调用门类型值
DA_386IGate     equ 8Eh         ; 386中断门类型值
DA_386TGate     equ 8Fh         ; 386陷阱门类型值
;----------------------------------------------------------------------------