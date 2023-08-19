
#include "kernel.h"
#include "process.h"

#include <mystical/common.h>





PRIVATE bool_t switching = FALSE;






FORWARD _PROTOTYPE(void pick, (void));

FORWARD _PROTOTYPE(void schedule, (void));




PUBLIC void interrupt(int task) {

    register Process_t *target = proc_addr(task);


    if(kernel_reenter != 0 || switching) {
        interrupt_lock();

        if(!target->int_held) {
            target->int_held = TRUE;
            if(held_head == NIL_PROC)
                held_head = target;
            else
                held_tail->next_held = target;
            held_tail = target;
            target->next_held = NIL_PROC;
        }
        interrupt_unlock();
        return;
    }


    if( (target->flags & (RECEIVING | SENDING)) != RECEIVING ||
        !is_any_hardware(target->get_from)) {
        target->int_blocked = TRUE;
        return;
    }


    target->inbox->source = HARDWARE;
    target->inbox->type = HARD_INT;
    target->flags &= ~RECEIVING;
    target->int_blocked = FALSE;


    if(ready_head[TASK_QUEUE] != NIL_PROC)
        ready_tail[TASK_QUEUE]->next_ready = target;
    else
        curr_proc = ready_head[TASK_QUEUE] = target;
    ready_tail[TASK_QUEUE] = target;
    target->next_ready = NIL_PROC;
}





PUBLIC void unhold(void) {

    register Process_t *target;


    if (switching || held_head == NIL_PROC) return;

    target = held_head;
    do {
        held_head = held_head->next_held;
        interrupt_lock();
        interrupt(target->logic_nr);
        interrupt_unlock();
    } while ((target = held_head) != NIL_PROC);
    held_tail = NIL_PROC;
}


PRIVATE void pick(void) {


    register Process_t *p;

    if ((p = ready_head[TASK_QUEUE]) != NIL_PROC) {
        curr_proc = p;
        return;
    }

    if ((p = ready_head[SERVER_QUEUE]) != NIL_PROC) {
        curr_proc = p;
        return;
    }

    if ((p = ready_head[USER_QUEUE]) != NIL_PROC) {
        curr_proc = bill_proc = p;
        return;
    }
    p = proc_addr(IDLE_TASK);
    curr_proc = bill_proc = p;
}


PUBLIC void ready(
        register Process_t *proc
) {

    if (is_task_proc(proc)) {
        if (ready_head[TASK_QUEUE] == NIL_PROC) {
            curr_proc = ready_head[TASK_QUEUE] = proc;
        } else {
            ready_tail[TASK_QUEUE]->next_ready = proc;
        }

        ready_tail[TASK_QUEUE] = proc;

        proc->next_ready = NIL_PROC;
        return;
    }

    if (is_serv_proc(proc)) {
        if (ready_head[SERVER_QUEUE] == NIL_PROC) {
            ready_head[SERVER_QUEUE] = proc;
        } else {
            ready_tail[SERVER_QUEUE]->next_ready = proc;
        }

        ready_tail[SERVER_QUEUE] = proc;

        proc->next_ready = NIL_PROC;
        return;
    }


    if (ready_head[USER_QUEUE] == NIL_PROC) {
        ready_tail[USER_QUEUE] = proc;
    }

    proc->next_ready = ready_head[USER_QUEUE];

    ready_head[USER_QUEUE] = proc;

}


PUBLIC void unready(
        register Process_t *proc
) {


    register Process_t *xp;
    register Process_t **qtail;

    if (is_task_proc(proc)) {

        if (*proc->stack_guard_word != SYS_TASK_STACK_GUARD)
            panic("stack overrun by task", proc->logic_nr);

        if ((xp = ready_head[TASK_QUEUE]) == NIL_PROC) return;
        if (xp == proc) {

            ready_head[TASK_QUEUE] = xp->next_ready;
            if (proc == curr_proc) pick();
            return;
        }
        qtail = &ready_tail[TASK_QUEUE];
    } else if (!is_user_proc(proc)) {
        if ((xp = ready_head[SERVER_QUEUE]) == NIL_PROC) return;
        if (xp == proc) {
            ready_head[SERVER_QUEUE] = xp->next_ready;
#if (CHIP == M68000)
            if (proc == curr_proc)
#endif
            pick();
            return;
        }
        qtail = &ready_tail[SERVER_QUEUE];
    } else {
        if ((xp = ready_head[USER_QUEUE]) == NIL_PROC) return;
        if (xp == proc) {
            ready_head[USER_QUEUE] = xp->next_ready;
#if (CHIP == M68000)
            if (proc == curr_proc)
#endif
            pick();
            return;
        }
        qtail = &ready_tail[USER_QUEUE];
    }


    while (xp->next_ready != proc)
        if ((xp = xp->next_ready) == NIL_PROC) return;
    xp->next_ready = xp->next_ready->next_ready;
    if (*qtail == proc) *qtail = xp;
}


PRIVATE void schedule(void) {




    if (ready_head[USER_QUEUE] == NIL_PROC) return;


    ready_tail[USER_QUEUE]->next_ready = ready_head[USER_QUEUE];
    ready_tail[USER_QUEUE] = ready_head[USER_QUEUE];
    ready_head[USER_QUEUE] = ready_head[USER_QUEUE]->next_ready;
    ready_tail[USER_QUEUE]->next_ready = NIL_PROC;
    pick();

}


PUBLIC void schedule_stop(void) {


    ready_head[USER_QUEUE] = NIL_PROC;
}


PUBLIC void lock_pick(void) {
    switching = TRUE;
    pick();
    switching = FALSE;
}


PUBLIC void lock_ready(Process_t *proc) {
    switching = TRUE;
    ready(proc);
    switching = FALSE;
}


PUBLIC void lock_unready(Process_t *proc) {
    switching = TRUE;
    unready(proc);
    switching = FALSE;
}


PUBLIC void lock_schedule(void) {
    switching = TRUE;
    schedule();
    switching = FALSE;
}

