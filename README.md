# PROYEK AKHIR MBD - KELOMPOK 1 || Sistem Scoreboard Digital Multi-Cabang Olahraga

- Steven (2406421831)
- Aridho Sectio Caesar (2406421831)
- Aidan Ardhazizi (2406430483)
- Otniel Kristian Sianturi

---

## Introduction

**Sistem Scoreboard Digital Multi-Cabang Olahraga** adalah perangkat pencatat skor otomatis berbasis mikrokontroler **ATmega328P** yang dirancang untuk pertandingan Bola Voli dan Bulu Tangkis. Perangkat ini diprogram sepenuhnya menggunakan **bahasa AVR Assembly** dan mengimplementasikan **7 modul praktikum terintegrasi**: I/O Programming, External Interrupt, Hardware Timer, Komunikasi I2C, EEPROM, Serial USART, dan Aritmatika. Sistem ini menyediakan antarmuka real-time melalui **LCD 16x2 (I2C)**, indikator *Match Point* via LED, dan sistem *logging* otomatis ke Serial Monitor.

---

## Fitur Utama
- **Dua Mode Olahraga:** Logika batas kemenangan adaptif untuk Bola Voli (25 poin) dan Bulu Tangkis (21 poin) beserta perhitungan *Deuce*.
- **Input Responsif & Anti-Bouncing:** Menggunakan *External Interrupt* (INT0 & INT1) yang dilengkapi *Software Debouncing* (manipulasi register EIFR).
- **Auto-Save EEPROM:** Data skor aman dan otomatis dimuat kembali saat alat dinyalakan ulang (mati listrik).
- **Serial Logging (USART):** Log riwayat poin dan status pemenang dikirimkan secara *real-time* ke terminal komputer.
- **Fitur Pertandingan Lengkap:** Tersedia tombol untuk *Undo* (pembatalan skor) dan *Timeout* (Timer presisi 60 detik hitung mundur).
- **Indikator Visual:** LED *Match Point* menyala otomatis untuk tim yang sedang memimpin di poin kritis.

---

## Struktur Modul
- `Main.S` – Prosedur utama (*state machine*), logika perhitungan batas skor, *deuce*, dan eksekusi LED Match Point.
- `Interrupt.S` – Konfigurasi dan *handler External Interrupt* (INT0 & INT1) serta algoritma *software debouncing*.
- `Display.S` – Konversi angka biner ke ASCII dan pembaruan antarmuka data pada layar.
- `I2C_LCD.S` – Driver antarmuka komunikasi TWI/I2C (SDA/SCL) ke modul PCF8574 untuk mengendalikan LCD 16x2.
- `Timer_PWM.S` – Pengaturan *Hardware Timer1* (16-bit) untuk menghasilkan *delay* presisi *Timeout* 60 detik dan rutinitas *polling*.
- `EEPROM_Data.S` – Fungsi baca/tulis data memori non-volatile (*Auto-Save* & *Load*).
- `USART_Log.S` – Komunikasi serial UART (Baud Rate 9600) untuk pengiriman data teks log ke terminal PC.

---

## Komponen yang Dibutuhkan

| Nama Komponen          | Jumlah | Keterangan                                  |
|------------------------|--------|---------------------------------------------|
| ATmega328P / Arduino   | 1      | Mikrokontroler utama                        |
| LCD 16x2               | 1      | Antarmuka tampilan utama                    |
| Modul PCF8574 (I2C)    | 1      | I/O Expander (Backpack LCD)                 |
| Push Button            | 4      | Trigger Skor (2), Undo (1), Ganti Mode (1)  |
| LED (Warna Bebas)      | 2      | Indikator Match Point Tim A & Tim B         |
| Resistor 220Ω          | 2      | Pembatas arus untuk lampu LED               |
| Breadboard             | 1      | Papan perakitan rangkaian                   |
| Kabel Jumper M-M / M-F | ~25    | Koneksi antar komponen                      |

---

## Konfigurasi Pin ATmega328P

| Fungsi                 | Pin ATmega328P / Arduino |
|------------------------|--------------------------|
| Tombol Skor Tim A      | PD2 (Digital 2 / INT0)   |
| Tombol Skor Tim B      | PD3 (Digital 3 / INT1)   |
| Tombol Undo / Timeout  | PD4 (Digital 4)          |
| Tombol Ganti Mode      | PD5 (Digital 5)          |
| LED Match Point Tim A  | PB4 (Digital 12)         |
| LED Match Point Tim B  | PB5 (Digital 13)         |
| I2C SDA (Data LCD)     | PC4 (Analog A4)          |
| I2C SCL (Clock LCD)    | PC5 (Analog A5)          |
| UART TX (Log Komputer) | PD1 (Digital 1 / TX)     |
| UART RX                | PD0 (Digital 0 / RX)     |

*(Catatan: Keempat tombol mekanis memanfaatkan internal pull-up ATmega328P, sehingga pin dirangkai langsung ke Ground tanpa resistor eksternal).*

---

## Cara Kerja Sistem
1. Saat dihidupkan, mikrokontroler mengecek data di **EEPROM**. Jika ada riwayat pertandingan, skor dilanjutkan. Layar **LCD** menampilkan jenis olahraga dan skor awal (A:00 B:00).
2. Wasit menekan tombol Tim A atau B. Sinyal masuk melalui **External Interrupt**, disaring oleh rutin *software debouncing*, lalu skor bertambah 1 poin.
3. Skor terbaru seketika ditampilkan di LCD, dicadangkan ke EEPROM, dan dilog ke **Serial Monitor** ("`[LOG] Skor -> A: 01 | B: 00`").
4. Jika skor mencapai angka kritis (misal: 20 di Badminton) dan tim dalam posisi unggul, mikrokontroler menyalakan **LED Match Point** terkait.
5. Jika terjadi salah pencet, menekan singkat tombol **Undo** akan membatalkan 1 skor terakhir dari tim yang baru saja mencetak angka.
6. Menahan tombol Undo selama 1 detik memicu **Timer1**, mengubah layar menjadi mode **TIMEOUT** dengan hitung mundur presisi 60 detik.
7. Menekan tombol **Mode** akan mereset skor, membersihkan memori EEPROM, dan mengganti batas poin kemenangan (Bola Voli $\leftrightarrow$ Bulu Tangkis).
8. Jika tim menang (mencapai target poin dengan selisih minimal 2 poin), Serial Monitor mencetak *"MATCH OVER!"*, skor reset ke 0, dan permainan baru siap dimulai.
