
#include "kernel.h"
#include <mystical//common.h>
#include "process.h"
#include <sys/times.h>


#define SCHEDULE_MILLISECOND    130
#define SCHEDULE_TICKS          (SCHEDULE_MILLISECOND / ONE_TICK_MILLISECOND)


#define TIMER0          0x40
#define TIMER1          0x41
#define TIMER2          0x42
#define TIMER_MODE      0x43
#define RATE_GENERATOR  0x34
#define SQUARE_WAVE     0x36
//外接的晶振频率是 1.193182 MHz = 1193182 HZ
#define TIMER_FREQ            1193182L
//#define TIMER_COUNT  (TIMER_FREQ / HZ)

#define TIMER_COUNT      ((TIMER_FREQ + HZ/2) / HZ)

#define CLOCK_ACK_BIT        0x80

#define MINUTES 60
#define HOURS   (60 * MINUTES)
#define DAYS    (24 * HOURS)
#define YEARS   (365 * DAYS)


PRIVATE Message_t msg;
PRIVATE clock_t ticks;
PRIVATE time_t realtime;
PRIVATE time_t boot_time;
PRIVATE clock_t next_alarm = ULONG_MAX;
PRIVATE clock_t delay_alarm = ULONG_MAX;


PRIVATE clock_t schedule_ticks = SCHEDULE_TICKS;
PRIVATE Process_t *last_proc;


PRIVATE int month_map[12] = {
        0,
        DAYS * (31),
        DAYS * (31 + 29),
        DAYS * (31 + 29 + 31),
        DAYS * (31 + 29 + 31 + 30),
        DAYS * (31 + 29 + 31 + 30 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31 + 30),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31),
        DAYS * (31 + 29 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30)
};


FORWARD _PROTOTYPE(int clock_handler, (int irq));

FORWARD _PROTOTYPE(void clock_init, (void));

FORWARD _PROTOTYPE(time_t mktime, (RTCTime_t * p_time));

FORWARD _PROTOTYPE(inline void do_get_uptime, (void));

FORWARD _PROTOTYPE(inline void do_get_time, (void));

FORWARD _PROTOTYPE(inline void do_set_time, (void));

FORWARD _PROTOTYPE(void do_clock_int, (void));


PUBLIC void clock_task(void) {


    clock_init();

//    interrupt_unlock();


    INIT_SAME_BOX(&msg);


//    printf("delay begin!\n");
//    milli_delay(sec2ms(5));
//    printf("delay end!\n");

    while (TRUE) {

        RECEIVE_DEFAULT(ANY);


        interrupt_lock();
        realtime = ticks / HZ;
        interrupt_unlock();



        switch (msg.type) {
            case HARD_INT:
                do_clock_int();
                break;
            case GET_UPTIME:
                do_get_uptime();
                break;
            case GET_TIME:
                do_get_time();
                break;
            case SET_TIME:
                do_set_time();
                break;
            default:
                panic("Clock task got bad message request.\n", msg.type);
        }


        msg.type = OK;
        SEND_DEFAULT(msg.source);
    }
}

PUBLIC void milli_delay(time_t delay_ms) {



    delay_alarm = ticks + delay_ms / ONE_TICK_MILLISECOND;

    while (delay_alarm != ULONG_MAX) {}
}


PRIVATE void do_clock_int(void) {


    printf("i am clock int, hi brother!\n");
    next_alarm = ULONG_MAX;
}


PRIVATE inline void do_get_uptime(void) {
    msg.CLOCK_TIME = ticks;
}


PRIVATE inline void do_get_time(void) {
    msg.CLOCK_TIME = (long) (boot_time + realtime);
}


PRIVATE inline void do_set_time(void) {
    boot_time = msg.CLOCK_TIME - realtime;
}


PRIVATE int clock_handler(int irq) {

    register Process_t *target;


    if (kernel_reenter)
        target = proc_addr(HARDWARE);
    else
        target = curr_proc;
    ticks++;


    target->user_time++;
    if (target != bill_proc && target != proc_addr(HARDWARE))
        bill_proc->sys_time++;


    if (next_alarm <= ticks) {
        interrupt(CLOCK_TASK);
        //硬件中断及时return
        return ENABLE;
    }


    if (delay_alarm <= ticks) {
        delay_alarm = ULONG_MAX;
    }


    if (--schedule_ticks == 0) {
        schedule_ticks = SCHEDULE_TICKS;
        last_proc = bill_proc;
    }

    return ENABLE;
}

PRIVATE int clock_handler2(int irq) {
    register struct process_s *rp;
    register unsigned u_ticks;
    clock_t now;



    if (kernel_reenter != 0)
        rp = proc_addr(HARDWARE);
    else
        rp = curr_proc;
    u_ticks = lost_ticks + 1;
    lost_ticks = 0;
    rp->user_time += u_ticks;
    if (rp != bill_proc && rp != proc_addr(IDLE_TASK)) bill_proc->sys_time += u_ticks;

    ticks += u_ticks;
    now = realtime + ticks;
//    if (tty_timeout <= now) tty_wakeup(now);


    if (next_alarm <= now ||
        schedule_ticks == 1 &&
        bill_proc == last_proc &&
        ready_head[USER_QUEUE] != NIL_PROC) {
        interrupt(CLOCK_TASK);
        return ENABLE;
    }

    if (--schedule_ticks == 0) {

        schedule_ticks = SCHEDULE_TICKS;
        last_proc = bill_proc;
    }
    return ENABLE;
}




PUBLIC void get_rtc_time(RTCTime_t *p_time) {

    u8_t status;

    p_time->year = cmos_read(YEAR);
    p_time->month = cmos_read(MONTH);
    p_time->day = cmos_read(DAY);
    p_time->hour = cmos_read(HOUR);
    p_time->minute = cmos_read(MINUTE);
    p_time->second = cmos_read(SECOND);


    status = cmos_read(CLK_STATUS);
    if ((status & 0x4) == 0) {
        p_time->year = bcd2dec(p_time->year);
        p_time->month = bcd2dec(p_time->month);
        p_time->day = bcd2dec(p_time->day);
        p_time->hour = bcd2dec(p_time->hour);
        p_time->minute = bcd2dec(p_time->minute);
        p_time->second = bcd2dec(p_time->second);
    }
    p_time->year += 2000;
}


PRIVATE time_t mktime(RTCTime_t *p_time) {


    time_t now;
    u16_t year = p_time->year;
    u8_t mouth = p_time->month;
    u16_t day = p_time->day;
    u8_t hour = p_time->hour, minute = p_time->minute, second = p_time->second;

    year -= 1970;

//    now = YEARS * year + DAYS * ((year + 1) / 4);
    now = YEARS * year + DAYS * ((year + 1) >> 2);
    now += month_map[mouth - 1];

//    if (mouth - 1 > 0 && ((year + 2) % 4))
    if (mouth - 1 > 0 && ((year + 2) & 3)) {
        now -= DAYS;
    }
    now += DAYS * (day - 1);
    now += HOURS * hour;
    now += MINUTES * minute;
    now += second;

    return (now - (8 * HOURS));
}



PRIVATE void clock_init(void) {



    out_byte(TIMER_MODE, RATE_GENERATOR);

    out_byte(TIMER0, (u8_t) TIMER_COUNT);
    out_byte(TIMER0, (u8_t) (TIMER_COUNT >> 8));

//    out_byte(TIMER0, (u8_t) 0x2e);
//    out_byte(TIMER0, (u8_t) (00));




    put_irq_handler(CLOCK_IRQ, clock_handler);
    enable_irq(CLOCK_IRQ);


    RTCTime_t now;

    read_rtc(&now);

    boot_time = mktime(&now);
    printf("#{CLOCK}-> now is %d-%d-%d %d:%d:%d\n",
           now.year, now.month, now.day, now.hour, now.minute, now.second);
    printf("#{CLOCK}-> boot startup time is %ld\n", boot_time);
}


