#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global save_score_A
.global save_score_B
.global load_scores
.global reset_eeprom_scores

.section .text

; 1. Simpan skor tim A ke EEPROM (Alamat 0x01)
save_score_A:
    ; tunggu kalau EEPROM masih sibuk menulis data sebelumnya
    SBIC EECR, EEPE
    RJMP save_score_A

    ; set alamat ke 0x0001
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x01
    OUT EEARL, R16

    ; masukkan skor tim A (dari R21) ke Data Register
    OUT EEDR, R21

    ; prosedur wajib penulisan EEPROM (Master Enable -> Enable)
    SBI EECR, EEMPE
    SBI EECR, EEPE
    RET

; 2. Simpan skor tim B ke EEPROM (Alamat 0x02)
save_score_B:
    SBIC EECR, EEPE
    RJMP save_score_B

    ; set alamat ke 0x0002
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x02
    OUT EEARL, R16

    ; Masukkan skor Tim B (dari R22)
    OUT EEDR, R22

    SBI EECR, EEMPE
    SBI EECR, EEPE
    RET

; 3. Baca skor saat arduino baru nyala
load_scores:
    ; baca tim A
wait_read_A:
    SBIC EECR, EEPE
    RJMP wait_read_A
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x01
    OUT EEARL, R16
    SBI EECR, EERE    ; trigger read
    IN R21, EEDR      ; tarik data ke R21

    ; baca tim B
wait_read_B:
    SBIC EECR, EEPE
    RJMP wait_read_B
    LDI R16, 0x00
    OUT EEARH, R16
    LDI R16, 0x02
    OUT EEARL, R16
    SBI EECR, EERE    ; trigger read
    IN R22, EEDR      ; tarik data ke R22
    RET

; reset skor (panggil saat pertandingan selesai)
reset_eeprom_scores:
    CLR R21
    CLR R22
    RCALL save_score_A
    RCALL save_score_B
    RET