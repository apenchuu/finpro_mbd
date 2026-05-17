#define __SFR_OFFSET 0x00
#include <avr/io.h>

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