; dirt.asm
;
; Dirt
;
; A game by
; Matthew Moss and Tony Ward
; mdm@cse.unsw.edu.au
;
; Includes sample code by
; Jorgen Peddersen

.include "m64def.inc"

; Shared
.def score_high = r2
.def score_low = r3
.def current_level = r4
.def player_lives = r5
.def temp = r16
.def temp2 = r17
.def lcd_data = r23
.def fire_block = r8
.def dm_fire_block = r10
.def button_press_found = r13
.def button_pressed_flag = r14
.def ready_to_start = r15
.def cheats_detected = r15
.def game_state = r18
.equ GAME_PLAYING = 1
.equ LEVEL_SCREEN = 2
.equ TITLE_SCREEN = 3
.equ WIN_SCREEN = 4
.equ GAME_FINISHED = 5

; Game
.def tick_count = r6
.def next_player_weapon = r7
.def chance_dm_firing = r9
.def dm_shots_left = r11
.def ticks_per_step = r19
.def finished = r12; A reverse flag. 0 == true, we're finished

.def row =r20
.def col =r21; Keypad location registers - the lazy man's choice
.def mask =r24

; Title

; Constants
.equ BOARD_SIZE = 14
.equ TICKS_PER_SECOND = 225 ;(7.3728 * 10^6) / (128 * 256) = 225 
.equ TENTH_OF_SECOND = 22; We'll err on the side of kindness

.equ RAND_A = 214013; RNG constants	
.equ RAND_C = 2531011

.equ PORTDDIR = 0xF0
.equ INITCOLMASK = 0xEF ; Keypad constants
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

.equ DEATH_MOON_WEAPON_SCALE = 26; Used for determining the next DM weapon. 10 * X must be greater than 255 or unexpected characters will occur
.equ DM_SHOTS_PER_LEVEL = 15
.equ DM_MAX_PROB_FIRING = 192

.dseg
	game_board: .byte BOARD_SIZE
	.byte 16; Just in case there's issues with accidental buffer overflows
	RAND: .byte 4

.cseg
	; Set up interrupt vectors
	jmp reset
	jmp start_level ; IRQ0 Handler
	jmp level_skip ; IRQ1 Handler
	jmp reset ; IRQ2 Handler
	jmp reset ; IRQ3 Handler
	jmp reset ; IRQ4 Handler
	jmp reset ; IRQ5 Handler
	jmp reset ; IRQ6 Handler
	jmp reset ; IRQ7 Handler
	jmp reset ; Timer2 Compare Handler
	jmp timer2 ; Timer2 Overflow Handler
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

	clr temp
	out EIMSK, temp                       ; disable all interrupts

	clr score_low
	clr score_high
	clr current_level
	inc current_level; Starting level is level 1
	ldi temp, 3
	mov player_lives, temp; Player has three lives, to start
	ldi temp, 1 << CS10 ;Start timer1, used for random generation
	out TCCR1B, temp
	call lcd_init
	ldi temp, (2 << ISC10) | (2 << ISC00) ;setting the interrupts for falling edge
	sts EICRA, temp                       ;storing them into EICRA 


refresh_game:
	clr ready_to_start
	clr finished
	clr tick_count

	; Show the title screen
	rjmp show_title_screen

/******************************************************************************/

show_title_screen:

	ldi temp, (1<<INT0)
	out EIMSK, temp; Enable interrput 0
	sei

	clr ready_to_start; Flag used to indicate game readiness

	call draw_title_screen

wait_title_screen:

	tst ready_to_start
	breq wait_title_screen

	ldi temp, (0<<INT0)
	out EIMSK, temp; Disable interrput 0. This allows the level start screen to delay, if needed
	sei

	rjmp show_level_screen


/******************************************************************************/

draw_title_screen:

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push print_8_bit_input

	; Clear the board
	ldi lcd_data, LCD_DISP_CLR
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data


	ldi lcd_data, 'S'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'p'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'a'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'c'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'B'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'r'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'a'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'w'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'l'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 's'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, '!'
	call lcd_wait_busy
	call lcd_write_data


	; Change lines
	ldi lcd_data, LCD_ADDR_SET | LCD_LINE2
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, 'I'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'n'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 's'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'r'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 't'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'c'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'o'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'i'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'n'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, '.'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, '.'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, '.'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, '.'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, '.'
	call lcd_wait_busy
	call lcd_write_data

	pop print_8_bit_input
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret


/******************************************************************************/

show_level_screen:

	; Show the level screen

	ldi game_state, LEVEL_SCREEN

	call draw_level_screen

	ldi delay_input_high, 255
	call delay

	call delay; Debouncing from the title screen. We want to show the screen off

	ldi temp, (1<<INT0)
	out EIMSK, temp                       ; enabling interrput0
	sei

	clr ready_to_start

run_game:
	tst ready_to_start
	breq run_game
	clr ready_to_start
	jmp game_start

/******************************************************************************/

draw_level_screen:

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push print_8_bit_input
	push delay_input_high
	push delay_input_low

	; Clear the board
	ldi lcd_data, LCD_DISP_CLR
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'L'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'v'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'l'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	mov print_8_bit_input, current_level
	call print_8_bit


	; Change lines
	ldi lcd_data, LCD_ADDR_SET | LCD_LINE2
	call lcd_wait_busy
	call lcd_write_com

	; Draw the Score
	mov print_8_bit_input, player_lives
	call print_8_bit

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	mov print_16_bit_input_high, score_high
	mov print_16_bit_input_low, score_low
	call print_16_bit

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	mov print_8_bit_input, current_level
	call print_8_bit

	ldi delay_input_high, 255
	call delay
	call delay

	pop delay_input_low
	pop delay_input_high
	pop print_8_bit_input
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret

/******************************************************************************/

start_level:

	push temp
	in temp, sreg
	push temp

	clr ready_to_start
	inc ready_to_start

	pop temp
	out sreg, temp
	pop temp

	reti

/******************************************************************************/

game_start:
	push temp
	in temp, sreg
	push temp
	push ticks_per_step
	push tick_count
	push finished
	push ZH
	push ZL

	ldi GAME_STATE, GAME_PLAYING

	ldi temp, (1<<INT1); Enable only interrupt 1
	out EIMSK, temp     

	; Reset the game board
	clr temp
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
	ldi temp2, ' '
clear_board:	
	st Z+, temp2
	inc temp
	cpi temp, BOARD_SIZE
	brne clear_board

	ldi temp, 0b00000101; Prescalar 128
	out TCCR0, temp
	ldi temp, 0b00000001; Timer0 overflow interrupt on
	out TIMSK, temp

	;Load the correct steps for the level
	push current_level

	ldi temp, TICKS_PER_SECOND
	ldi ticks_per_step, TICKS_PER_SECOND; First level has 1 second per step
	clr temp2

calculate_step_timing:
	dec current_level
	tst current_level
	breq step_load_finish

	cpi temp2, 5; The first four times, we'll go for reducing by 10%
	brge halve_current_speed
	inc temp2
	subi ticks_per_step, TENTH_OF_SECOND
	rjmp calculate_step_timing

halve_current_speed:

	; We need to halve the current ticks per second. Shift right
	lsr ticks_per_step
	rjmp calculate_step_timing

step_load_finish:

	pop current_level

	; Load the correct chance of the DM firing for the level
	clr chance_dm_firing; Start with a zero probability
	ldi temp, 32; 255 / 8. Chance of first level firing
	clr temp2
	push current_level

calculate_fire_probability:

	tst current_level
	breq calculate_fire_probability_finish

	ldi temp2, DM_MAX_PROB_FIRING
	cp chance_dm_firing, temp2
	breq calculate_fire_probability_finish

	add chance_dm_firing, temp
	dec current_level
	rjmp calculate_fire_probability

calculate_fire_probability_finish:
	pop current_level

	; Load the correct number of DM shots
	ldi temp, DM_SHOTS_PER_LEVEL
	mov dm_shots_left, temp

	; Start interrupts
	sei

	; Render the game board once to start with
	call game_render

	; Set the player's first shot to an illegal value ie. undecided
	clr next_player_weapon
	dec next_player_weapon; underflow to 255

	; Clear the fire block. Player can fire
	clr fire_block
	; So can the Death Moon
	clr dm_fire_block

	clr cheats_detected; There's no cheating, yet

	; Enable portC, for the keypad
	ldi temp, PORTDDIR
	out DDRA, temp

	call initrandom; Seed the RNG from timer1

	clr finished
	dec finished; Underflow finished. It's a reverse flag

	clr button_press_found; Reset the keypad debouncing
	clr button_pressed_flag

game_loop:
	ldi mask, INITCOLMASK ; initial column mask
	clr col ; initial column

is_button_held:
	tst button_press_found
	brne colloop
	clr button_pressed_flag

colloop:
	out PORTA, mask ; set column to mask value
	; (sets column 0 off)
	ldi temp, 0xFF ; implement a delay so the
	; hardware can stabilize

key_delay:
	dec temp
	brne key_delay
	in temp, PINA ; read PORTD
	andi temp, ROWMASK ; read only the row bits
	cpi temp, 0xF ; check if any rows are grounded
	breq nextcol ; if not go to the next column
	ldi mask, INITROWMASK ; initialise row check
	clr row ; initial row
	
rowloop:
	mov temp2, temp
	and temp2, mask ; check masked bit
	brne skipconv ; if the result is non-zero,
	; we need to look again
	rcall convert ; if bit is clear, convert the bitcode
	jmp game_loop ; and start again

skipconv:
	inc row ; else move to the next row
	lsl mask ; shift the mask to the next bit
	jmp rowloop

nextcol:
	cpi col, 3 ; check if we’re on the last column
	breq no_button_pressed ; if so, no buttons were pushed,
	; so start again.

	sec ; else shift the column mask:
	; We must set the carry bit
	rol mask ; and then rotate left by a bit,
	; shifting the carry into
	; bit zero. We need this to make
	; sure all the rows have
	; pull-up resistors
	inc col ; increment column value
	jmp colloop ; and check the next column
	; convert function converts the row and column given to a
	; binary number and also outputs the value to PORTC.
	; Inputs come from registers row and col and output is in
	; temp.

no_button_pressed:
	clr button_press_found
	tst finished
	breq game_end
	tst player_lives
	breq game_end
	rjmp game_loop

game_end:
	
	; Disable timer2, we don't need it any more
	ldi temp, 0b00000000; Timer0 overflow interrupt off
	out TIMSK, temp

	tst cheats_detected
	brne game_end_finish; Cheating is discouraged

	; Check the player lives, and if they're not dead, increase the score
	tst player_lives
	breq no_more_lives
	ldi temp, 100
	mul current_level, temp
	add score_low, r0
	adc score_high, r1; Done

game_end_finish:

	call game_render
	inc current_level
	ldi temp, 3
	cp player_lives, temp
	breq game_end_win_screen
	inc player_lives

game_end_win_screen:

	tst cheats_detected
	brne game_end_return; Cheated? No win screen. Tough luck

	call show_win_screen

game_end_return:

	pop ZL
	pop ZH
	pop finished
	pop tick_count
	pop ticks_per_step
	pop temp
	out sreg, temp
	pop temp

	jmp show_level_screen

no_more_lives:
	jmp game_over

/******************************************************************************/
; Cheat Method.

level_skip:

	clr cheats_detected
	inc cheats_detected

	clr dm_shots_left; There's no shots left to fire

	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
	ldi temp2, ' '
	clr temp	
	
clear_next:
	st Z+, temp2
	inc temp
	cpi temp, 14
	brne clear_next

	inc fire_block
	
	ldi ticks_per_step, 1; Force a timer interrupt

cheat_finish:

	reti


/******************************************************************************/

convert:
	ldi temp2, 0xFF
	mov button_press_found, temp2
	tst button_pressed_flag
	brne early_convert_end
	inc button_pressed_flag
	cpi col, 3 ; if column is 3 we have a letter
	breq letters
	cpi row, 3 ; if row is 3 we have a symbol or 0
	breq symbols
	mov temp, row ; otherwise we have a number (1-9)
	lsl temp ; temp = row * 2
	add temp, row ; temp = row * 3
	add temp, col ; add the column address
	; to get the offset from 1
	inc temp ; add 1. Value of switch is
	; row*3 + col + 1.
	jmp convert_end

early_convert_end:
	ret

letters:
	ldi temp, 0xA
	add temp, row ; increment from 0xA by the row value
	jmp convert_end

symbols:
	cpi col, 0 ; check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp, 0xF ; we'll output 0xF for hash
	jmp convert_end

star:
	ldi temp, 0xE ; we'll output 0xE for star
	jmp convert_end

zero:
	clr temp ; set to zero

convert_end:
	; Our pressed number is in temp
	cpi temp, 9 + 1
	brge convert_finish; It wasn't a number, skip it
	; Otherwise, it's legal
	mov next_player_weapon, temp

convert_finish:
	ret

/******************************************************************************/

; Once we hit this point, the game is finished
; The previous contents of all registers, other than score, can be ignored
; We're just going to jump to reset, so maintaining things doesn't matter

.def game_over_is_finished = r17
.def game_over_time = r23

game_over:

	ldi game_state, GAME_FINISHED
	call draw_game_over_screen

	ldi temp, 0b00000101;
	out TCCR2, temp; Set timer2 to 1024 prescalar, for timekeeping

	ldi temp, 0b01000000
	out TIMSK, temp; Enable timer2 overflow interrupts

	ldi temp, 0b01101001
	out TCCR0, temp; Turn on timer0, fastPWM, clear on comparison

	ldi temp, 230
	out OCR0, temp; 230 is about 70rpm

	ldi temp, 0b00010000
	out DDRB, temp; Make the 4th pin of B an output

	clr game_over_time
	clr game_over_is_finished

game_over_wait:
	tst game_over_is_finished
	breq game_over_wait

	ldi temp, 0b00000000;
	out TCCR2, temp; We're done with timer2

	ldi temp, 0b00000000
	out TCCR0, temp; We're also done with timer0

	jmp reset

/******************************************************************************/

; Timer2's overflow interrupt is only ever used for end of game timekeeping

timer2:
	
	push temp
	in temp, sreg
	push temp

	;Just in case
	cpi game_state, GAME_FINISHED
	brne timer2_end

	inc game_over_time
	cpi game_over_time, 84; Three seconds
	brne timer2_end
	ser game_over_is_finished

timer2_end:
	pop temp
	out sreg, temp
	pop temp

	reti


/******************************************************************************/
draw_game_over_screen:

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push print_8_bit_input

	; Clear the board
	ldi lcd_data, LCD_DISP_CLR
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'G'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'a'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'm'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'O'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'v'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'r'
	call lcd_wait_busy
	call lcd_write_data

	; Change lines
	ldi lcd_data, LCD_ADDR_SET | LCD_LINE2
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'S'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'c'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'o'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'r'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ':'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	mov print_16_bit_input_high, score_high
	mov print_16_bit_input_low, score_low
	call print_16_bit

	; Two extra spaces to hide the cursor
	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	pop print_8_bit_input
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret


/******************************************************************************/

; Show the level complete screen and play a sound

.def win_screen_is_finished = r17
.def win_screen_time = r19

show_win_screen:

	push temp
	in temp, sreg
	push temp
	push win_screen_is_finished
	push win_screen_time

	ldi game_state, WIN_SCREEN

	ldi temp, 0b10000000
	out DDRB, temp ; PORT B PIN 7 is an output

	; Enable Timer0
	ldi temp, 0b00000111; Prescalar: 1024
	out TCCR0, temp

	ldi temp, 0b00000001; Timer0 overflow interrupt on
	out TIMSK, temp

	ldi temp, (1 << WGM21) | (1 << COM20) | (3 << CS20); CTC mode, toggle OC2, prescalar = 64 
	out TCCR2, temp 

	ldi temp, 255; Lowest tone possible. Might save my housemates murdering me.
	out OCR2, temp

	; We should be good to go for sound

	clr win_screen_is_finished
	clr win_screen_time

	call draw_win_screen

show_win_screen_wait:
	tst win_screen_is_finished
	breq show_win_screen_wait; We're not done yet


show_win_screen_end:

	clr temp
	out TCCR0, temp

	clr temp; Disable timer2, we're done with it
	out TCCR2, temp

	out PORTB, temp; Force the tone to stop

	in temp, TIMSK
	andi temp, (0 << TOIE0); Turn off timer0 overflow
	out TIMSK, temp

	pop win_screen_time
	pop win_screen_is_finished
	pop temp
	out sreg, temp
	pop temp

	ret

/******************************************************************************/

draw_win_screen:

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push print_8_bit_input
	
	; Clear the board
	ldi lcd_data, LCD_DISP_CLR
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, 'L'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'v'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'l'
	call lcd_wait_busy
	call lcd_write_data

	; Change lines
	ldi lcd_data, LCD_ADDR_SET | LCD_LINE2
	call lcd_wait_busy
	call lcd_write_com

	ldi lcd_data, 'C'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'o'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'm'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'p'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'l'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 't'
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, 'e'
	call lcd_wait_busy
	call lcd_write_data

	pop print_8_bit_input
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret

/******************************************************************************/

win_screen_timer_0:

	push temp
	in temp, sreg
	push temp

	ser temp
	out portb, temp

	inc win_screen_time

	cpi win_screen_time, 7
	breq win_screen_raise_tone
	cpi win_screen_time, 14
	breq win_screen_raise_tone
	cpi win_screen_time, 21
	breq win_screen_raise_tone

	cpi win_screen_time, 45
	brne win_screen_timer_0_end
	ser win_screen_is_finished

win_screen_raise_tone:

	in temp, OCR2
	subi temp, 15
	out OCR2, temp

win_screen_timer_0_end:

	pop temp
	out sreg, temp
	pop temp

	ret

/******************************************************************************/

/******************************************************************************/

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
/******************************************************************************/


/******************************************************************************/

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

	cpi game_state, WIN_SCREEN
	breq timer0_win_screen

	cpi game_state, GAME_PLAYING
	breq timer0_game_playing

	rjmp timer0_ret

timer0_win_screen:

	call win_screen_timer_0
	rjmp timer0_ret


timer0_game_playing:

	; This should only occur while the game is running
	inc tick_count

	cp tick_count, ticks_per_step
	brlo timer0_ret

	; A whole step has elapsed. Clear the tick count
	clr tick_count

	call board_update
	call game_render

	rjmp timer0_ret

timer0_ret:

	pop temp
	out sreg, temp
	pop temp

	reti

/***********************************************************************************************/

board_update_early_return:

	pop temp
	out sreg, temp
	pop temp

	ret

board_update:

	push temp
	in temp, sreg
	push temp

	cpi game_state, GAME_PLAYING
	brne board_update_early_return

	push temp2
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push ZH
	push ZL

	;Ok, here we go. This is the important bit
	
	; First, we're clearing all explosions
	clr temp
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)

get_next_explosion:
	ld temp2, Z
	cpi temp2, '*'
	brne increase_explosion_search_pos
	ldi temp2, ' '
	st Z, temp2

increase_explosion_search_pos:
	adiw Z, 1
	inc temp
	cpi temp, BOARD_SIZE
	brne get_next_explosion

	; If the player has something on the rightmost space, it should be cleared
clear_rightmost_space:
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
	adiw Z, BOARD_SIZE-1
	ld temp, Z
	cpi temp, '9'+1
	brge check_leftmost_space
	cpi temp, '0'
	brlo check_leftmost_space
	; There's a player number there, and it has no effect. Clear it
	ldi temp, ' '
	st Z, temp

	; We're looking for an impact with the planet
check_leftmost_space:
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
	ld temp, Z
	cpi temp, '9'+11
	brge check_player_weapons
	cpi temp, '0'+10
	brlo check_player_weapons
	; There's an enemy weapon there. Clear it and decrement lives
	ldi temp, ' '
	st Z, temp
	dec player_lives

check_player_weapons:
	; Next, we're going to check if player weapons are hitting an enemy weapon
	clr temp
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
	
check_player_weapons_loop:
	cpi temp, BOARD_SIZE - 1; We don't need to check the 14th space, there's nothing next to it, and it's already been cleared
	breq shift_player_weapons
	push temp; We need the extra temp space
	ld temp2, Z; Check what's at the space we're looking at
	cpi temp2, '0'
	brlo move_to_next_player_weapon; Not a player weapon, skip
	cpi temp2, '9'+1
	brsh move_to_next_player_weapon; Not a player weapon, also skip
	; We found a weapon, yay
	; Check the space next to it
	adiw Z, 1
	ld temp, Z; temp is now the space to the right
	sbiw Z, 1; Restore Z, just in case
	cpi temp, ' '; If it's a space, skip it
	breq move_to_next_player_weapon
	cpi temp, '*'; If it's an explosion, ignore it
	breq move_to_next_player_weapon
	cpi temp, '9' + 1
	brlo move_to_next_player_weapon; If it's a player weapon, ignore it
	; It's not empty, it's not an explosion. It's an enemy weapon
	; Check if they have the same value
	subi temp, 10; Remove ten, to see if they're the same
	cp temp, temp2;
	breq player_weapon_matches
	; There was a weapon, but it didn't match. Start the penalty, etc etc.
	ldi temp, ' '
	st Z, temp
	ldi temp, 2
	mov fire_block, temp
	ldi temp, 10; Decrease the score by current level * 10
	mul temp, current_level
	sub score_low, r0
	sbc score_high, r1; Score calculated and added
	; Check the score isn't less than 0 (it hasn't underflowed)
	mov temp, score_high
	cpi temp, 0xFF
	brne move_to_next_player_weapon
	clr score_low
	clr score_high
	rjmp move_to_next_player_weapon

player_weapon_matches:

	ldi temp, '*'
	adiw Z, 1
	st Z, temp
	sbiw Z, 1
	ldi temp, ' '
	st Z, temp; Overwrite the enemy weapon. Success, yay.
	ldi temp, 10; Increase the score by current level * 10
	mul temp, current_level
	add score_low, r0
	adc score_high, r1; Score calculated and added

move_to_next_player_weapon:
	pop temp
	adiw Z, 1
	inc temp
	rjmp check_player_weapons_loop

shift_player_weapons:
	clr temp
	ldi ZH, high(game_board + BOARD_SIZE - 1)
	ldi ZL, low(game_board + BOARD_SIZE - 1); We're looking backwards

shift_player_weapons_loop:
	cpi temp, BOARD_SIZE
	breq check_enemy_weapons
	inc temp

	sbiw Z, 1; Check the next space over
	ld temp2, Z
	cpi temp2, '9'+1
	brge shift_player_weapons_loop; It's not a player weapon
	cpi temp2, '0'
	brlo shift_player_weapons_loop; It's not a player weapon
	; It's a player weapon. Move it up
	adiw Z, 1
	st Z, temp2
	sbiw Z, 1
	ldi temp2, ' '
	st Z, temp2; We've shifted it, and replaced it with a space
	
	rjmp shift_player_weapons_loop

check_enemy_weapons:
	; And now we get to do it all again
	; The player weapons have all moved up, so we'd better check again
	clr temp
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)

check_enemy_weapons_loop:
	cpi temp, BOARD_SIZE
	breq shift_enemy_weapons
	push temp

	ld temp2, Z; Check what's at the space we're looking at
	cpi temp2, '0' + 10
	brlo move_to_next_enemy_weapon; Not an enemy weapon, skip
	cpi temp2, '9'+11
	brsh move_to_next_enemy_weapon; Not an enemy weapon, also skip
	; It's a weapon. Check the space before it
	sbiw Z, 1
	ld temp, Z
	adiw Z, 1
	; If it's a player weapon of the same value, we replace with an explosion	
	subi temp2, 10
	cp temp, temp2
	breq enemy_weapon_matches
	cpi temp, ' '; It's a space, ignore it
	breq move_to_next_enemy_weapon
	; The enemy weapon and player weapon don't match
	; Clear the player weapon, the enemy weapon will move up later. Apply the penalty
	ldi temp, ' '
	sbiw Z, 1
	st Z, temp
	adiw Z, 1
	ldi temp, 2
	mov fire_block, temp
	ldi temp, 10; Decrease the score by current level * 10
	mul temp, current_level
	sub score_low, r0
	sbc score_high, r1; Score calculated and added
	; Check the score isn't less than 0 (it hasn't underflowed)
	mov temp, score_high
	cpi temp, 0xFF
	brne move_to_next_enemy_weapon
	clr score_low
	clr score_high
	rjmp move_to_next_enemy_weapon

enemy_weapon_matches:
	ldi temp, '*'
	sbiw Z, 1
	st Z, temp
	adiw Z, 1
	ldi temp, ' '
	st Z, temp 
	ldi temp, 10; Increase the score by current level * 10
	mul temp, current_level
	add score_low, r0
	adc score_high, r1; Score calculated and added

move_to_next_enemy_weapon:
	pop temp
 	adiw Z, 1
	inc temp
	rjmp check_enemy_weapons_loop

shift_enemy_weapons:
	clr temp
	ldi ZH, high(game_board)
	ldi ZL, low(game_board); We're looking backwards

shift_enemy_weapons_loop:
	cpi temp, BOARD_SIZE
	breq add_new_weapons
	inc temp

	adiw Z, 1; Check the next space over
	ld temp2, Z
	cpi temp2, '9'+11
	brge shift_enemy_weapons_loop; It's not an enemy weapon
	cpi temp2, '0' + 10
	brlo shift_enemy_weapons_loop; It's not an enemy weapon
	; It's an enemy weapon. Move it up
	sbiw Z, 1
	st Z, temp2
	adiw Z, 1
	ldi temp2, ' '
	st Z, temp2; We've shifted it, and replaced it with a space
	
	rjmp shift_enemy_weapons_loop

add_new_weapons:
	; Check if the player's next weapon is legal

	tst fire_block
	brne dec_fire_block

	; Otherwise, add it
	mov temp, next_player_weapon
	cpi temp, 9 + 1
	brsh add_death_moon_weapon; No weapon this time...
	
	clr next_player_weapon
	dec next_player_weapon; Underflow back to an illegal value
	ldi temp2, '0'
	add temp, temp2; Add the char zero for outputting
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
	st Z, temp; The player's next shot is added to the board
	rjmp add_death_moon_weapon

dec_fire_block:
	dec fire_block


add_death_moon_weapon:

	tst dm_shots_left
	breq end_board_update; We're not firing again

	tst dm_fire_block
	brne dec_dm_fire_block; Can't fire if it's blocked

	call getRandom
	cp temp, chance_dm_firing; Expressed as a possibility x/255
	brsh end_board_update; If we've got a number greater, skip it

	; Otherwise, add a new death moon weapon
	; Random value is between 0-255
	call getRandom
	; We need a value between 0-9

	clr temp2
get_dm_weapon_value:

	cpi temp, DEATH_MOON_WEAPON_SCALE; While the value is greater than 25
	brlo place_dm_next_weapon
	subi temp, DEATH_MOON_WEAPON_SCALE; Subtract 25 and increase the new weapon value
	inc temp2
	rjmp get_dm_weapon_value

place_dm_next_weapon:

	ldi temp, 10 + '0'; Add the offset for a death moon weapon
	add temp, temp2; Add the new weapon value
	ldi ZH, high(game_board + BOARD_SIZE - 1)
	ldi ZL, low(game_board+ BOARD_SIZE - 1)
	st Z, temp; Put the new weapon on the board
	inc dm_fire_block
	dec dm_shots_left
	rjmp end_board_update

dec_dm_fire_block:
	dec dm_fire_block

end_board_update:

	; Last thing we have to do? Check if the game is finished
	clr temp
	clr finished; Assume we're done, for the sake of argument
	add finished, dm_shots_left; If the DM isn't finished, neither are we
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)

check_next_pos:
	cpi temp, BOARD_SIZE
	brsh board_update_finish
	inc temp
	ld temp2, Z+
	cpi temp2, ' '; If there's nothing there
	breq check_next_pos
	inc finished; Otherwise, we're not done

board_update_finish:

	pop ZL
	pop ZH
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	pop temp2
	pop temp
	out sreg, temp
	pop temp

	ret

/***********************************************************************************************/
game_render:

	push temp
	in temp, sreg
	push temp
	push lcd_data
	push print_16_bit_input_high
	push print_16_bit_input_low
	push ZH
	push ZL

	; Clear the board
	ldi lcd_data, LCD_DISP_CLR
	call lcd_wait_busy
	call lcd_write_com

	; Draw the game board.

	; Top left is the planet
	ldi lcd_data, 'D'
	call lcd_wait_busy
	call lcd_write_data

	; Draw the 14 char Game Board
	clr temp
	ldi ZH, high(game_board)
	ldi ZL, low(game_board)
draw_board:	
	ld print_game_char_input, Z+
	call print_game_char
	inc temp
	cpi temp, BOARD_SIZE
	brne draw_board

	; Top right is the Death Moon
	ldi lcd_data, 'M'
	call lcd_wait_busy
	call lcd_write_data

	; Change lines
	ldi lcd_data, LCD_ADDR_SET | LCD_LINE2
	call lcd_wait_busy
	call lcd_write_com

	; Draw the Score
	mov print_8_bit_input, player_lives
	call print_8_bit

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	mov print_16_bit_input_high, score_high
	mov print_16_bit_input_low, score_low
	call print_16_bit

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	ldi lcd_data, ' '
	call lcd_wait_busy
	call lcd_write_data

	mov print_8_bit_input, current_level
	call print_8_bit
	
	pop ZL
	pop ZH
	pop print_16_bit_input_low
	pop print_16_bit_input_high
	pop lcd_data
	pop temp
	out sreg, temp
	pop temp

	ret

/***********************************************************************************************/

; Prints a 16 bit number.
; Params: r24:r25 = number to print

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

; Prints an 8 bit number.
; Params: r25 = number to print

print_8_bit:

.def print_8_bit_input = r25
.def result = r22; < Completely local, safe to use again

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

; Prints a game char
; Params: r25 = char to print

print_game_char:

.def print_game_char_input = r25

	push lcd_data
	in lcd_data, sreg
	push lcd_data
	push temp

	; Is it a number straight out?
	mov temp, print_game_char_input
	cpi temp, ' '
	breq print_from_temp
	cpi temp, '*'
	breq print_from_temp
	cpi temp, '9'+1
	brlo print_from_temp
	ldi lcd_data, 10; It's not a legal char, therefore reduce by ten.
	sub temp, lcd_data

print_from_temp:
	mov lcd_data, temp
	call lcd_wait_busy
	call lcd_write_data

	pop temp
	pop lcd_data
	out sreg, lcd_data
	pop lcd_data

	ret


/***********************************************************************************************/

; Sample Random Number Generator code
; Author: Jorgen Peddersen
; Modified by: Matthew Moss
; Returns a random number in r16

InitRandom:
push r16 ; save conflict register
in r16, TCNT1L ; Create random seed from time of timer 1
sts RAND,r16
sts RAND+2,r16
in r16,TCNT1H
sts RAND+1, r16
sts RAND+3, r16
pop r16 ; restore conflict register
ret

GetRandom:
push r0 ; save conflict registers
push r1
push r17
push r18
push r19
push r20
push r21
push r22

clr r22 ; remains zero throughout

ldi r16, low(RAND_C) ; set original value to be equal to C
ldi r17, BYTE2(RAND_C)
ldi r18, BYTE3(RAND_C)
ldi r19, BYTE4(RAND_C)

; calculate A*X + C where X is previous random number.  A is 3 bytes.
lds r20, RAND
ldi r21, low(RAND_A)
mul r20, r21 ; low byte of X * low byte of A
add r16, r0
adc r17, r1
adc r18, r22

ldi r21, byte2(RAND_A)
mul r20, r21  ; low byte of X * middle byte of A
add r17, r0
adc r18, r1
adc r19, r22

ldi r21, byte3(RAND_A)
mul r20, r21  ; low byte of X * high byte of A
add r18, r0
adc r19, r1

lds r20, RAND+1
ldi r21, low(RAND_A)
mul r20, r21  ; byte 2 of X * low byte of A
add r17, r0
adc r18, r1
adc r19, r22

ldi r21, byte2(RAND_A)
mul r20, r21  ; byte 2 of X * middle byte of A
add r18, r0
adc r19, r1

ldi r21, byte3(RAND_A)
mul r20, r21  ; byte 2 of X * high byte of A
add r19, r0

lds r20, RAND+2
ldi r21, low(RAND_A)
mul r20, r21  ; byte 3 of X * low byte of A
add r18, r0
adc r19, r1

ldi r21, byte2(RAND_A)
mul r20, r21  ; byte 2 of X * middle byte of A
add r19, r0

lds r20, RAND+3
ldi r21, low(RAND_A)	
mul r20, r21  ; byte 3 of X * low byte of A
add r19, r0

sts RAND, r16 ; store random number
sts RAND+1, r17
sts RAND+2, r18
sts RAND+3, r19

mov r16, r19  ; prepare result (bits 30-23 of random number X)
lsl r18
rol r16

pop r22 ; restore conflict registers
pop r21 
pop r20
pop r19
pop r18
pop r17
pop r1
pop r0
ret

