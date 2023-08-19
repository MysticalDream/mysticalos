#include "kernel.h"
#include <mystical/common.h>
#include "process.h"
#include "assert.h"
#include <errno.h>
#include "logger.h"

INIT_ASSERT

// bss没有初始化
//FIXED:已在加载内核初始化
PRIVATE Process_t *waiters[NR_TASKS + NR_SERVERS + NR_PROCS];


PUBLIC int sys_call(int function,
                    int src_dest,
                    Message_t *m_ptr) {



    register struct process_s *rp;
    int n;
    Message_t *msg_vir;
    Message_t *msg_phys;


    rp = curr_proc;

    if (function == IN_OUTBOX) {
        msg_vir = (Message_t *) src_dest;
        if (msg_vir != NIL_MESSAGE) {
            rp->inbox = (Message_t *) proc_vir2phys(rp, msg_vir);
        }
        if (m_ptr != NIL_MESSAGE) {
            rp->outbox = (Message_t *) proc_vir2phys(rp, m_ptr);
        }
        return OK;
    }

    if (!is_ok_src_dest(src_dest)) {
        return (ERROR_BAD_SRC);
    }

    if (is_user_proc(rp) && function != SEND_REC) {
        return (ERROR_NO_PERM);
    }


    if (function & SEND) {

        assert(rp->logic_nr != src_dest);

        if (m_ptr == NIL_MESSAGE) {
            msg_phys = rp->outbox;
        } else {
            msg_phys = (Message_t *) proc_vir2phys(rp, m_ptr);
        }

        msg_phys->source = rp->logic_nr;

        n = mystical_send(rp, src_dest, msg_phys);

        if (function == SEND || n != OK)
            return (n);
    }

    if (m_ptr == NIL_MESSAGE) {
        msg_phys = rp->inbox;
    } else {
        msg_phys = (Message_t *) proc_vir2phys(rp, m_ptr);
    }

    return (mystical_receive(rp, src_dest, msg_phys));
}


PUBLIC int mystical_send(
        register struct process_s *caller_ptr,
        int dest,
        Message_t *m_ptr) {


    register struct process_s *dest_ptr, *next_ptr;
    vir_bytes vb;
    vir_clicks vlo, vhi;


    if (is_user_proc(caller_ptr) && !is_sys_server(dest)) {
        return (ERROR_BAD_DEST);
    }
    dest_ptr = proc_addr(dest);

    //死进程
    if (is_empty_proc(dest_ptr)) {
        return (ERROR_BAD_DEST);
    }

//#if ALLOW_GAP_MESSAGES
//
//  vb = (vir_bytes) m_ptr;
//  vlo = vb >> CLICK_SHIFT;
//  vhi = (vb + MESS_SIZE - 1) >> CLICK_SHIFT;
//  if (vlo < caller_ptr->p_map[D].mem_vir || vlo > vhi ||
//      vhi >= caller_ptr->p_map[S].mem_vir + caller_ptr->p_map[S].mem_len)
//        return(EFAULT);
//#else
//
//    vb = (vir_bytes) m_ptr;
//    vlo = vb >> CLICK_SHIFT;
//    vhi = (vb + MESSAGE_SIZE - 1) >> CLICK_SHIFT;
//    if (vhi < vlo ||
//        vhi - caller_ptr->map.base >= caller_ptr->map.size)
//        return (EFAULT);
//#endif


    if (dest_ptr->flags & SENDING) {
        next_ptr = proc_addr(dest_ptr->send_to);
        while (TRUE) {
            if (next_ptr == caller_ptr) return (ERROR_LOCKED);
            if (next_ptr->flags & SENDING)
                next_ptr = proc_addr(next_ptr->send_to);
            else
                break;
        }
    }


    if ((dest_ptr->flags & (RECEIVING | SENDING)) == RECEIVING &&
        (dest_ptr->get_from == ANY ||
         dest_ptr->get_from == (caller_ptr->logic_nr))) {

        msg_copy((phys_bytes) m_ptr, (phys_bytes) dest_ptr->transfer);
        dest_ptr->flags &= ~RECEIVING;
        if (dest_ptr->flags == CLEAN_MAP) ready(dest_ptr);
    } else {

        caller_ptr->transfer = m_ptr;
        if (caller_ptr->flags == CLEAN_MAP) unready(caller_ptr);
        caller_ptr->flags |= SENDING;
        caller_ptr->send_to = dest;


        if ((next_ptr = dest_ptr->waiter_head) == NIL_PROC) {
            dest_ptr->waiter_head = caller_ptr;
        } else {
            while (next_ptr->next_waiter != NIL_PROC) {
                next_ptr = next_ptr->next_waiter;
            }
            next_ptr->next_waiter = caller_ptr;
        }
        caller_ptr->next_waiter = NIL_PROC;
    }
    return (OK);
}


PUBLIC int mystical_receive(
        register struct process_s *caller_ptr,
        int src,
        Message_t *m_ptr) {



    register struct process_s *sender_ptr;
    register struct process_s *previous_ptr;


    if (!(caller_ptr->flags & SENDING)) {

        for (sender_ptr = caller_ptr->waiter_head; sender_ptr != NIL_PROC;
             previous_ptr = sender_ptr, sender_ptr = sender_ptr->next_waiter) {
            if (src == ANY || src == (sender_ptr->logic_nr)) {
                msg_copy((phys_bytes) sender_ptr->transfer, (phys_bytes) m_ptr);
                if (sender_ptr == caller_ptr->waiter_head) {
                    caller_ptr->waiter_head = sender_ptr->next_waiter;
                } else {
                    previous_ptr->next_waiter = sender_ptr->next_waiter;
                }

                if ((sender_ptr->flags &= ~SENDING) == 0)
                    ready(sender_ptr);
                return (OK);
            }
        }


//        if (caller_ptr->int_blocked && is_any_hardware(src)) {
//            m_ptr->source = HARDWARE;
//            m_ptr->type = HARD_INT;
//            caller_ptr->int_blocked = FALSE;
//            return (OK);
//        }
    }




    caller_ptr->get_from = src;
    caller_ptr->transfer = m_ptr;
    if (caller_ptr->flags == CLEAN_MAP) {
        unready(caller_ptr);
    }
    caller_ptr->transfer = m_ptr;
    caller_ptr->flags |= RECEIVING;

//
//    if (sig_procs > 0 && (caller_ptr->logic_nr) == MM_PROC_NR && src == ANY)
//        inform();
    return (OK);
}