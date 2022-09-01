.setcpu "65c02"

.macro INCPOINTER pt
	inc pt
	bne :+
	inc pt + 1
	:
.endmacro

TEMPBYTE = $1D
TEMPWORD = $1E
TEMP_DWORD = $19

PTR1 = $20
PTR2 = $22
PTR3 = $24
PTR4 = $26

hospital:
	.byte 3, 3
	.byte $55, $F2, $43, $F2, $49, $F2
	.byte $42, $F2, $08, $12, $42, $F2
	.byte $4A, $F2, $43, $F2, $4B, $F2 
hospital_name:
	.literal "HOSPITAL",0
hospital_costs:
	.word $0100
	.byte $88, $00
hospital_profits:
	.byte $00
	.word $0000 
	.byte $10
	.word $0015 ; max profit = 25 * 10 = 250
hospital_price = $5000

road:
	.byte 2, 2
	.byte $A0, $0B, $A0, $0B
	.byte $A0, $0B, $A0, $0B 
road_name:
	.literal "ROAD",0
road_costs:
	.word $0000
	.byte $00, $00
road_profits:
	.byte $00
	.word $0000
	.byte $00
	.word $0000
road_price = $100
	
house:
	.byte 2, 2
	.byte $E9, $59, $DF, $59
	.byte $E1, $52, $61, $52
house_name:
	.literal "HOUSE",0
house_costs:
	.word $0004
	.byte $00, $05
house_profits:
	.byte $5
	.word $0005
	.byte $00
	.word $0000
house_price = $800

police:
	.byte 2, 3
	.byte $4F, $16, $50, $16
	.byte $10, $16, $04, $16
	.byte $4C, $16, $7A, $16
police_name:
	.literal "POLICE",0
police_costs:
	.word $0040
	.byte $40, $00
police_profits:
	.byte $00
	.word $0000
	.byte $00
	.word $0000
police_price = $2500
	
bank:
	.byte 3, 3
	.byte $66, $C0, $62, $0F, $66, $0C
	.byte $E1, $0F, $24, $F5, $61, $0F
	.byte $66, $0C, $E2, $0F, $66, $C0
bank_name:
	.literal "BANK",0
bank_costs:
	.word $0250
	.byte $15, $00
bank_profits:
	.byte $00
	.word $0000
	.byte $20
	.word $2000
bank_price = $20000

fire:
	.byte 3, 3
	.byte $4F, $21, $A0, $22, $50, $21
	.byte $06, $21, $51, $21, $04, $21
	.byte $4C, $21, $A0, $22, $7A, $21
fire_name:
	.literal "FIRE",0
fire_costs:
	.word $0040
	.byte $10, $00
fire_profits:
	.byte $00
	.word $0000
	.byte $00
	.word $0000
fire_price = $2500

buildings_addr:
	.word bank
	.word fire
	.word hospital
	.word house
	.word police
	.word road

buildings_name:
	.word bank_name
	.word fire_name
	.word hospital_name
	.word house_name
	.word police_name
ROAD_INDEX = (* - buildings_name) / 2
	.word road_name
buildings_name_end:

BUILDING_NAMES_LEN = (buildings_name_end - buildings_name) / 2

buildings_cost:
	.dword bank_price
	.dword fire_price
	.dword hospital_price
	.dword house_price
	.dword police_price
	.dword road_price

buildings_recurring_cost:
	.word bank_costs
	.word fire_costs
	.word hospital_costs
	.word house_costs
	.word police_costs
	.word road_costs
buildings_profit:
	.word bank_profits
	.word fire_profits
	.word hospital_profits
	.word house_profits
	.word police_profits
	.word road_profits

last_building:
	.byte $FF
; building index in A ;
; x,y in X , Y ;
build_if_possible:
	phx 
	phy
	pha 
	jsr can_build
	beq :+
	
	ply 
	ply 
	ply 
	rts 
	
	:
	pla
	pha 
	jsr pay_for_building
	pla 
	ply 
	plx
	
	phx 
	phy 
	pha 
	
	sta last_building
	jsr draw_building
	pla 
	ply 
	plx 
	jsr add_to_buildings_list
	
	lda #0
	rts
	
building_literal_string:
	.literal "BUILDING:",0

; building index in A ;
; x,y in X , Y ;
; returns: ;
; A != 0 -> cannot build ;
; A == 0 -> can build ;
can_build:
	pha
	
	pha
	txa 
	asl 
	sta @spare_byte
	tya
	clc 
	adc #>MAP_VRAM
	sta $9F21
	lda #2 * $10
	sta $9F22
	pla 
	asl
	tay
	lda buildings_addr, Y
	sta PTR1
	iny 
	lda buildings_addr, Y
	sta PTR1 + 1
	lda (PTR1)
	tax
	inx
	INCPOINTER PTR1
	lda (PTR1)
	tay
	iny
	INCPOINTER PTR1
	phy
@outer_loop:
	ply
	dey
	phy
	beq @end_loop
	phx
	
	lda @spare_byte
	sta $9F20
@inner_loop:
	dex
	beq @end_inner_loop
	
	; main thing ;
	lda $9F23
	cmp #$20
	beq @inner_loop
	
	plx 
	ply
	
	pla
@fail:
	lda #1
	rts
@spare_byte:
	.byte 0
	
@end_inner_loop:	
	plx
	inc $9F21
	bra @outer_loop
@end_loop:
	ply 
	pla
		
	jsr load_cost_into_mem
	
@check_if_less:	
	lda money + 3
	cmp PTR1 + 3
	bne @check_flags
	lda money + 2
	cmp PTR1 + 2
	bne @check_flags
	lda money + 1
	cmp PTR1 + 1
	bne @check_flags
	lda money
	cmp PTR1
	bcs @pass
	; if less fail
@money_fail:
	lda #2
	rts
@check_flags:
	bcc @money_fail
	;bcs @pass
@pass:
	lda #0
	rts

	
last_err_string:
	.literal "LAST ERROR: ",0
no_space_string:
	.literal "NOT ENOUGH SPACE",0
no_money_string:
	.literal "NOT ENOUGH MONEY",0
build_err_strings:
	.word no_space_string
	.word no_money_string

; errno in A ;
; VRAM address to write to must already be set ;
print_err_string:
	pha
	
	ldx #<last_err_string
	ldy #>last_err_string
	jsr print_string
	
	pla 
	dec A
	asl 
	tay 
	lda build_err_strings, Y
	tax
	lda build_err_strings + 1, Y
	tay
	jmp print_string
	;rts
	

load_cost_into_mem:
	asl 
	asl
	tay 
	
	lda buildings_cost, Y
	sta PTR1
	lda buildings_cost + 1, Y
	sta PTR1 + 1
	lda buildings_cost + 2, Y
	sta PTR1 + 2
	lda buildings_cost + 3, Y
	sta PTR1 + 3
	rts
	
pay_for_building:
	jsr load_cost_into_mem

	sec
	sed
	lda money 
	sbc PTR1
	sta money
	
	lda money+1
	sbc PTR1+1
	sta money+1
	
	lda money+2
	sbc PTR1+2
	sta money+2
	
	lda money+3
	sbc PTR1+3
	sta money+3
	
	cld
	
	jsr display_money
	rts 


; building index in A ;
; x,y in X , Y ;
draw_building:
	pha 
	txa 
	asl 
	clc 
	adc #<MAP_VRAM
	sta @spare_byte
	tya
	adc #>MAP_VRAM
	sta $9F21
	lda #1 * $10
	sta $9F22
	pla 
	asl
	tay
	lda buildings_addr, Y
	sta PTR1
	iny 
	lda buildings_addr, Y
	sta PTR1 + 1
	lda (PTR1)
	tax
	inx
	INCPOINTER PTR1
	lda (PTR1)
	tay
	iny
	INCPOINTER PTR1
	phy
@outer_loop:
	ply
	dey
	phy
	beq @end_loop
	phx
	
	lda @spare_byte
	sta $9F20
@inner_loop:
	dex
	beq @end_inner_loop
	
	; main thing ;
	lda (PTR1)
	INCPOINTER PTR1
	sta $9F23
	lda (PTR1)
	INCPOINTER PTR1
	sta $9F23
	
	bra @inner_loop
@end_inner_loop:	
	plx
	inc $9F21
	bra @outer_loop
@end_loop:
	ply 
	rts 
@spare_byte:
	.byte 0

; only works given buildings_name is alphabetical ;
; find index given pointer to name ;
; x = low byte, y = high byte ;
find_building_index:
	stx strcmp_ptr2
	sty strcmp_ptr2 + 1

	lda #0
	sta @low 
	lda #BUILDING_NAMES_LEN
	sta @high
@loop:
	lda @low
	cmp @high
	bcs @fail
	
	lda @low 
	clc
	adc @high 
	lsr A 
	sta @middle
	
	lda @middle
	asl A
	tay 
	lda buildings_name, Y
	sta strcmp_ptr1
	iny 
	lda buildings_name, Y
	sta strcmp_ptr1 + 1
	jsr strcmp
	
	cmp #0
	bne :+
	
	lda @middle
	rts 
	:
	bmi :+
	; str1 < str2
	lda @middle
	sta @high
	
	bra :++
	:
	; str2 > str1
	lda @middle 
	inc A 
	sta @low	
	:
	jmp @loop
	
@fail:
	lda #$FF
	rts 

@low:
	.byte 0
@middle:
	.byte 0
@high:
	.byte 0

money_string:
	.literal "MONEY: $",0
display_money:
	lda #51*2
	sta $9F20 
	lda #1
	sta $9F21
	lda #$20
	sta $9F22
	
	ldx #<money_string
	ldy #>money_string
	jsr print_string
	
	ldy #3
	sty TEMPBYTE
@loop:
	phy 
	lda money, Y
	bne :+
	cpy TEMPBYTE
	bne :+
	dec TEMPBYTE
	bra @pull_y
	:
	pha 
	sec 
	jsr get_hex
	sta $9F23
	pla 
	clc 
	jsr get_hex
	sta $9F23

@pull_y:
	ply
	beq @end
	dey
	bra @loop
@end:
	ldy TEMPBYTE
	cpy #$FF
	bne :+
	
	lda #$30
	sta $9F23
	
	:
	ldy #8
	lda #$20
	:
	sta $9F23
	dey
	bne :-
	rts

initialize_sprite:
	jsr load_cursor_vram

	lda #8
	sta $9F20
	lda #$FC 
	sta $9F21
	lda #$11
	sta $9F22
	
	stz $9F23
	lda #%00001000 ; set 4bpp and addr
	sta $9F23
	stz $9F23 
	stz $9F23
	stz $9F23
	stz $9F23
	lda #%00001100
	sta $9F23
	stz $9F23
	
	rts
	
; X, Y contains sprite X, Y ;
update_sprite:
	lda #8 + 2
	sta $9F20
	lda #$FC 
	sta $9F21
	lda #$11
	sta $9F22
	
	lda cursor_x
	ldx #0
	:
	stz TEMPWORD + 1
	asl A
	rol TEMPWORD + 1
	asl A
	rol TEMPWORD + 1
	asl A
	rol TEMPWORD + 1
	sta $9F23
	lda TEMPWORD+1
	sta $9F23
	
	cpx #0
	bne :+
	ldx #1
	lda cursor_y
	bra :-
	:
	rts 
	

load_cursor_vram:
	stz $9F20
	stz $9F21
	lda #$11
	sta $9F22
	ldy #0
@loop:
	lda cursor_sprite_data, Y
	sta $9F23
	iny 
	cpy #32
	bcc @loop
	rts

cursor_sprite_data:
	.byte $11, $10, $01, $11
	.byte $10, $00, $00, $01
	.byte $10, $00, $00, $01
	.byte $00, $00, $00, $00
	.byte $00, $00, $00, $00
	.byte $10, $00, $00, $01
	.byte $10, $00, $00, $01
	.byte $11, $10, $01, $11
	