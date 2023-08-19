
#include "kernel.h"
#include <mystical//keymap.h>
#include "keymaps/us-std.h"


#define KEYBOARD_DATA       0x60


#define KEYBOARD_COMMAND    0x64
#define KEYBOARD_STATUS     0x64
#define KEYBOARD_ACK        0xFA

#define KEYBOARD_OUT_FULL   0x01
#define KEYBOARD_IN_FULL    0x02
#define LED_CODE            0xED
#define MAX_KEYBOARD_ACK_RETRIES    0x1000
#define MAX_KEYBOARD_BUSY_RETRIES   0x1000
#define KEY_BIT             0x80


#define SCROLL_UP       0
#define SCROLL_DOWN     1


#define SCROLL_LOCK	    0x01
#define NUM_LOCK	    0x02
#define CAPS_LOCK	    0x04
#define DEFAULT_LOCK    0x02


#define KEYBOARD_IN_BYTES	  32


#define ESC_SCAN	        0x01
#define SLASH_SCAN	        0x35
#define RSHIFT_SCAN	        0x36
#define HOME_SCAN	        0x47
#define INS_SCAN	        0x52
#define DEL_SCAN	        0x53


PRIVATE bool_t esc = FALSE;
PRIVATE bool_t alt_left = FALSE;
PRIVATE bool_t alt_right = FALSE;
PRIVATE bool_t alt = FALSE;
PRIVATE bool_t ctrl_left = FALSE;
PRIVATE bool_t ctrl_right = FALSE;
PRIVATE bool_t ctrl = FALSE;
PRIVATE bool_t shift_left = FALSE;
PRIVATE bool_t shift_right = FALSE;
PRIVATE bool_t shift = FALSE;
PRIVATE bool_t num_down = FALSE;
PRIVATE bool_t caps_down = FALSE;
PRIVATE bool_t scroll_down = FALSE;
PRIVATE u8_t locks[NR_CONSOLES];



PRIVATE char numpad_map[] =
        {'H', 'Y', 'A', 'B', 'D', 'C', 'V', 'U', 'G', 'S', 'T', '@'};


PRIVATE u8_t input_buff[KEYBOARD_IN_BYTES];
PRIVATE int input_count;
PRIVATE u8_t *input_free = input_buff;
PRIVATE u8_t *input_todo = input_buff;


#define map_key0(scan_code) \
    ((u16_t)keymap[scan_code * MAP_COLS])


PRIVATE u8_t scan_key(void) {

    u8_t scan_code = in_byte(KEYBOARD_DATA);


    int val = in_byte(PORT_B);
    out_byte(PORT_B, val | KEY_BIT);
    out_byte(PORT_B, val);

    return scan_code;
}


PRIVATE int keyboard_handler(int irq) {


    if(input_count < KEYBOARD_IN_BYTES) {
        *input_free++ = scan_key();
        ++input_count;


        if(input_count == KEYBOARD_IN_BYTES) {

            int i;
            u8_t prb[KEYBOARD_IN_BYTES + 1];
            for(i = 0; i < KEYBOARD_IN_BYTES; ++i) {
                prb[i] = map_key0(input_buff[i]);
                if(prb[i] == 0) {
                    prb[i] = ' ';
                }
            }
            prb[KEYBOARD_IN_BYTES] = '\0';
            printf("input buffer full. string is '%s'\n", prb);

            input_free = input_buff;
        }
    }

    return ENABLE;
}



PRIVATE int keyboard_wait(void) {


    int retries = MAX_KEYBOARD_BUSY_RETRIES;
    u8_t status;
    while (retries-- > 0 && ((status = in_byte(KEYBOARD_STATUS)) & (KEYBOARD_IN_FULL | KEYBOARD_OUT_FULL)) != 0) {
        if((status & KEYBOARD_OUT_FULL) != 0) {
            (void) in_byte(KEYBOARD_DATA);
        }
    }
    return retries;
}


PRIVATE int keyboard_ack(void) {


    int retries = MAX_KEYBOARD_ACK_RETRIES;
    for (; retries-- > 0 && in_byte(KEYBOARD_DATA) != KEYBOARD_ACK; );
    return retries;
}


PRIVATE void setting_led(void) {
    keyboard_wait();
    out_byte(KEYBOARD_DATA, LED_CODE);
    keyboard_ack();

    keyboard_wait();
    out_byte(KEYBOARD_DATA, locks[0]);
    keyboard_ack();
}


PUBLIC void keyboard_init(void) {
    printf("#{KEY_BD}-> init...\n");


    int i = 0;
    for(; i < NR_CONSOLES; ++i) {
        locks[i] = DEFAULT_LOCK;
    }
    setting_led();


    (void) scan_key();


    put_irq_handler(KEYBOARD_IRQ, keyboard_handler);
    enable_irq(KEYBOARD_IRQ);
}


