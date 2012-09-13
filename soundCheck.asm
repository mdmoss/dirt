; Speaker tests.  Two configurations for board: 
; Without Filter: 
;   PortB7 -> AIn    - Audio Input 
;   PushB0 -> PortA0 - Push the button to change frequency 
;   PushB1 -> ASD    - Hold the button to enable audio     
; 
; With Filter: 
;   PortB4 -> FCk    - Filter clock, set to 73,728 Hz for a corner frequency of 737.28 Hz 
;   PortB7 -> FIn    - Filter Input 
;   PortB2 -> FEn    - Filter Enable, set to 1, so enabled 
;   FOp -> Ain       - Filter Output connected to speaker  
;   PushB0 -> PortA0 - Push the button to change frequency 
;   PushB1 -> ASD    - Hold the button to enable audio     
; 
; Frequencies in this example are generated with CTC mode, meaning: 
; F = 7372800 / (2 * prescalar * (OCR+1))  
; 
.include "m64def.inc" 
.def temp=r16 
.equ FREQ1=95 ; will generate 600 Hz  
.equ FREQ2=47 ; will generate 1200 Hz 
 
RESET: ldi temp, (1 << WGM01) | (1 << COM00) | (1 << CS00); CTC mode, toggle OC0, 7.3728MHz clock 
  out TCCR0, temp 
  ldi temp, 80
  out OCR0, temp ; waveform will toggle every 50 cycles, corner frequency is 737.28 Hz.   
  ldi temp, (1 << WGM21) | (1 << COM20) | (3 << CS20); CTC mode, toggle OC2, prescalar = 64 
  out TCCR2, temp 
  ser temp 
  out DDRB, temp ; PORT B is outputs 
  ldi temp, 0x0C 
  out PORTb, temp ; Set up output values to enable filter and speaker 
  clr temp 
  out DDRA, temp ; Set up Port A for input 
loop: 
  inc temp
  out OCR2, temp ; Set frequency 
  rjmp loop 
