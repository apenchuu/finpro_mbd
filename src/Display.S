#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global update_lcd_score
.global update_lcd_mode
.global print_number
.global update_lcd_timeout

.section .progmem
str_volley:    .asciz "  VOLLEYBALL    "
str_badminton: .asciz "   BADMINTON    "
str_timeout:   .asciz "    TIMEOUT     "

.section .text

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