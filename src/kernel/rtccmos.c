
#include <sys/times.h>

#define CURRENT_YEAR        2023                            // 每年都需要更改

int century_register = 0x00;                                // 如有可能，根据ACPI表解析代码进行设置。


void out_byte(int port, int value);

int in_byte(int port);

enum {
    cmos_address = 0x70,
    cmos_data = 0x71
};

int get_update_in_progress_flag() {
    out_byte(cmos_address, 0x0A);
    return (in_byte(cmos_data) & 0x80);
}

unsigned char get_RTC_register(int reg) {
    out_byte(cmos_address, reg);
    return in_byte(cmos_data);
}

void read_rtc(struct rtc_time *p_time) {

    unsigned char second;
    unsigned char minute;
    unsigned char hour;
    unsigned char day;
    unsigned char month;
    unsigned int year;

    unsigned char century;
    unsigned char last_second;
    unsigned char last_minute;
    unsigned char last_hour;
    unsigned char last_day;
    unsigned char last_month;
    unsigned char last_year;
    unsigned char last_century;
    unsigned char registerB;

    // 注意：这里使用了“连续读取寄存器直到两次获得相同值”的技术，以避免由于RTC更新导致的不稳定/不一致值的问题。
    while (get_update_in_progress_flag());                // 确保更新不在进行中
    second = get_RTC_register(0x00);
    minute = get_RTC_register(0x02);
    hour = get_RTC_register(0x04);
    day = get_RTC_register(0x07);
    month = get_RTC_register(0x08);
    year = get_RTC_register(0x09);
    if (century_register != 0) {
        century = get_RTC_register(century_register);
    }

    do {
        last_second = second;
        last_minute = minute;
        last_hour = hour;
        last_day = day;
        last_month = month;
        last_year = year;
        last_century = century;

        while (get_update_in_progress_flag());           // 确保更新不在进行中
        second = get_RTC_register(0x00);
        minute = get_RTC_register(0x02);
        hour = get_RTC_register(0x04);
        day = get_RTC_register(0x07);
        month = get_RTC_register(0x08);
        year = get_RTC_register(0x09);
        if (century_register != 0) {
            century = get_RTC_register(century_register);
        }
    } while ((last_second != second) || (last_minute != minute) || (last_hour != hour) ||
             (last_day != day) || (last_month != month) || (last_year != year) ||
             (last_century != century));

    registerB = get_RTC_register(0x0B);

    // 如有必要，将BCD码转换为二进制值

    if (!(registerB & 0x04)) {
        second = (second & 0x0F) + ((second / 16) * 10);
        minute = (minute & 0x0F) + ((minute / 16) * 10);
        hour = ((hour & 0x0F) + (((hour & 0x70) / 16) * 10)) | (hour & 0x80);
        day = (day & 0x0F) + ((day / 16) * 10);
        month = (month & 0x0F) + ((month / 16) * 10);
        year = (year & 0x0F) + ((year / 16) * 10);
        if (century_register != 0) {
            century = (century & 0x0F) + ((century / 16) * 10);
        }
    }

    // 如有必要，将12小时制时钟转换为24小时制

    if (!(registerB & 0x02) && (hour & 0x80)) {
        hour = ((hour & 0x7F) + 12) % 24;
    }

    // 计算完整的（4位数）年份

    if (century_register != 0) {
        year += century * 100;
    } else {
        year += (CURRENT_YEAR / 100) * 100;
        if (year < CURRENT_YEAR) year += 100;
    }

    p_time->year = year;
    p_time->month = month;
    p_time->day = day;
    p_time->hour = hour;
    p_time->minute = minute;
    p_time->second = second;

}
