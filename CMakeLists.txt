# 设置CMake的最小版本需求
cmake_minimum_required(VERSION 3.9)
# 设置工程名称
project(Mystical)
# 设置C语言所使用的标准
set(CMAKE_C_STANDARD 90)
# 导入头文件目录，特别是针对于操作系统工程
include_directories(HEAD "include")

# 将所有的可执行文件添加进跟踪列表
add_executable(
        Mystical src/kernel/main.c
        src/kernel/protect.c
        src/kernel/table.c
        include/mystical/keymap.h
        src/kernel/start.c
        src/kernel/exception.c
        src/lib/stdio/vsprintf.c
        src/kernel/misc.c
        src/lib/stdio/sprintf.c
        src/kernel/i8259.c
        src/kernel/clock.c
        src/kernel/process.c
        src/kernel/message.c
        src/kernel/dump.c
        src/kernel/rtccmos.c
        src/kernel/keymaps/us-std.h
)
