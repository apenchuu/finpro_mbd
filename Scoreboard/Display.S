#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global update_lcd_score
.global update_lcd_mode
.global print_number
.global update_lcd_timeout

; data teks di flash memory
.section .progmem
str_volley:    .asciz "  VOLLEYBALL    "
str_badminton: .asciz "   BADMINTON    "
str_timeout:   .asciz "    TIMEOUT     "

.section .text

; fungsi update baris 1 (mode olahraga)
update_lcd_mode:
    ; 1. posisikan kursor ke baris 1, kolom 1 (command: 0x80)
    LDI R16, 0x80
    RCALL lcd_command

    ; 2. Pilih teks berdasarkan Mode (R24: 0=Volley, 1=Badminton)
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
    ; Loop membaca karakter dari Flash satu per satu
lpm_loop:
    LPM R16, Z+
    CPI R16, 0      ; Cek apakah sudah sampai akhir teks (null terminator)
    BREQ selesai_mode
    RCALL lcd_data  ; Kirim karakter ke LCD
    RJMP lpm_loop
selesai_mode:
    RET

; fungsi update baris 2 (skor)
update_lcd_score:
    ; 1. posisikan kursor ke baris 2, kolom 1 (command: 0xC0)
    LDI R16, 0xC0
    RCALL lcd_command

    ; 2. Print Teks "A:" dan skor Tim A
    LDI R16, 'A'
    RCALL lcd_data
    LDI R16, ':'
    RCALL lcd_data
    MOV R16, R21
    RCALL print_number

    ; 3. Spasi tengah
    LDI R16, ' '
    RCALL lcd_data
    RCALL lcd_data
    RCALL lcd_data
    RCALL lcd_data

    ; 4. Print Teks "B:" dan skor Tim B
    LDI R16, 'B'
    RCALL lcd_data
    LDI R16, ':'
    RCALL lcd_data
    MOV R16, R22
    RCALL print_number
    RET

; fungsi konversi angka ke ASCII 2 digit
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
    SUBI R16, -'0'  ; Cara singkat menambah '0' (negatif dari -48)
    RCALL lcd_data
    RET

; fungsi update lcd saat timeout (countdown 60 -> 0)
; input: R19 = sisa detik
update_lcd_timeout:
    ; 1. posisikan kursor ke baris 1, kolom 1
    LDI R16, 0x80
    RCALL lcd_command

    ; 2. Print "    TIMEOUT     " di baris 1
    LDI ZL, lo8(str_timeout)
    LDI ZH, hi8(str_timeout)
timeout_lpm:
    LPM R16, Z+
    CPI R16, 0
    BREQ timeout_baris2
    RCALL lcd_data
    RJMP timeout_lpm

timeout_baris2:
    ; 3. Posisikan Kursor ke Baris 2, Kolom 1
    LDI R16, 0xC0
    RCALL lcd_command

    ; 4. Print 7 spasi untuk centering
    LDI R18, 7
timeout_spasi1:
    LDI R16, ' '
    RCALL lcd_data
    DEC R18
    BRNE timeout_spasi1

    ; 5. Print angka countdown (2 digit dari R19)
    MOV R16, R19
    RCALL print_number

    ; 6. Print 7 spasi penutup (bersihkan sisa karakter lama)
    LDI R18, 7
timeout_spasi2:
    LDI R16, ' '
    RCALL lcd_data
    DEC R18
    BRNE timeout_spasi2

    RET
