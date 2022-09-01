.setcpu "65c02"

.SEGMENT "STARTUP"
.SEGMENT "INIT"
.SEGMENT "ONCE"
jmp main

.include "data.s"
.include "routines.s"

GUI_VRAM = $0000
MAP_VRAM = $5000

VIEW_WIDTH = 50
VIEW_HEIGHT = 50

money:
	.res 4,0
cursor_x:
	.byte 0
cursor_y:
	.byte 0
map_scroll_x:
	.byte 0
map_scroll_y:
	.byte 0
real_cursor_x:
	.byte 0
real_cursor_y:
	.byte 0
gameover_flag:
	.word 0

setup: 
	; Setting up video ;
	; Stuff before main menu ;
	; point vera to read tile map for layer 0 at $5000 in VRAM
	lda #MAP_VRAM / 512
	sta $9F2E
	lda $9F36
	sta $9F2F
	stz $9F30
	stz $9F31
	stz $9F32
	stz $9F33
	lda #$60
	sta $9F2D
	; point vera to read tile map for layer 1 at $0000 in VRAM
	lda #GUI_VRAM / 512
	sta $9F35
	
	stz $9F25
	lda #%01110001
	sta $9F29
	
	jsr clear_screen
	jsr draw_outline
	
	
	; Setting up map ; 
	; Stuff after main menu code ;
	stz gameover_flag
	
	lda #$FF 
	sta buildings_array_start
	lda #<buildings_array_start
	sta buildings_array_end
	lda #>buildings_array_start
	sta buildings_array_end + 1
	
	stint $20000, money
	jsr display_money
	
	jsr setup_handler
	
	; do cursor stuff ;
	stz cursor_x
	stz cursor_y
	stz map_scroll_x
	stz map_scroll_y
	stz real_cursor_x
	stz real_cursor_y
	
	jsr initialize_sprite
	rts

clear_screen:
	stx $9F21
	stz $9F20
	lda #$10
	sta $9F22
	ldx #0
	ldy #$50 * 2
	lda #$20
	:
	sta $9F23
	stz $9F23
	inx 
	inx
	bne :-
	dey 
	bne :-
	rts 

main:
	jsr setup
	
	:
	jsr $FFE4
	cmp #$0a
	beq :-
	cmp #$0d
	beq :-
	
	;ldx #10
	;ldy #10
	;jsr build_building_search

game:
	jsr check_keyboard
	jsr update_sprite
	jsr update_map_scroll
	lda cursor_x
	clc 
	adc map_scroll_x
	sta real_cursor_x
	lda cursor_y
	clc 
	adc map_scroll_y
	sta real_cursor_y
	
	lda #60*2
	sta $9F20
	lda #30
	sta $9F21
	lda #$20
	sta $9F22
	
	lda real_cursor_x
	sta $9F23
	lda real_cursor_y
	sta $9F23
	
	; multiplication test ;
	lda #$20
	sta $9F23
	
	ldx real_cursor_x 
	ldy real_cursor_y
	jsr multiply_bcd
	sta $9F23 
	stx $9F23
	
	jsr check_frame
	jmp game
	
key_pressed:
	.byte 0
check_keyboard:
	jsr $FFE4
	sta key_pressed
	cmp #0
	bne :+
	jmp @end_check_keyboard
	:

	; W -> move cursor up ;
	cmp #$41 + 'W' - 'A'
	beq :+
	cmp #$91 ; UP arrow
	bne :+++
	:
	lda cursor_y
	beq :+
	dec cursor_y
	bra @end_check_mvmt
	:
	lda map_scroll_y
	beq @end_check_mvmt
	dec map_scroll_y
	:
	
	; A -> move cursor left ;
	cmp #$41
	beq :+
	cmp #$9D ; LEFT arrow
	bne :+++
	:
	lda cursor_x 
	beq :+
	dec cursor_x
	bra @end_check_mvmt
	:
	lda map_scroll_x
	beq @end_check_mvmt
	dec map_scroll_x
	:
	
	; S -> move cursor down ;
	cmp #$41 + 'S' - 'A'
	beq :+
	cmp #$11 ; DOWN arrow
	bne :+++
	:
	lda cursor_y 
	cmp #(VIEW_HEIGHT - 1)
	bcs :+
	inc cursor_y
	bra @end_check_mvmt
	:
	lda map_scroll_y
	cmp #64 - VIEW_HEIGHT
	bcs @end_check_mvmt	
	inc map_scroll_y
	:
	
	; D -> move cursor right ;
	cmp #$41 + 'D' - 'A'
	beq :+
	cmp #$1D ; RIGHT arrow
	bne :+++
	:
	lda cursor_x
	cmp #(VIEW_WIDTH - 1)
	bcs :+
	inc cursor_x
	bra @end_check_mvmt
	:
	lda map_scroll_x
	cmp #128 - VIEW_WIDTH
	bcs @end_check_mvmt
	inc map_scroll_x
	:
		
@end_check_mvmt:
	lda key_pressed
	; B -> search & build building ;
	cmp #$41 + 'B' - 'A'
	bne :+
	
	ldx real_cursor_x
	ldy real_cursor_y
	jsr build_building_search
	jmp @end_check_keyboard
	:
	
	; N -> build last building again ;
	cmp #$41 + 'N' - 'A'
	bne :+
	lda last_building
	cmp #$FF
	beq :+
	ldx real_cursor_x
	ldy real_cursor_y
	jsr build_if_possible
	cmp #0
	beq :+
	
	pha
	lda #59
	jsr clear_line
	lda #59
	sta $9F21
	stz $9F20
	lda #$20
	sta $9F22	
	pla
	
	jsr print_err_string
	:
	
	; U -> go to monitor ;
	cmp #$41 + 'U' - 'A'
	bne :+
	brk 
	:
	

@end_check_keyboard:	
	rts
	
; Do actions that should happen every second
; Generate revenue, do taxes, expenses, etc.
second_actions:
	jsr display_money
	
	lda @do_finances_counter
	bne :+
	jsr do_finances
	lda #2 ; every other second 
	:
	dec A 
	sta @do_finances_counter
	rts
@do_finances_counter:
	.byte 0
	
total_expenses = $44 ;:
	.word 0
road_counter:
	.word 0
happiness_amnt = $42 ;:
	.word 0
residental_amnt = $40 ;:
	.word 0
do_finances:
	stz happiness_amnt
	stz happiness_amnt+1
	stz residental_amnt
	stz residental_amnt+1
	stz total_expenses
	stz total_expenses+1
	stz road_counter
	stz road_counter+1
	
	;rts 
	
	lda #<buildings_array_start
	sta PTR1
	lda #>buildings_array_start
	sta PTR1+1
@expenses_loop:
	lda (PTR1)
	cmp #$FF
	beq @end_of_expense_loop
	
	; If building is road, add to road_counter ;
	; make user user is building roads ;
	cmp #ROAD_INDEX
	bne :+
	tax 
	cld 
	lda road_counter
	adc #(4 - 1)  ; (+ 2, since carry must be set since ROAD_INDEX >= ROAD_INDEX)
	sta road_counter
	txa
	bcc :+
	inc road_counter + 1
	:
	
	sec
	; A has building type ;
	asl ; Word = * 2
	tay
	lda buildings_recurring_cost, Y
	sta PTR2
	lda buildings_recurring_cost + 1, Y
	sta PTR2 + 1
	
	sed ; set decimal mode ;
	ldy #0
	lda (PTR2), Y
	clc 
	adc total_expenses
	sta total_expenses
	iny 
	lda (PTR2), Y
	adc total_expenses + 1
	sta total_expenses + 1
	
	iny
	lda (PTR2), Y
	clc 
	adc happiness_amnt
	sta happiness_amnt
	lda happiness_amnt + 1
	adc #0
	sta happiness_amnt + 1
	
	iny 
	lda (PTR2), Y
	clc 
	adc residental_amnt
	sta residental_amnt 
	lda residental_amnt + 1
	adc #0
	sta residental_amnt + 1
	
	; clear decimal flag for pointer addition ;
	cld 
	
	lda PTR1 
	adc #4
	sta PTR1 
	bcc @expenses_loop
	inc PTR1 + 1
	bra @expenses_loop	
@end_of_expense_loop:

	lda #<buildings_array_start
	sta PTR1
	lda #>buildings_array_start
	sta PTR1+1
	
	; Write road_counter to $9000, useful if breaking ;
	lda road_counter
	sta $9000
	lda road_counter+1
	sta $9001
	
	; For debugging, print out happiness and residental amounts ;
	lda #31
	sta $9F21
	lda #$20
	sta $9F22
	lda #50*2
	sta $9F20
	lda happiness_amnt
	jsr print_char_hex
	lda happiness_amnt + 1
	jsr print_char_hex
	lda residental_amnt
	jsr print_char_hex
	lda residental_amnt + 1
	jsr print_char_hex
@profits_loop:
	lda (PTR1)
	cmp #$FF
	beq @end
	
	asl ; Word = * 2
	tay
	lda buildings_profit, Y
	sta PTR2
	lda buildings_profit + 1, Y
	sta PTR2 + 1
	
	; mult by happiness to get profit ;
	lda happiness_amnt
	sta amnt_using
	lda happiness_amnt + 1
	sta amnt_using + 1
	ldy #0
	jsr profit_helper_routine
	lda amnt_using 
	sta happiness_amnt 
	lda amnt_using + 1
	sta happiness_amnt + 1
	
	lda residental_amnt
	sta amnt_using
	lda residental_amnt + 1
	sta amnt_using + 1
	ldy #3
	jsr profit_helper_routine
	lda amnt_using 
	sta residental_amnt 
	lda amnt_using + 1
	sta residental_amnt + 1
	
	cld 
	
	lda PTR1 
	adc #4
	sta PTR1 
	bcc :+
	inc PTR1 + 1
	:
	jmp @profits_loop
@end:
	; subtract expenses ;
	sed 
	sec 
	lda money
	sbc total_expenses
	sta money
	lda money + 1
	sbc total_expenses + 1
	sta money + 1
	lda money + 2
	sbc #0
	sta money + 2
	lda money + 3
	sbc #0
	sta money + 3
	bcc out_of_money
	cld 
	
	rts
	
out_of_money:
	lda #1
	sta gameover_flag
	rts 

amnt_using:
	.word 0
profit_helper_routine:
; MULTIPLY_BCD uses TEMPBYTE so need a seperate BYTE
@profit_tempbyte = TEMP_DWORD + 3	
	lda (PTR2), Y
	; Write data pointer
	bne :+
	rts 
	:
	sta @profit_tempbyte
	
	iny 
	lda (PTR2), Y 
	sta TEMPWORD 
	iny 
	lda (PTR2), Y
	sta TEMPWORD + 1
	
	; compare MAX to HAPPINESS_AMNT
	; put least in TEMPWORD 
	lda amnt_using + 1
	cmp TEMPWORD + 1
	bcc @happiness_less_max
	bne @happiness_greater_max
	lda amnt_using
	cmp TEMPWORD 
	bcs @happiness_greater_max
@happiness_less_max:
	lda amnt_using
	sta TEMPWORD
	lda amnt_using + 1
	sta TEMPWORD + 1

	stz amnt_using
	stz amnt_using + 1
	bra @subtract_from_total
@happiness_greater_max:	
	sed 
	sec 
	lda amnt_using
	sbc TEMPWORD 
	sta amnt_using
	lda amnt_using + 1
	sbc TEMPWORD + 1
	sta amnt_using + 1

@subtract_from_total:
	; Do multiply ;
	ldx TEMPWORD 
	ldy @profit_tempbyte
	phy
	jsr multiply_bcd
	sta TEMP_DWORD
	stx TEMP_DWORD + 1
	
	ldx TEMPWORD + 1
	;ldy @profit_tempbyte
	ply
	jsr multiply_bcd 
	sed 
	clc 
	adc TEMP_DWORD + 1
	sta TEMP_DWORD + 1
	txa
	adc #0
	sta TEMP_DWORD + 2
	
	; decimal is already set 
	; add residental profit to money ;
	clc 
	lda money 
	adc TEMP_DWORD
	sta money 
	lda money + 1
	adc TEMP_DWORD + 1
	sta money + 1
	lda money + 2
	adc TEMP_DWORD + 2
	sta money + 2
	lda money + 3
	adc #0
	sta money + 3
	cld 
	
	rts
	
build_building_search:	
	phy
	phx
	jsr prompt_string
	
	jsr find_building_index
	plx 
	ply
	
	
	cmp #BUILDING_NAMES_LEN
	bcs :++
	jsr build_if_possible
	beq :+
	
	stz $9F20
	ldx #59
	stx $9F21 
	ldx #$20
	stx $9F22
	jsr print_err_string
	:
	rts
	:
	lda #0
	sta $9F20
	lda #59
	sta $9F21
	lda #$20
	sta $9F22
	ldx #<err_string
	ldy #>err_string 
	jsr print_string
	ldx #<prompt_string_text
	ldy #>prompt_string_text
	jsr print_string
	ldx #<quote
	ldy #>quote
	jsr print_string
	rts

err_string:
	.literal "NO SUCH BUILDING "
quote:
	.literal "'", 0

buildings_array_end:
	.word 0

end_of_program = *
buildings_array_start = $2000
	