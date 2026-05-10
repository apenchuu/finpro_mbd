#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global delay_1s
.global delay_short_ms

.section .text

; delay 1 detik presisi (timer1 - normal mode)
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

; delay singkat untuk debounce (looping)
delay_short_ms:
    PUSH R20
    PUSH R21            ; simpan skor tim A
    PUSH R22            ; simpan skor tim B
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
    POP R22             ; pulihkan skor tim B
    POP R21             ; pulihkan skor tim A
    POP R20
    RET