; dirt.asm
;
; Dirt
;
; A game by
; Matthew Moss and Tony Ward
; mdm@cse.unsw.edu.au

.include "m64def.inc"

; Shared
.def score_high = r2
.def score_low = r3
.def temp = r16
.def temp2 = r17
.def lcd_data = r23

; Game
.def tick_count = r6
.def ticks_per_step = r19
.equ TICKS_PER_SECOND = 225 ;(7.3728 * 10^6) / (128 * 256) = 225 
.def finished = r18

; Title

.cseg
	; Set up interrupt vectors
	jmp reset
	jmp reset ; IRQ0 Handler
	jmp reset ; IRQ1 Handler
	jmp reset ; IRQ2 Handler
	jmp reset ; IRQ3 Handler
	jmp reset ; IRQ4 Handler
	jmp reset ; IRQ5 Handler
	jmp reset ; IRQ6 Handler
	jmp reset ; IRQ7 Handler
	jmp reset ; Timer2 Compare Handler
	jmp reset ; Timer2 Overflow Handler
	jmp reset ; Timer1 Capture Handler
	jmp reset ; Timer1 CompareA Handler
	jmp reset ; Timer1 CompareB Handler
	jmp reset ; Timer1 Overflow Handler
	jmp reset ; Timer0 Compare Handler
	jmp timer0 ; Timer0 Overflow Handler

reset:
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, low(RAMEND)
	out SPL, temp

	clr finished
	clr tick_count
	clr score_low
	clr score_high

	call lcd_init
	call game_start

end:
	rjmp end

game_start:
	push temp
	in temp, sreg
	push temp
	push ticks_per_step
	push tick_count
	push finished

	ldi temp, 0b00000101; Prescalar 128
	out TCCR0, temp
	ldi temp, 0b00000001; Timer0 overflow interrupt on
	out TIMSK, temp

	;Load the correct steps for the level
	ldi ticks_per_step, ticks_per_second

	; Start interrupts
	sei

game_loop:

	tst finished
	breq game_loop

game_end:
	
	pop finished
	pop tick_count
	pop ticks_per_step
	pop temp
	out sreg, temp
	pop temp

	ret


/***************************************************/
.def lcd_data =r23
.def delay_input_low = r24; < Completely local, safe to reuse
.def delay_input_high = r25; < Completely local, safe to reuse
;LCD protocol control bits
.equ LCD_RS = 6
.equ LCD_RW = 4
.equ LCD_E = 5
;LCD functions
.equ LCD_FUNC_SET = 0b00110000
.equ LCD_DISP_OFF = 0b00001000
.equ LCD_DISP_CLR = 0b00000001
.equ LCD_DISP_ON = 0b00001100
.equ LCD_ENTRY_SET = 0b00000100
.equ LCD_ADDR_SET = 0b10000000
;LCD function bits and constants
.equ LCD_BF = 7
.equ LCD_N = 3
.equ LCD_F = 2
.equ LCD_ID = 1
.equ LCD_S = 0
.equ LCD_C = 1
.equ LCD_B = 0
.equ LCD_LINE1 = 0
.equ LCD_LINE2 = 0x40
; LCD Ports
.equ LCD_DATA_PORT = PORTC
.equ LCD_DATA_DIR_REG = DDRC
.equ LCD_DATA_PORT_PINS = PINC
.equ LCD_CONTROL_PORT = PORTD
.equ LCD_CONTROL_DIR_REG = DDRD
; Note: PortD is shifted up by 3 to make room for ext interrupts
/*****************************************************/


/****************************************************************************************************************************************/

;Function lcd_write_com: Write a command to the LCD. The data reg stores the value to be written.
lcd_write_com:
	push temp
	in temp, sreg
	push temp	

	out LCD_DATA_PORT, lcd_data ; set the data port's value up
	in temp, LCD_CONTROL_PORT
	andi temp, 0b00000111
	out LCD_CONTROL_PORT, temp ; RS = 0, RW = 0 for a command write
	nop ; delay to meet timing (Set up time)
	sbi LCD_CONTROL_PORT, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi LCD_CONTROL_PORT, LCD_E ; turn off the enable pin
	nop ; delay to meet timing (Enable cycle time)
	nop
	nop

	pop temp
	out sreg, temp
	pop temp

	ret

/******************************************************************************/

;Function lcd_write_data: Write a character to the LCD. The data reg stores the value to be written.
lcd_write_data:

	push temp
	in temp, sreg
	push temp	

	out LCD_DATA_PORT, lcd_data ; set the data port's value up
	ldi temp, 1 << LCD_RS
	out LCD_CONTROL_PORT, temp ; RS = 1, RW = 0 for a data write
	nop ; delay to meet timing (Set up time)
	sbi LCD_CONTROL_PORT, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Enable pulse width)
	nop
	nop
	cbi LCD_CONTROL_PORT, LCD_E ; turn off the enable pin
	nop ; delay to meet timing (Enable cycle time)
	nop
	nop

	pop temp
	out sreg, temp
	pop temp

	ret

/******************************************************************************/

;Function lcd_wait_busy: Read the LCD busy flag until it reads as not busy.
lcd_wait_busy:
	push temp
	in temp, sreg
	push temp

	clr temp
	out LCD_DATA_DIR_REG, temp ; Make LCD_DATA_PORT be an input port for now
	out LCD_DATA_PORT, temp
	ldi temp, 1 << LCD_RW
	out LCD_CONTROL_PORT, temp ; RS = 0, RW = 1 for a command port read

busy_loop:
	nop ; delay to meet timing (Set up time / Enable cycle time)
	sbi LCD_CONTROL_PORT, LCD_E ; turn on the enable pin
	nop ; delay to meet timing (Data delay time)
	nop
	nop
	in temp, LCD_DATA_PORT_PINS ; read value from LCD
	cbi LCD_CONTROL_PORT, LCD_E ; turn off the enable pin
	sbrc temp, LCD_BF ; if the busy flag is set
	rjmp busy_loop ; repeat command read
	clr temp ; else
	out LCD_CONTROL_PORT, temp ; turn off read mode,
	ser temp
	out LCD_DATA_DIR_REG, temp ; make LCD_DATA_PORT an output port again

	pop temp
	out sreg, temp
	pop temp

	ret ; and return

/******************************************************************************/

;Function lcd_init Initialisation function for LCD.
lcd_init:

	push temp
	in temp, sreg
	push temp
	push delay_input_low
	push delay_input_high
	push lcd_data

	ser temp
	out LCD_DATA_DIR_REG, temp ; LCD_DATA_PORT, the data port is usually all otuputs
    ldi temp, 0b11111000
	out LCD_CONTROL_DIR_REG, temp ; LCD_CONTROL_PORT, the control port is always all outputs, this accounts for a shift of three
	ldi delay_input_low, low(15000)
	ldi delay_input_high, high(15000)
	rcall delay ; delay for > 15ms
	; Function set command with N = 1 and F = 0
	ldi lcd_data, LCD_FUNC_SET | (1 << LCD_N)
	rcall lcd_write_com ; 1st Function set command with 2 lines and 5*7 font
	ldi delay_input_low, low(4100)
	ldi delay_input_high, high(4100)
	rcall delay ; delay for > 4.1ms
	rcall lcd_write_com ; 2nd Function set command with 2 lines and 5*7 font
	ldi delay_input_low, low(100)
	ldi delay_input_high, high(100)
	rcall delay ; delay for > 100us
	rcall lcd_write_com ; 3rd Function set command with 2 lines and 5*7 font
	rcall lcd_write_com ; Final Function set command with 2 lines and 5*7 font
	rcall lcd_wait_busy ; Wait until the LCD is ready
	ldi lcd_data, LCD_DISP_OFF
	rcall lcd_write_com ; Turn Display off
	rcall lcd_wait_busy ; Wait until the LCD is ready
	ldi lcd_data, LCD_DISP_CLR
	rcall lcd_write_com ; Clear Display
	rcall lcd_wait_busy ; Wait until the LCD is ready
	; Entry set command with I/D = 1 and S = 0
	ldi lcd_data, LCD_ENTRY_SET | (1 << LCD_ID)
	rcall lcd_write_com ; Set Entry mode: Increment = yes and Shift = no
	rcall lcd_wait_busy ; Wait until the LCD is ready
	; Display on command with C = 0 and B = 1
	ldi lcd_data, LCD_DISP_ON | (1 << LCD_C)
	rcall lcd_write_com ; Trun Display on with a cursor that doesn't blink
	
	pop lcd_data
	pop delay_input_high
	pop delay_input_low
	pop temp
	out sreg, temp
	pop temp

	ret

/******************************************************************************/

; Funtion to delay a certain time in microseconds
; @Param delay_input_high:delay_input_low The time in microseconds to delay
; An exact timing is not garunteed. The function will delay at minumum the given time

delay:
	push temp
	in temp, sreg
	push temp
	push delay_input_low
	push delay_input_high

check_loop:
	tst delay_input_low
	breq test_delay_input_high
	dec delay_input_low
	nop
	nop
	nop
	nop
	rjmp check_loop
 
test_delay_input_high:
	tst delay_input_high; if r18 = 0 and r19=0
	breq return

	dec delay_input_high;else, decrement r19 and set r18
	ser delay_input_low
	nop
	nop
	rjmp check_loop

return:
	pop delay_input_high
	pop delay_input_low
	pop temp
	out sreg, temp
	pop temp
	ret 

/*********************************************************************************************/

; This is the main logic of the game loop

timer0:

	push temp
	in temp, sreg
	push temp

	; This should only occur while the game is running
	inc tick_count

	cp tick_count, ticks_per_step
	brlo timer0_ret

	; A whole step has elapsed. Clear the tick count
	clr tick_count

	inc score_low
	call game_render

timer0_ret:

	pop temp
	out sreg, temp
	pop temp

	reti

/***********************************************************************************************/

game_render:

	push temp
	in temp, sreg
	push temp
	push lcd_data

	; Clear the board
	ldi lcd_data, LCD_DISP_CLR
	call lcd_wait_busy
	call lcd_write_com

	; Draw the game board, eventually

	; Change lines
	ldi lcd_data, LCD_ADDR_SET | LCD_LINE2
	call lcd_wait_busy
	call lcd_write_com

	; Draw the Score
	mov print_8_bit_input, score_low
	call print_8_bit

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi print_16_bit_input_high, high(23456)
	ldi print_16_bit_input_low, low(23456)
	call print_16_bit
	
	pop lcd_data
	pop temp
	out sreg, temp
	pop temp

	ret

/***********************************************************************************************/

print_16_bit:

.def print_16_bit_input_high = r25
.def print_16_bit_input_low = r24
.def lcd_data = r23
.def result = r22

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push result
	push temp
	push temp2
	clr result

print_16_get_ten_thousands:
	; Check ten thousands
	ldi temp, low(10000)
	ldi temp2, high(10000)
	cp print_16_bit_input_high, temp2
	brlo print_16_print_ten_thousands; First byte is lower, there's no ten thousands
	cp print_16_bit_input_high, temp2
	brne print_16_sub_ten_thousands; It's not lower and not even, therefore there's a ten thousand present
	cp print_16_bit_input_low, temp
	brlo print_16_print_ten_thousands; High byte even, low byte lower, no ten thousands
	rjmp print_16_sub_ten_thousands; Otheriwse, there's at least one ten thousand. Subtract it.
	
print_16_sub_ten_thousands:

	sub print_16_bit_input_low, temp
	sbc print_16_bit_input_high, temp2
	inc result
	rjmp print_16_get_ten_thousands

print_16_print_ten_thousands:

	ldi lcd_data, '0'
	add lcd_data, result
	call lcd_wait_busy
	call lcd_write_data
	clr result

print_16_get_thousands:
	; Check thousands
	ldi temp, low(1000)
	ldi temp2, high(1000)
	cp print_16_bit_input_high, temp2
	brlo print_16_print_thousands; First byte is lower, there's no thousands
	cp print_16_bit_input_high, temp2
	brne print_16_sub_thousands; It's not lower and not even, therefore there's a thousand present
	cp print_16_bit_input_low, temp
	brlo print_16_print_thousands; High byte even, low byte lower, no ten thousands
	rjmp print_16_sub_thousands; Otheriwse, there's at least one thousand. Subtract it.
	
print_16_sub_thousands:

	sub print_16_bit_input_low, temp
	sbc print_16_bit_input_high, temp2
	inc result
	rjmp print_16_get_thousands

print_16_print_thousands:

	ldi lcd_data, '0'
	add lcd_data, result
	call lcd_wait_busy
	call lcd_write_data
	clr result

print_16_get_hundreds:
	; Check hundreds
	ldi temp, low(100)
	ldi temp2, high(100)
	cp print_16_bit_input_high, temp2
	brlo print_16_print_hundreds; First byte is lower, there's no hundred
	cp print_16_bit_input_high, temp2
	brne print_16_sub_hundreds; It's not lower and not even, therefore there's a hundred present
	cp print_16_bit_input_low, temp
	brlo print_16_print_hundreds; High byte even, low byte lower, no ten hundred
	rjmp print_16_sub_hundreds; Otheriwse, there's at least one hundred. Subtract it.
	
print_16_sub_hundreds:

	sub print_16_bit_input_low, temp
	sbc print_16_bit_input_high, temp2
	inc result
	rjmp print_16_get_hundreds

print_16_print_hundreds:

	ldi lcd_data, '0'
	add lcd_data, result
	call lcd_wait_busy
	call lcd_write_data
	clr result

; We're down to tens. These all fit in the one register
print_16_get_tens:
	cpi print_16_bit_input_low, 10
	brlo print_16_print_tens
	inc result
	subi print_16_bit_input_low, 10
	rjmp print_16_get_tens

print_16_print_tens:
	call lcd_wait_busy
	ldi lcd_data, '0'
	add lcd_data, result
	call lcd_write_data

print_16_get_ones:
	mov result, print_16_bit_input_low; Only ones are left...

print_16_print_ones:
	call lcd_wait_busy
	ldi lcd_data, '0'
	add lcd_data, result
	call lcd_write_data
	clr lcd_data

	pop temp2
	pop temp
	pop result
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret

/***********************************************************************************************/

print_8_bit:

.def print_8_bit_input = r25
.def result = r24; < Completely local, safe to use again

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push print_8_bit_input
	push result
	clr lcd_data

get_hundreds:
	cpi print_8_bit_input, 100
	brlo print_hundreds
	inc lcd_data
	subi print_8_bit_input, 100
	rjmp get_hundreds

print_hundreds:
	call lcd_wait_busy
	ldi result, 0b00110000 ;0 char on lcd
	add lcd_data, result
	call lcd_write_data
	clr lcd_data

get_tens:
	cpi print_8_bit_input, 10
	brlo print_tens
	inc lcd_data
	subi print_8_bit_input, 10
	rjmp get_tens

print_tens:
	call lcd_wait_busy
	ldi result, 0b00110000 ;0 char on lcd
	add lcd_data, result
	call lcd_write_data

get_ones:
	mov lcd_data, print_8_bit_input; Only ones are left...

print_ones:
	call lcd_wait_busy
	ldi result, 0b00110000 ;0 char on lcd
	add lcd_data, result
	call lcd_write_data
	clr lcd_data

lcd_print_reg_end:
	pop result
	pop print_8_bit_input
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret

/***********************************************************************************************/


/***********************************************************************************************/


