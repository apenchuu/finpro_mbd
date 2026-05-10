#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Deklarasi fungsi agar bisa dipanggil dari file Main.S
.global init_interrupt
.global INT0_vect
.global INT1_vect

.section .text

; inisialisasi external interrupt
init_interrupt:
    ; konfigurasi trigger (falling edge)
    ; karena kita pakai internal pull-up, tombol saat tidak ditekan = HIGH.
    ; saat ditekan, dia jadi LOW. transisi HIGH ke LOW ini disebut falling edge.
    ; isc01 = 1 untuk int0 (pin d2) | isc11 = 1 untuk int1 (pin d3)
    LDI R16, (1<<ISC01) | (1<<ISC11)
    STS EICRA, R16

    ; aktifkan INT0 dan INT1
    ; masking register agar mikrokontroler mulai "mendengarkan" pin D2 dan D3
    LDI R16, (1<<INT0) | (1<<INT1)
    OUT EIMSK, R16

    ; reset skor awal ke 0
    CLR R21     ; R21 = skor tim A
    CLR R22     ; R22 = skor tim B

    ; aktifkan global interrupt
    SEI
    RET

; interrupt service routine - tim A
INT0_vect:
    PUSH R16
    IN R16, SREG        ; simpan status register
    PUSH R16
    INC R21             ; tambah skor tim A
    LDI R25, 1          ; ingat bahwa tim A (1) yang terakhir cetak poin
    LDI R23, 1          ; set flag R23 = 1 (tanda layar butuh di-update)
    POP R16
    OUT SREG, R16       ; pulihkan status register
    POP R16
    RETI

; interrupt service routine - tim B
INT1_vect:
    PUSH R16
    IN R16, SREG        ; simpan status register
    PUSH R16
    INC R22             ; tambah skor tim B
    LDI R25, 2          ; ingat bahwa tim B (2) yang terakhir cetak poin
    LDI R23, 1          ; set flag R23 = 1
    POP R16
    OUT SREG, R16       ; pulihkan status register
    POP R16
    RETI