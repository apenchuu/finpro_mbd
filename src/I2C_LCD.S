#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global init_lcd
.global lcd_command
.global lcd_data
.global lcd_clear

.section .text

i2c_init:
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

    ; High Nibble
    MOV R18, R19
    ANDI R18, 0xF0       
    OR R18, R17          
    ORI R18, 0x08        
    MOV R16, R18
    ORI R16, 0x04        
    RCALL pcf8574_write
    MOV R16, R18         
    RCALL pcf8574_write

    ; Low Nibble
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