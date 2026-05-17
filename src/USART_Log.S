#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global init_usart
.global log_score
.global log_winner_A
.global log_winner_B

.section .progmem
msg_score:  .asciz "\r\n[LOG] Skor -> A: "
msg_vs:     .asciz " | B: "
msg_win_A:  .asciz "\r\n>>> MATCH OVER! TIM A MENANG! <<<\r\n"
msg_win_B:  .asciz "\r\n>>> MATCH OVER! TIM B MENANG! <<<\r\n"

.section .text

init_usart:
    LDI R16, 0x00
    STS UBRR0H, R16
    LDI R16, 0x67
    STS UBRR0L, R16
    LDI R16, (1<<TXEN0)
    STS UCSR0B, R16
    LDI R16, (1<<UCSZ01) | (1<<UCSZ00)
    STS UCSR0C, R16
    RET

log_score:
    LDI ZL, lo8(msg_score)
    LDI ZH, hi8(msg_score)
    RCALL usart_send_string
    MOV R16, R21                
    RCALL usart_print_num
    LDI ZL, lo8(msg_vs)
    LDI ZH, hi8(msg_vs)
    RCALL usart_send_string
    MOV R16, R22                
    RCALL usart_print_num
    RET

log_winner_A:
    LDI ZL, lo8(msg_win_A)
    LDI ZH, hi8(msg_win_A)
    RCALL usart_send_string
    RET

log_winner_B:
    LDI ZL, lo8(msg_win_B)
    LDI ZH, hi8(msg_win_B)
    RCALL usart_send_string
    RET

usart_send_char:
    LDS R17, UCSR0A
    SBRS R17, UDRE0
    RJMP usart_send_char
    STS UDR0, R16               
    RET

usart_send_string:
uss_loop:
    LPM R16, Z+        
    CPI R16, 0                  
    BREQ uss_done
    RCALL usart_send_char
    RJMP uss_loop
uss_done:
    RET

usart_print_num:
    LDI R18, '0'
upn_div:
    CPI R16, 10
    BRLO upn_print
    SUBI R16, 10
    INC R18
    RJMP upn_div
upn_print:
    PUSH R16
    MOV R16, R18
    RCALL usart_send_char       
    POP R16
    SUBI R16, -'0'
    RCALL usart_send_char       
    RET