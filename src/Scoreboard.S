#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global main

.section .text
main:
    ; Inisialisasi stack pointer AVR 
    LDI R16, hi8(RAMEND)
    OUT SPH, R16
    LDI R16, lo8(RAMEND)
    OUT SPL, R16

    ; Konfigurasi pin D2 sampai D5 sebagai input.
    IN R16, DDRD
    ANDI R16, ~((1<<2) | (1<<3) | (1<<4) | (1<<5))
    OUT DDRD, R16

    ; Aktifkan pull-up internal untuk semua button sebagai input
    IN R16, PORTD
    ORI R16, (1<<2) | (1<<3) | (1<<4) | (1<<5)
    OUT PORTD, R16

    IN R16, DDRB
    ORI R16, (1<<4) | (1<<5)
    OUT DDRB, R16

    IN R16, PORTB
    ANDI R16, ~((1<<4) | (1<<5))
    OUT PORTB, R16

    CLR R24
    CLR R25

    RCALL init_interrupt
    RCALL init_lcd
    RCALL init_usart
    RCALL load_scores
    RCALL update_lcd_mode
    RCALL update_lcd_score
    RCALL check_match_point

main_loop:
    CPI R23, 1
    BRNE skip_update
    
    ; Jika ada perubahan skor, perbarui LCD, LED match point, log USART, EEPROM, dan cek pemenang.
    RCALL update_lcd_mode
    RCALL update_lcd_score
    RCALL check_match_point
    RCALL log_score
    RCALL save_score_A
    RCALL save_score_B
    RCALL check_win
    CLR R23

skip_update:
    SBIS PIND, 4
    RCALL undo_logic
    
    SBIS PIND, 5
    RCALL mode_logic

    RJMP main_loop

; Logika button timeout/undo: tekan singkat untuk membatalkan poin terakhir, tekan lama untuk mode timeout.
undo_logic:
    LDI R18, 0

cek_tahan:
    RCALL delay_short_ms
    SBIC PIND, 4
    RJMP short_press
    
    INC R18
    CPI R18, 50
    BREQ long_press
    RJMP cek_tahan

; Kalau button ditekan cepat, maka akan mengurangi skor tim yang terakhir mendapat poin.
short_press:
    CPI R25, 1
    BREQ undo_tim_a
    CPI R25, 2
    BREQ undo_tim_b
    RET

undo_tim_a:
    ; Jika yang terakhir mencetak poin adalah Tim A, kurangi skor A bila masih ada.
    TST R21
    BREQ selesai_undo
    DEC R21
    RJMP selesai_undo

undo_tim_b:
    ; Jika yang terakhir mencetak poin adalah Tim B, kurangi skor B bila masih ada.
    TST R22
    BREQ selesai_undo
    DEC R22

selesai_undo:
    CLR R25
    LDI R23, 1
    RET

; Jika button ditekan lama, maka masuk ke mode timeout dan menampilkan hitung mundur selama 60 detik.
long_press:
    LDI R19, 60

timeout_loop:
    RCALL update_lcd_timeout

    RCALL delay_1s

    DEC R19
    BRNE timeout_loop

    LDI R23, 1

wait_release_4:
    ; Tunggu tombol D4 dilepas sebelum kembali ke loop utama.
    SBIS PIND, 4
    RJMP wait_release_4
    RET

; Tombol mode digunakan untuk berpindah antara volley dan badminton, lalu mereset skor.
mode_logic:
wait_release_5:
    SBIS PIND, 5
    RJMP wait_release_5
    RCALL delay_short_ms

    LDI R16, 1
    EOR R24, R16

    RCALL reset_eeprom_scores
    CLR R25
    LDI R23, 1
    RET

; Cek pemenang dan aturan selisih 2 poin saat skor sudah melewati target.
check_win:
    CPI R24, 0
    BREQ target_volley
target_badminton:
    LDI R17, 21
    RJMP cek_batas
target_volley:
    LDI R17, 25

cek_batas:
    CP R21, R17
    BRGE hitung_selisih
    CP R22, R17
    BRGE hitung_selisih
    RET

hitung_selisih:
    MOV R18, R21
    MOV R19, R22
    CP R18, R19
    BRGE tim_a_memimpin

tim_b_memimpin:
    SUB R19, R18
    CPI R19, 2
    BRGE tim_b_menang
    RET

tim_a_memimpin:
    SUB R18, R19
    CPI R18, 2
    BRGE tim_a_menang
    RET

tim_a_menang:
    RCALL log_winner_A
    RCALL reset_eeprom_scores
    CLR R25
    LDI R23, 1
    RET

tim_b_menang:
    RCALL log_winner_B
    RCALL reset_eeprom_scores
    CLR R25
    LDI R23, 1
    RET

; Menyalakan LED pada saat tim tertentu memasuki match point.
check_match_point:
    PUSH R16
    PUSH R17

    IN R16, PORTB
    ANDI R16, ~((1<<4) | (1<<5))
    OUT PORTB, R16

    CPI R24, 0
    BREQ mp_volley
mp_badminton:
    LDI R17, 21
    RJMP hitung_mp
mp_volley:
    LDI R17, 25

hitung_mp:
    DEC R17

    ; Tim A mendapat LED match point jika skornya sudah memenuhi
    CP R21, R17
    BRLT cek_mp_b
    CP R21, R22
    BRLO cek_mp_b
    BREQ cek_mp_b
    
    IN R16, PORTB
    ORI R16, (1<<4)
    OUT PORTB, R16

cek_mp_b:
    ; Tim B mendapat LED match point jika skornya sudah memenuhi
    CP R22, R17
    BRLT selesai_mp
    CP R22, R21
    BRLO selesai_mp
    BREQ selesai_mp
    
    IN R16, PORTB
    ORI R16, (1<<5)
    OUT PORTB, R16

selesai_mp:
    POP R17
    POP R16
    RET

; =========================================
; Display.S
; =========================================
.global update_lcd_score
.global update_lcd_mode
.global print_number
.global update_lcd_timeout

; Teks mode dan timeout disimpan di flash memory agar tidak memakai RAM.
.section .progmem
str_volley:    .asciz "  VOLLEYBALL    "
str_badminton: .asciz "   BADMINTON    "
str_timeout:   .asciz "    TIMEOUT     "

.section .text

; Tulis mode sportnya pada baris pertama LCD.
update_lcd_mode:
    LDI R16, 0x80
    RCALL lcd_command

    CPI R24, 0
    BREQ mode_v
mode_b:
    LDI ZL, lo8(str_badminton)
    LDI ZH, hi8(str_badminton)
    RJMP tampilkan_mode
mode_v:
    LDI ZL, lo8(str_volley)
    LDI ZH, hi8(str_volley)

tampilkan_mode:
lpm_loop:
    LPM R16, Z+
    CPI R16, 0      
    BREQ selesai_mode
    RCALL lcd_data  
    RJMP lpm_loop
selesai_mode:
    RET

; Untuk menuliskan skor tim A dan B pada baris kedua LCD.
update_lcd_score:
    LDI R16, 0xC0
    RCALL lcd_command

    LDI R16, 'A'
    RCALL lcd_data
    LDI R16, ':'
    RCALL lcd_data
    MOV R16, R21
    RCALL print_number

    LDI R16, ' '
    RCALL lcd_data
    RCALL lcd_data
    RCALL lcd_data
    RCALL lcd_data

    LDI R16, 'B'
    RCALL lcd_data
    LDI R16, ':'
    RCALL lcd_data
    MOV R16, R22
    RCALL print_number
    RET

; Untuk mengubah angka 0-99 menjadi dua karakter ASCII lalu kirim ke LCD.
print_number:
    LDI R18, '0'
hitung_puluhan:
    CPI R16, 10
    BRLO cetak_digit
    SUBI R16, 10
    INC R18
    RJMP hitung_puluhan
cetak_digit:
    PUSH R16
    MOV R16, R18
    RCALL lcd_data
    POP R16
    SUBI R16, -'0'
    RCALL lcd_data
    RET

; Untuk menampilkan timeout dan hitung mundur pada LCD.
update_lcd_timeout:
    LDI R16, 0x80
    RCALL lcd_command

    LDI ZL, lo8(str_timeout)
    LDI ZH, hi8(str_timeout)
timeout_lpm:
    LPM R16, Z+
    CPI R16, 0
    BREQ timeout_baris2
    RCALL lcd_data
    RJMP timeout_lpm

timeout_baris2:
    LDI R16, 0xC0
    RCALL lcd_command

    LDI R18, 7
timeout_spasi1:
    LDI R16, ' '
    RCALL lcd_data
    DEC R18
    BRNE timeout_spasi1

    MOV R16, R19
    RCALL print_number

    LDI R18, 7
timeout_spasi2:
    LDI R16, ' '
    RCALL lcd_data
    DEC R18
    BRNE timeout_spasi2
    RET

; =========================================
; EEPROM_Data.S
; =========================================
.global save_score_A
.global save_score_B
.global load_scores
.global reset_eeprom_scores

.section .text

save_score_A:
    SBIC EECR, EEPE
    RJMP save_score_A
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x01
    OUT EEARL, R16
    OUT EEDR, R21
    SBI EECR, EEMPE
    SBI EECR, EEPE
    RET

save_score_B:
    SBIC EECR, EEPE
    RJMP save_score_B
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x02
    OUT EEARL, R16
    OUT EEDR, R22
    SBI EECR, EEMPE
    SBI EECR, EEPE
    RET

load_scores:
wait_read_A:
    SBIC EECR, EEPE
    RJMP wait_read_A
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x01
    OUT EEARL, R16
    SBI EECR, EERE    
    IN R21, EEDR      

wait_read_B:
    SBIC EECR, EEPE
    RJMP wait_read_B
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x02
    OUT EEARL, R16
    SBI EECR, EERE    
    IN R22, EEDR      
    RET

reset_eeprom_scores:
    CLR R21
    CLR R22
    RCALL save_score_A
    RCALL save_score_B
    RET

; =========================================
; I2C_LCD.S 
; =========================================
.global init_lcd
.global lcd_command
.global lcd_data
.global lcd_clear

.section .text

i2c_init:
    ; Set bus I2C ke sekitar 100 kHz.
    LDI R16, 72
    STS TWBR, R16
    LDI R16, 0x00
    STS TWSR, R16
    RET

i2c_start:
    LDI R16, (1<<TWINT) | (1<<TWSTA) | (1<<TWEN)
    STS TWCR, R16
wait_start:
    LDS R16, TWCR
    SBRS R16, TWINT
    RJMP wait_start
    RET

i2c_write:
    STS TWDR, R16
    LDI R16, (1<<TWINT) | (1<<TWEN)
    STS TWCR, R16
wait_write:
    LDS R16, TWCR
    SBRS R16, TWINT
    RJMP wait_write
    RET

i2c_stop:
    LDI R16, (1<<TWINT) | (1<<TWSTO) | (1<<TWEN)
    STS TWCR, R16
    RET

pcf8574_write:
    PUSH R16
    RCALL i2c_start
    LDI R16, 0x4E
    RCALL i2c_write
    POP R16
    RCALL i2c_write
    RCALL i2c_stop
    RET

lcd_send_byte_i2c:
    PUSH R18
    PUSH R19
    MOV R19, R16

    MOV R18, R19
    ANDI R18, 0xF0
    OR R18, R17
    ORI R18, 0x08
    MOV R16, R18
    ORI R16, 0x04
    RCALL pcf8574_write
    MOV R16, R18
    RCALL pcf8574_write

    MOV R18, R19
    SWAP R18
    ANDI R18, 0xF0
    OR R18, R17
    ORI R18, 0x08
    MOV R16, R18
    ORI R16, 0x04
    RCALL pcf8574_write
    MOV R16, R18
    RCALL pcf8574_write

    POP R19
    POP R18
    RET

lcd_command:
    PUSH R17
    LDI R17, 0x00
    RCALL lcd_send_byte_i2c
    RCALL delay_ms
    POP R17
    RET

lcd_data:
    PUSH R17
    LDI R17, 0x01
    RCALL lcd_send_byte_i2c
    RCALL delay_ms
    POP R17
    RET

lcd_clear:
    LDI R16, 0x01
    RCALL lcd_command
    RCALL delay_ms
    RCALL delay_ms
    RET

lcd_write_nibble_init:
    ORI R16, 0x08
    PUSH R16
    ORI R16, 0x04
    RCALL pcf8574_write
    POP R16
    RCALL pcf8574_write
    RCALL delay_ms
    RET

; Inisialisasi LCD 16x2 melalui PCF8574.
init_lcd:
    RCALL i2c_init
    RCALL delay_ms
    RCALL delay_ms

    LDI R16, 0x30
    RCALL lcd_write_nibble_init
    LDI R16, 0x30
    RCALL lcd_write_nibble_init
    LDI R16, 0x30
    RCALL lcd_write_nibble_init
    LDI R16, 0x20
    RCALL lcd_write_nibble_init

    LDI R16, 0x28
    RCALL lcd_command
    LDI R16, 0x0C
    RCALL lcd_command
    RCALL lcd_clear
    LDI R16, 0x06
    RCALL lcd_command
    RET

delay_ms:
    PUSH R23
    PUSH R24
    LDI R23, 40
d_loop1:
    LDI R24, 100
d_loop2:
    DEC R24
    BRNE d_loop2
    DEC R23
    BRNE d_loop1
    POP R24
    POP R23
    RET

; =========================================
; Interrupt.S
; =========================================
.global init_interrupt
.global INT0_vect
.global INT1_vect

.section .text

init_interrupt:
    LDI R16, (1<<ISC01) | (1<<ISC11)
    STS EICRA, R16
    LDI R16, (1<<INT0) | (1<<INT1)
    OUT EIMSK, R16
    CLR R21
    CLR R22
    SEI
    RET

INT0_vect:
    PUSH R16
    IN R16, SREG
    PUSH R16
    INC R21
    LDI R25, 1
    LDI R23, 1
    POP R16
    OUT SREG, R16
    POP R16
    RETI

INT1_vect:
    PUSH R16
    IN R16, SREG
    PUSH R16
    INC R22
    LDI R25, 2
    LDI R23, 1
    POP R16
    OUT SREG, R16
    POP R16
    RETI

; =========================================
; Timer_PWM.S
; =========================================
.global delay_1s
.global delay_short_ms

.section .text

delay_1s:
    LDI R16, hi8(49911)
    STS TCNT1H, R16
    LDI R16, lo8(49911)
    STS TCNT1L, R16
    LDI R16, 0x00
    STS TCCR1A, R16
    LDI R16, (1<<CS12) | (1<<CS10)
    STS TCCR1B, R16
wait_1s:
    IN R16, TIFR1
    SBRS R16, TOV1
    RJMP wait_1s
    LDI R16, 0x00
    STS TCCR1B, R16
    LDI R16, (1<<TOV1)
    OUT TIFR1, R16
    RET

delay_short_ms:
    PUSH R20
    PUSH R21
    PUSH R22
    LDI R20, 20
ds_loop1:
    LDI R21, 255
ds_loop2:
    LDI R22, 100
ds_loop3:
    DEC R22
    BRNE ds_loop3
    DEC R21
    BRNE ds_loop2
    DEC R20
    BRNE ds_loop1
    POP R22             
    POP R21             
    POP R20
    RET

; =========================================
; USART_Log.S
; =========================================
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