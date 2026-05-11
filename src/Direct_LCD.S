#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global init_lcd
.global lcd_command
.global lcd_data
.global lcd_clear

.section .text

; inisialisasi lcd (mode 4-bit)
init_lcd:
    ; Set PC0 (RS), PC1 (EN) sebagai output
    IN R16, DDRC
    ORI R16, (1<<0) | (1<<1)
    OUT DDRC, R16
    
    ; Set PB0-PB3 (D4-D7) sebagai output
    IN R16, DDRB
    ORI R16, (1<<0) | (1<<1) | (1<<2) | (1<<3)
    OUT DDRB, R16
    
    ; Set RS=0, EN=0 (PC0=0, PC1=0)
    IN R16, PORTC
    ANDI R16, ~((1<<0) | (1<<1))
    OUT PORTC, R16

    RCALL delay_ms
    RCALL delay_ms

    ; Sequence Waking Up LCD (Mode 4-bit)
    LDI R16, 0x03
    RCALL lcd_send_nibble_init
    RCALL delay_ms
    
    LDI R16, 0x03
    RCALL lcd_send_nibble_init
    RCALL delay_ms
    
    LDI R16, 0x03
    RCALL lcd_send_nibble_init
    RCALL delay_ms
    
    LDI R16, 0x02
    RCALL lcd_send_nibble_init
    RCALL delay_ms

    ; Setup Konfigurasi Layar
    LDI R16, 0x28   ; Function set: 4-bit, 2 baris, font 5x8
    RCALL lcd_command
    LDI R16, 0x0C   ; Display ON, Cursor OFF, Blink OFF
    RCALL lcd_command
    RCALL lcd_clear ; Bersihkan layar
    LDI R16, 0x06   ; Entry mode set: Geser kursor ke kanan otomatis
    RCALL lcd_command
    RET

; mengirim command (RS = 0)
lcd_command:
    PUSH R16
    CBI PORTC, 0    ; RS = 0
    
    ; kirim 4 bit atas (high nibble)
    MOV R17, R16
    SWAP R17
    RCALL lcd_send_nibble
    
    ; kirim 4 bit bawah (low nibble)
    MOV R17, R16
    RCALL lcd_send_nibble
    
    RCALL delay_ms  ; jeda pemrosesan LCD
    POP R16
    RET

; mengirim data / karakter ascii (RS = 1)
lcd_data:
    PUSH R16
    SBI PORTC, 0    ; RS = 1
    
    ; kirim 4 bit atas
    MOV R17, R16
    SWAP R17
    RCALL lcd_send_nibble
    
    ; kirim 4 bit bawah
    MOV R17, R16
    RCALL lcd_send_nibble
    
    RCALL delay_ms  ; Jeda untuk membiarkan LCD memproses karakter (>37us)
    POP R16
    RET

; clear screen
lcd_clear:
    LDI R16, 0x01
    RCALL lcd_command
    RCALL delay_ms
    RCALL delay_ms
    RET

; subrutine mengirim nibble untuk inisialisasi awal (R16 ke D4-D7)
lcd_send_nibble_init:
    MOV R17, R16
    ; fallthrough ke lcd_send_nibble

; subrutine mengirim 4 bit terbawah dari R17 ke PB0-PB3 (D4-D7)
lcd_send_nibble:
    PUSH R18
    PUSH R19
    
    IN R18, PORTB
    ANDI R18, 0xF0  ; clear bit 0-3
    MOV R19, R17
    ANDI R19, 0x0F  ; ambil 4 bit dari R17
    OR R18, R19
    OUT PORTB, R18
    
    ; Setup time
    NOP
    NOP
    
    ; trigger EN (PC1) HIGH
    SBI PORTC, 1
    
    ; Hold EN HIGH (Pulse width > 450ns, 8 NOP = 500ns @16MHz)
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    
    ; trigger EN (PC1) LOW
    CBI PORTC, 1
    
    ; Hold time
    NOP
    NOP
    
    POP R19
    POP R18
    RET

; delay sederhana (looping)
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
