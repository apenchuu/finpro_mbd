#define __SFR_OFFSET 0x00
#include <avr/io.h>

.global main

.section .text
main:
    ; stack pointer (standar avr)
    LDI R16, hi8(RAMEND)
    OUT SPH, R16
    LDI R16, lo8(RAMEND)
    OUT SPL, R16

    ; inisialisasi pin input (d2, d3, d4, d5)
    IN R16, DDRD
    ANDI R16, ~((1<<2) | (1<<3) | (1<<4) | (1<<5))
    OUT DDRD, R16

    ; internal pull-up untuk tombol
    IN R16, PORTD
    ORI R16, (1<<2) | (1<<3) | (1<<4) | (1<<5)
    OUT PORTD, R16

    ; inisialisasi Pin LED Match Point
    IN R16, DDRB
    ORI R16, (1<<4) | (1<<5)   
    OUT DDRB, R16

    IN R16, PORTB
    ANDI R16, ~((1<<4) | (1<<5)) 
    OUT PORTB, R16

    CLR R24         ; Set mode awal: Volley (R24 = 0)
    CLR R25         ; Reset history undo

    RCALL init_interrupt
    RCALL init_lcd            
    RCALL init_usart
    RCALL load_scores
    RCALL update_lcd_mode
    RCALL update_lcd_score
    RCALL check_match_point   

main_loop:
    CPI R23, 1
    BRNE skip_update
    
    RCALL update_lcd_mode
    RCALL update_lcd_score
    RCALL check_match_point   
    RCALL log_score
    RCALL save_score_A
    RCALL save_score_B
    RCALL check_win
    CLR R23                 

skip_update:
    SBIS PIND, 4
    RCALL undo_logic
    
    SBIS PIND, 5
    RCALL mode_logic

    RJMP main_loop

undo_logic:
    LDI R18, 0              

cek_tahan:
    RCALL delay_short_ms    
    SBIC PIND, 4            
    RJMP short_press        
    
    INC R18
    CPI R18, 50             
    BREQ long_press         
    RJMP cek_tahan

short_press:
    CPI R25, 1              
    BREQ undo_tim_a
    CPI R25, 2              
    BREQ undo_tim_b
    RET                     

undo_tim_a:
    TST R21                 
    BREQ selesai_undo
    DEC R21                 
    RJMP selesai_undo

undo_tim_b:
    TST R22                 
    BREQ selesai_undo
    DEC R22                 

selesai_undo:
    CLR R25                 
    LDI R23, 1              
    RET

long_press:
    LDI R19, 60

timeout_loop:
    RCALL update_lcd_timeout
    RCALL delay_1s
    DEC R19
    BRNE timeout_loop       

    LDI R23, 1              

wait_release_4:
    SBIS PIND, 4            
    RJMP wait_release_4
    RET

mode_logic:
wait_release_5:
    SBIS PIND, 5
    RJMP wait_release_5
    RCALL delay_short_ms    

    LDI R16, 1
    EOR R24, R16            

    RCALL reset_eeprom_scores   
    CLR R25                     
    LDI R23, 1                  
    RET

check_win:
    CPI R24, 0
    BREQ target_volley
target_badminton:
    LDI R17, 21
    RJMP cek_batas
target_volley:
    LDI R17, 25

cek_batas:
    CP R21, R17
    BRGE hitung_selisih   
    CP R22, R17
    BRGE hitung_selisih   
    RET                   

hitung_selisih:
    MOV R18, R21
    MOV R19, R22
    CP R18, R19
    BRGE tim_a_memimpin

tim_b_memimpin:
    SUB R19, R18
    CPI R19, 2
    BRGE tim_b_menang
    RET                   

tim_a_memimpin:
    SUB R18, R19
    CPI R18, 2
    BRGE tim_a_menang
    RET                   

tim_a_menang:
    RCALL log_winner_A
    RCALL reset_eeprom_scores
    CLR R25
    LDI R23, 1
    RET

tim_b_menang:
    RCALL log_winner_B
    RCALL reset_eeprom_scores
    CLR R25
    LDI R23, 1
    RET

check_match_point:
    PUSH R16
    PUSH R17

    IN R16, PORTB
    ANDI R16, ~((1<<4) | (1<<5))
    OUT PORTB, R16

    CPI R24, 0
    BREQ mp_volley
mp_badminton:
    LDI R17, 21          
    RJMP hitung_mp
mp_volley:
    LDI R17, 25          

hitung_mp:
    DEC R17              

    CP R21, R17          
    BRLT cek_mp_b        
    CP R21, R22          
    BRLO cek_mp_b        
    BREQ cek_mp_b        
    
    IN R16, PORTB
    ORI R16, (1<<4)
    OUT PORTB, R16

cek_mp_b:
    CP R22, R17          
    BRLT selesai_mp      
    CP R22, R21          
    BRLO selesai_mp      
    BREQ selesai_mp      
    
    IN R16, PORTB
    ORI R16, (1<<5)
    OUT PORTB, R16

selesai_mp:
    POP R17
    POP R16
    RET