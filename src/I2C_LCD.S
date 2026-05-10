#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global init_i2c_lcd
.global lcd_command
.global lcd_data
.global lcd_clear

.section .text

; inisialisasi i2c dan lcd
init_i2c_lcd:
    ; setup baud rate i2c (TWBR)
    ; f_cpu = 16MHz, target scl = 100khz -> twbr = 72
    LDI R16, 72
    STS TWBR, R16
    CLR R16
    STS TWSR, R16   ; prescaler i2c = 1

    RCALL delay_ms  ; tunggu lcd nyala stabil (>15ms)
    RCALL delay_ms

    ; sequence waking up lcd (mode 4-bit)
    ; kirim 0x30 tiga kali, lalu 0x20
    LDI R16, 0x38   ; 0x30 + Backlight ON (0x08)
    RCALL lcd_send_nibble
    RCALL delay_ms

    LDI R16, 0x38
    RCALL lcd_send_nibble
    RCALL delay_ms

    LDI R16, 0x38
    RCALL lcd_send_nibble
    RCALL delay_ms

    LDI R16, 0x28   ; set ke mode 4-bit (0x20 + Backlight ON)
    RCALL lcd_send_nibble
    RCALL delay_ms

    ; setup konfigurasi layar (sudah bisa pakai fungsi lcd_command)
    LDI R16, 0x28   ; function set: 4-bit, 2 baris, font 5x8
    RCALL lcd_command

    LDI R16, 0x0C   ; display ON, cursor OFF, blink OFF
    RCALL lcd_command

    RCALL lcd_clear ; bersihkan layar dari karakter sisa

    LDI R16, 0x06   ; entry mode set: geser kursor ke kanan otomatis
    RCALL lcd_command
    RET

; mengirim command (RS = 0)
lcd_command:
    PUSH R16
    ; kirim 4 bit atas (high nibble)
    ANDI R16, 0xF0  ; ambil 4 bit atas saja
    ORI R16, 0x08   ; gabung dgn backlight ON (bit 3) & RS=0 (bit 0)
    RCALL lcd_send_nibble

    ; kirim 4 bit bawah (low nibble)
    POP R16
    SWAP R16        ; tukar posisi atas ke bawah (nibble swap)
    ANDI R16, 0xF0  ; ambil 4 bit yang sekarang di atas
    ORI R16, 0x08   ; gabung dgn backlight ON & RS=0
    RCALL lcd_send_nibble
    RCALL delay_ms  ; jeda pemrosesan LCD
    RET

; mengirim data / karakter ascii (RS = 1)
lcd_data:
    PUSH R16
    ; kirim 4 bit atas
    ANDI R16, 0xF0
    ORI R16, 0x09   ; Backlight ON (Bit 3) & RS=1 (Bit 0) -> 1001 = 0x09
    RCALL lcd_send_nibble

    ; kirim 4 bit bawah
    POP R16
    SWAP R16
    ANDI R16, 0xF0
    ORI R16, 0x09   ; Backlight ON & RS=1
    RCALL lcd_send_nibble
    RET

; clear screen
lcd_clear:
    LDI R16, 0x01
    RCALL lcd_command
    RCALL delay_ms
    RCALL delay_ms  ; clear screen butuh waktu sedikit lebih lama
    RET

; mengirim data / karakter ascii (RS = 1)
lcd_data:
    PUSH R16
    ; kirim 4 bit atas
    ANDI R16, 0xF0
    ORI R16, 0x09   ; Backlight ON (Bit 3) & RS=1 (Bit 0) -> 1001 = 0x09
    RCALL lcd_send_nibble

    ; kirim 4 bit bawah
    POP R16
    SWAP R16
    ANDI R16, 0xF0
    ORI R16, 0x09   ; Backlight ON & RS=1
    RCALL lcd_send_nibble
    RET

; clear screen
lcd_clear:
    LDI R16, 0x01
    RCALL lcd_command
    RCALL delay_ms
    RCALL delay_ms  ; Clear screen butuh waktu sedikit lebih lama
    RET

; subrutine pendukung: kirim nibble via i2c
lcd_send_nibble:
    ; data mentah (plus status rs/rw/backlight) sudah ada di r16
    ; kirim data dengan en = 1 (bit 2 di-set jadi 1)
    PUSH R16
    ORI R16, 0x04   ; tambahkan sinyal en high
    RCALL i2c_send_pcf

    ; kirim data dengan en = 0 (pulse turun untuk nge-latch data di lcd)
    POP R16
    RCALL i2c_send_pcf
    RET

; subrutine komunikasi i2c ke chip pcf8574
i2c_send_pcf:
    PUSH R18
    ; start condition
    LDI R18, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS TWCR, R18
    RCALL wait_i2c

    ; kirim alamat i2c pcf8574 (0x20 di-shift kiri 1 bit = 0x40 untuk write)
    LDI R18, 0x40
    STS TWDR, R18
    LDI R18, (1<<TWINT)|(1<<TWEN)
    STS TWCR, R18
    RCALL wait_i2c

    ; kirim data yang ada di R16
    STS TWDR, R16
    LDI R18, (1<<TWINT)|(1<<TWEN)
    STS TWCR, R18
    RCALL wait_i2c

    ; stop condition
    LDI R18, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS TWCR, R18

    POP R18
    RET

wait_i2c:
    LDS R18, TWCR
    SBRS R18, 7     ; tunggu bit TWINT (bit ke-7) berubah jadi 1
    RJMP wait_i2c
    RET

; delay sederhana (looping)
delay_ms:
    PUSH R23            ; Simpan Update Flag
    PUSH R24            ; Simpan Mode Olahraga
    LDI R23, 40
d_loop1:
    LDI R24, 100
d_loop2:
    DEC R24
    BRNE d_loop2
    DEC R23
    BRNE d_loop1
    POP R24             ; Pulihkan Mode Olahraga
    POP R23             ; Pulihkan Update Flag
    RET