PLATFORM=Linux

# 这个值必须存在且相等在文件"load.inc"中的 'KERNEL_ENTRY_POINT_PHY_ADDR'
ENTRY_POINT=0x1000


# 库文件所在目录
LIB_ANSI = src/lib/ansi
LIB_STDIO = src/lib/stdio
LIB_I386 = src/lib/i386

#目录
SRC_DIR=src
INCLUDE=include
SRC_KERNEL=$(SRC_DIR)/kernel
BOOT_DIR=$(SRC_DIR)/boot
TARGET_DIR=target
TARGET_BOOT=$(TARGET_DIR)/boot
TARGET_KERNEL=$(TARGET_DIR)/kernel
TARGET_LIB=$(TARGET_DIR)/lib


# 编译器以及编译参数
ASM=nasm
ASM_BIN_TYPE=-f bin
ASM_INCLUDE_ARG=-I src/boot/include/
ASM_ELF_ARG=-f elf  -I $(SRC_KERNEL)/
MACRO_DEFINITION=
#当用户自定义的函数与内建函数冲突时，若在gcc的编译选项中加上-fno-builtin 时，则表示不使用C语言的内建函数。
#-Wall编译后显示所有警告
C_ARG=-c -I$(INCLUDE) -fno-builtin -Wall $(MACRO_DEFINITION)
CC=gcc
LD=ld
#-Map=<mapfile>:
#将链接映射输出到指定的文件
LDFlags=-Ttext $(ENTRY_POINT) -Map kernel.map




MYSTICAL_BOOT=$(TARGET_BOOT)/boot.bin $(TARGET_BOOT)/loader.bin
MYSTICAL_KERNEL=$(TARGET_KERNEL)/kernel.bin

# 内核，只实现基本功能
KernelObjs= $(TARGET_KERNEL)/kernel.o $(TARGET_KERNEL)/main.o $(TARGET_KERNEL)/kernel_386lib.o \
            $(TARGET_KERNEL)/protect.o $(TARGET_KERNEL)/table.o $(TARGET_KERNEL)/start.o \
            $(TARGET_KERNEL)/exception.o $(TARGET_KERNEL)/misc.o $(TARGET_KERNEL)/i8259.o \
            $(TARGET_KERNEL)/clock.o $(TARGET_KERNEL)/process.o $(TARGET_KERNEL)/message.o \
            $(TARGET_KERNEL)/dump.o $(TARGET_KERNEL)/rtccmos.o


# 内核之外所需要的库，有系统库，也有提供给用户使用的库
LibObjs = $(AnsiObjs) $(StdioObjs) $(I386Objs)
AnsiObjs = $(TARGET_LIB)/ansi/string.o $(TARGET_LIB)/ansi/memcmp.o $(TARGET_LIB)/ansi/stringc.o
StdioObjs = $(TARGET_LIB)/stdio/vsprintf.o
I386Objs= $(TARGET_LIB)/i386/rts/sendrec.o

Objs= $(KernelObjs) $(LibObjs)

#软盘镜像
FD = mysticalos.img
#镜像挂载点
MOUNTPOINT = /mnt/floppy

#虚拟机

BOCHS=E:/software_file/Bochs/Bochs-2.7/bochs.exe
QEMU=E:/software_file/msys64/mingw64/bin/qemu-system-i386.exe
#QEMU=/ucrt64/bin/qemu-system-i386.exe
BOCHS_DEBUG=E:/software_file/Bochs/Bochs-2.7/bochsdbg.exe


# 伪目标
.PHONY: all image debug run clean realclean m qdebug


nop:
	@echo  "all              编译所有文件，生成目标文件(二进制文件，boot.bin)"
	@echo "image            生成系统镜像文件"
	@echo "debug            打开bochs进行系统的运行和调试"
	@echo "run              提示用于如何将系统安装到虚拟机上运行"
	@echo "clean            清理所有的中间编译文件"
	@echo "realclean        完全清理：清理所有的中间编译文件以及生成的目标文件(二进制文件)"

m:
	make clean
	make image

all: $(MYSTICAL_BOOT) $(MYSTICAL_KERNEL)
	@echo "已经生成内核!"

image: $(FD) $(MYSTICAL_BOOT) $(MYSTICAL_KERNEL)
	dd if=$(TARGET_BOOT)/boot.bin of=$(FD) bs=512 count=1  conv=notrunc
	mountpoint -q $(MOUNTPOINT); \
	if [ $$? -eq 0 ]; then \
		echo "Already mounted at $(MOUNTPOINT)"; \
	else \
		sudo  mount -o loop $(FD) $(MOUNTPOINT);\
		sleep 1; \
		echo "Mounted at $(MOUNTPOINT)"; \
	fi
	sudo cp -fv $(TARGET_BOOT)/loader.bin $(MOUNTPOINT)
	sudo cp -fv $(MYSTICAL_KERNEL) $(MOUNTPOINT)
	sudo umount  $(MOUNTPOINT)

debug:$(FD)
	$(BOCHS_DEBUG) -q

run:$(FD)
	$(QEMU) -rtc base=localtime -drive file=$(FD),index=0,if=floppy,format=raw

qdebug:$(FD)
	$(QEMU) -s -S  -drive file=$(FD),index=0,if=floppy,format=raw

runb:$(FD)
	$(BOCHS) -q

clean:
	-rm -f $(Objs)

realclean:clean
	rm -f  $(MYSTICAL_BOOT) $(MYSTICAL_KERNEL)


$(FD):
	dd if=/dev/zero of=$(FD) bs=512 count=2880

#$@:规则中的目标
#$<:规则中的第一个依赖条件
#$^:规则中的所有依赖条件
$(TARGET_BOOT)/boot.bin:$(BOOT_DIR)/myboot.asm src/boot/include/fat12hdr.inc
	$(ASM) $(ASM_BIN_TYPE) $(ASM_INCLUDE_ARG) -o $@ $<

$(TARGET_BOOT)/loader.bin:$(BOOT_DIR)/loader.asm
	$(ASM) $(ASM_BIN_TYPE) $(ASM_INCLUDE_ARG) -o $@ $<

$(MYSTICAL_KERNEL):$(Objs)
	$(LD) $(LDFlags) -o $(MYSTICAL_KERNEL) $^

#中间Obj文件生成规则

#内核
$(TARGET_KERNEL)/kernel.o: $(SRC_KERNEL)/kernel.asm
	$(ASM) $(ASM_ELF_ARG) -o $@ $<

$(TARGET_KERNEL)/kernel_386lib.o: $(SRC_KERNEL)/kernel_386lib.asm
	$(ASM) $(ASM_ELF_ARG) -o $@ $<

$(TARGET_KERNEL)/main.o: $(SRC_KERNEL)/main.c
	$(CC) $(C_ARG) -o $@ $<

$(TARGET_KERNEL)/start.o: $(SRC_KERNEL)/start.c
	$(CC) $(C_ARG) -o $@ $<

$(TARGET_KERNEL)/protect.o: $(SRC_KERNEL)/protect.c
	$(CC) $(C_ARG) -o $@ $<

$(TARGET_KERNEL)/table.o: $(SRC_KERNEL)/table.c
	$(CC) $(C_ARG) -o $@ $<

$(TARGET_KERNEL)/exception.o: $(SRC_KERNEL)/exception.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/misc.o: $(SRC_KERNEL)/misc.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/i8259.o: $(SRC_KERNEL)/i8259.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/clock.o:$(SRC_KERNEL)/clock.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/process.o: $(SRC_KERNEL)/process.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/message.o: $(SRC_KERNEL)/message.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/dump.o: $(SRC_KERNEL)/dump.c
	$(CC) $(C_ARG) -o $@ $<
$(TARGET_KERNEL)/rtccmos.o: $(SRC_KERNEL)/rtccmos.c
	$(CC) $(C_ARG) -o $@ $<
# ======= 库  =======
$(TARGET_LIB)/ansi/string.o: $(LIB_ANSI)/string.asm
	$(ASM) $(ASM_ELF_ARG) -o $@ $<

$(TARGET_LIB)/ansi/memcmp.o: $(LIB_ANSI)/memcmp.c
	$(CC) $(C_ARG) -o $@ $<

$(TARGET_LIB)/ansi/stringc.o: $(LIB_ANSI)/stringc.c
	$(CC) $(C_ARG) -o $@ $<

$(TARGET_LIB)/stdio/vsprintf.o: $(LIB_STDIO)/vsprintf.c
	$(CC) $(C_ARG) -fno-stack-protector  -o $@ $<

$(TARGET_LIB)/i386/rts/sendrec.o: $(LIB_I386)/rts/sendrec.asm
	$(ASM) $(ASM_ELF_ARG) -o $@ $<


