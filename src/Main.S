#define __SFR_OFFSET 0x00
#include "avr/io.h"

.global main

; setup awal (booting)
.section .text
main:
    ; stack pointer (standar avr)
    LDI R16, hi8(RAMEND)
    OUT SPH, R16
    LDI R16, lo8(RAMEND)
    OUT SPL, R16

    ; inisialisasi pin input (d2, d3, d4, d5)
    ; d2 (int0) = skor a | d3 (int1) = skor b | d4 = undo | d5 = ganti mode
    IN R16, DDRD
    ANDI R16, ~((1<<2) | (1<<3) | (1<<4) | (1<<5)) ; clear bit 2,3,4,5 (set sbg input)
    OUT DDRD, R16

    ; internal pull-up untuk tombol
    IN R16, PORTD
    ORI R16, (1<<2) | (1<<3) | (1<<4) | (1<<5)     ; Set bit 2,3,4,5 jadi HIGH
    OUT PORTD, R16
    CLR R24         ; Set mode awal: Volley (R24 = 0)
    CLR R25         ; Reset history undo

    RCALL init_interrupt
    RCALL init_i2c_lcd
    RCALL init_usart
    RCALL load_scores
    RCALL update_lcd_mode
    RCALL update_lcd_score

; loop utama (state machine)
main_loop:
    ; cek apakah ada request update layar dari interrupt? (cek flag r23)
    CPI R23, 1
    BRNE skip_update
    
    ; jika r23 = 1, jalankan update LCD, buzzer, dan EEPROM
    RCALL update_lcd_mode
    RCALL update_lcd_score
    RCALL log_score
    RCALL save_score_A
    RCALL save_score_B
    RCALL check_win
    CLR R23                 ; reset Flag ke 0

skip_update:
    ; cek tombol Undo (D4)
    SBIS PIND, 4
    RCALL undo_logic
    
    ; cek tombol Ganti Mode (D5)
    SBIS PIND, 5
    RCALL mode_logic

    RJMP main_loop

; fungsi undo & timeout (d4) - deteksi long/short press
undo_logic:
    LDI R18, 0              ; R18 = counter untuk mendeteksi long press

cek_tahan:
    RCALL delay_short_ms    ; delay sekitar 20ms dari Timer_PWM.S
    SBIC PIND, 4            ; apakah tombol sudah dilepas (HIGH)?
    RJMP short_press        ; jika dilepas cepat, berarti short press
    
    INC R18
    CPI R18, 50             ; 50 * 20ms = sekitar 1 detik tombol ditahan
    BREQ long_press         ; jika sudah 1 detik ditahan, lompat ke timeout
    RJMP cek_tahan

; logika undo
short_press:
    CPI R25, 1              ; apakah Tim A yang terakhir cetak poin?
    BREQ undo_tim_a
    CPI R25, 2              ; apakah Tim B yang terakhir cetak poin?
    BREQ undo_tim_b
    RET                     ; tidak ada history, batalkan Undo

undo_tim_a:
    TST R21                 ; pastikan skor A tidak 0
    BREQ selesai_undo
    DEC R21                 ; kurangi skor A
    RJMP selesai_undo

undo_tim_b:
    TST R22                 ; pastikan skor B tidak 0
    BREQ selesai_undo
    DEC R22                 ; kurangi skor B

selesai_undo:
    CLR R25                 ; hapus history agar tidak bisa di-undo 2 kali berturut-turut
    LDI R23, 1              ; nyalakan flag update layar
    RET

; logika timeout
long_press:
    ; siapkan hitung mundur 60 detik
    LDI R19, 60

timeout_loop:
    ; tampilkan "TIMEOUT" dan sisa waktu ke LCD
    RCALL update_lcd_timeout

    ; panggil delay presisi 1 detik dari Timer_PWM.S
    RCALL delay_1s

    ; kurangi sisa waktu
    DEC R19
    BRNE timeout_loop       ; ulangi sampai R19 = 0

    ; timeout selesai! kembali ke permainan
    LDI R23, 1              ; perbarui layar agar skor tampil lagi

wait_release_4:
    SBIS PIND, 4            ; pastikan udah lepas dari tombol D4
    RJMP wait_release_4
    RET

; fungsi ganti mode & logika pemenang
mode_logic:
    ; debounce sederhana (tunggu tombol dilepas)
wait_release_5:
    SBIS PIND, 5
    RJMP wait_release_5
    RCALL delay_short_ms    ; delay dari Timer_PWM.S

    ; toggle mode (R24) antara 0 dan 1
    LDI R16, 1
    EOR R24, R16            ; exclusive OR, 0 jadi 1, 1 jadi 0

    ; kalau ganti mode, skor kita reset
    RCALL reset_eeprom_scores   ; dari EEPROM_Data.S
    CLR R25                     ; hapus history undo
    LDI R23, 1                  ; beri flag update layar
    RET

; fungsi cek pemenang & deuce (dipanggil otomatis di loop utama)
check_win:
    ; tentukan target poin berdasarkan mode (R24)
    CPI R24, 0
    BREQ target_volley
target_badminton:
    LDI R17, 21
    RJMP cek_batas
target_volley:
    LDI R17, 25

cek_batas:
    ; apakah ada yang sudah mencapai target poin?
    CP R21, R17
    BRGE hitung_selisih   ; tim A >= target
    CP R22, R17
    BRGE hitung_selisih   ; tim B >= target
    RET                   ; belum ada yang sampai target, lanjut main

hitung_selisih:
    ; logika menang = harus selisih 2 poin (deuce handling)
    MOV R18, R21
    MOV R19, R22
    CP R18, R19
    BRGE tim_a_memimpin

tim_b_memimpin:
    ; selisih = skor B - skor A
    SUB R19, R18
    CPI R19, 2
    BRGE tim_b_menang
    RET                   ; selisih masih 1, ini deuce!

tim_a_memimpin:
    ; selisih = skor A - skor B
    SUB R18, R19
    CPI R18, 2
    BRGE tim_a_menang
    RET                   ; selisih masih 1, ini deuce!

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