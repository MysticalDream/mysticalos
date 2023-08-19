; Disassembly of file: test.o
; Sat Apr 15 20:44:07 2023
; Mode: 32 bits
; Syntax: YASM/NASM
; Instruction set: 80386


global my_memcpy: function


SECTION .text   align=16 execute                        ; section number 1, code

my_memcpy:; Function begin
        push    esi                                     ; 0000 _ 56
        push    ebx                                     ; 0001 _ 53
        mov     eax, dword [esp+0CH] ;目的地址                   ; 0002 _ 8B. 44 24, 0C
        mov     ebx, dword [esp+10H] ;源地址                  ; 0006 _ 8B. 5C 24, 10
        mov     esi, dword [esp+14H] ;长度                  ; 000A _ 8B. 74 24, 14
        test    eax, eax                                ; 000E _ 85. C0
        jz      ?_005                                   ; 0010 _ 74, 5E
        test    ebx, ebx                                ; 0012 _ 85. DB
        jz      ?_005                                   ; 0014 _ 74, 5A
        cmp     eax, ebx                                ; 0016 _ 39. D8
        jbe     ?_003                                   ; 0018 _ 76, 36
        lea     edx, [ebx+esi]                          ; 001A _ 8D. 14 33
        cmp     eax, edx                                ; 001D _ 39. D0
        nop                                             ; 001F _ 90
        jnc     ?_003 ;=jae ?_003                            ; 0020 _ 73, 2E
        lea     edx, [esi-1H]                           ; 0022 _ 8D. 56, FF
        add     ebx, edx                                ; 0025 _ 01. D3
        test    esi, esi                                ; 0027 _ 85. F6
        lea     ecx, [eax+edx]                          ; 0029 _ 8D. 0C 10
        jz      ?_002                                   ; 002C _ 74, 1B
        neg     esi                                     ; 002E _ F7. DE
        add     ebx, esi                                ; 0030 _ 01. F3
        add     esi, ecx                                ; 0032 _ 01. CE
; Filling space: 4H
; Filler type: lea with same source and destination
;       db 8DH, 74H, 26H, 00H

ALIGN   8
?_001:  movzx   ecx, byte [ebx+edx+1H]                  ; 0038 _ 0F B6. 4C 13, 01
        mov     byte [esi+edx+1H], cl                   ; 003D _ 88. 4C 16, 01
        sub     edx, 1                                  ; 0041 _ 83. EA, 01
        cmp     edx, -1                                 ; 0044 _ 83. FA, FF
        jnz     ?_001                                   ; 0047 _ 75, EF
?_002:  pop     ebx                                     ; 0049 _ 5B
        pop     esi                                     ; 004A _ 5E
        ret                                             ; 004B _ C3

; Filling space: 4H
; Filler type: lea with same source and destination
;       db 8DH, 74H, 26H, 00H

ALIGN   8
?_003:  xor     edx, edx                                ; 0050 _ 31. D2
        test    esi, esi                                ; 0052 _ 85. F6
        jz      ?_002                                   ; 0054 _ 74, F3
; Filling space: 2H
; Filler type: NOP with prefixes
;       db 66H, 90H

ALIGN   8
?_004:  movzx   ecx, byte [ebx+edx]                     ; 0058 _ 0F B6. 0C 13
        mov     byte [eax+edx], cl                      ; 005C _ 88. 0C 10
        add     edx, 1                                  ; 005F _ 83. C2, 01
        cmp     edx, esi                                ; 0062 _ 39. F2
        jnz     ?_004                                   ; 0064 _ 75, F2
        pop     ebx                                     ; 0066 _ 5B
        pop     esi                                     ; 0067 _ 5E
        ret                                             ; 0068 _ C3

; Filling space: 7H
; Filler type: lea with same source and destination
;       db 8DH, 0B4H, 26H, 00H, 00H, 00H, 00H

ALIGN   8
?_005:  xor     eax, eax                                ; 0070 _ 31. C0
        pop     ebx                                     ; 0072 _ 5B
        pop     esi                                     ; 0073 _ 5E
        ret                                             ; 0074 _ C3
; my_memcpy End of function


SECTION .data   align=1 noexecute                       ; section number 2, data


SECTION .bss    align=1 noexecute                       ; section number 3, bss


