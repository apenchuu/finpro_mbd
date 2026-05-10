#define __SFR_OFFSET 0x00
#include "avr/io.h"

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

; inisialisasi usart (baud rate 9600)
init_usart:
    ; set baud rate 9600 untuk f_cpu 16mhz (ubrr = 103 / 0x67)
    LDI R16, 0x00
    STS UBRR0H, R16
    LDI R16, 0x67
    STS UBRR0L, R16

    ; aktifkan transmitter (TXEN0 = 1)
    LDI R16, (1<<TXEN0)
    STS UCSR0B, R16

    ; set format frame: 8 data bit, 1 stop bit
    LDI R16, (1<<UCSZ01) | (1<<UCSZ00)
    STS UCSR0C, R16
    RET

; fungsi utama pengiriman log
log_score:
    LDI ZL, lo8(msg_score)
    LDI ZH, hi8(msg_score)
    RCALL usart_send_string
    MOV R16, R21                ; Kirim Skor A
    RCALL usart_print_num
    LDI ZL, lo8(msg_vs)
    LDI ZH, hi8(msg_vs)
    RCALL usart_send_string
    MOV R16, R22                ; Kirim Skor B
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

; subrutine pendukung usart
usart_send_char:
    ; tunggu sampai buffer transmit kosong
    LDS R17, UCSR0A
    SBRS R17, UDRE0
    RJMP usart_send_char
    STS UDR0, R16               ; kirim karakter
    RET

usart_send_string:
uss_loop:
    LPM R16, Z+                 ; ambil karakter dari flash
    CPI R16, 0                  ; cek null terminator
    BREQ uss_done
    RCALL usart_send_char
    RJMP uss_loop
uss_done:
    RET

usart_print_num:
    ; konversi nilai hex R16 ke 2 digit ASCII, kirim via TX
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
    RCALL usart_send_char       ; send puluhan
    POP R16
    SUBI R16, -'0'
    RCALL usart_send_char       ; send satuan
    RET