#define __SFR_OFFSET 0x00
#include <avr/io.h>

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