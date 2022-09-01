.macro stint num, addr
lda #<num
sta addr
lda #>num
sta addr+1
lda #<(.hiword(num))
sta addr+2
lda #>(.hiword(num))
sta addr+3
.endmacro

.macro mov4 dest, src
lda src
sta dest
lda src+1
sta dest+1
lda src+2
sta dest+2
lda src+3
sta dest+3
.endmacro

print_string:
	stx PTR1
	sty PTR1 + 1
@loop:	
	lda (PTR1)
	beq @end
	
	cmp #$41
	bcc :+
	cmp #$41 + 'Z' - 'A'
	and #%10111111
	:
	sta $9F23 
	
	INCPOINTER PTR1
	bra @loop
@end:
	rts

; A contains byte ;
; All registers are preserved ;
print_char_hex:
	pha 
	pha 
	sec 
	jsr get_hex 
	sta $9F23 
	
	pla 
	clc 
	jsr get_hex
	sta $9F23 
	
	lda #$20
	sta $9F23
	
	pla 
	rts 

; A contains byte ;
; Carry Set = High nibble ;
; Carry Clear = Low nibble ;
get_hex:
	phy 
	bcc :+
	lsr 
	lsr 
	lsr 
	lsr 
	:
	and #$0F
	tay 
	lda @get_hex_array, Y
	ply 
	rts 
@get_hex_array:
	.byte $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, 1, 2, 3, 4, 5, 6

print_string_hex:
	stx PTR1
	sty PTR1 + 1
@loop:	
	lda (PTR1)
	beq @end
	
	pha
	sec 
	jsr get_hex
	sta $9F23 
	pla 
	clc 
	jsr get_hex
	sta $9F23 
	
	ldy #$20
	sty $9F23 
	
	INCPOINTER PTR1
	bra @loop
@end:
	rts

draw_outline:
	lda #$10
	sta $9F22
	
	ldy #0
	sty $9F21 
	:
	ldx #100
	stx $9F20
	ldx #30
	:
	lda #$20
	sta $9F23 
	lda #$61
	sta $9F23
	dex 
	bne :-
	iny 
	sty $9F21
	cpy #50
	bcc :--
	
	dec $9F21
	tax ; ldx #$61
	lda #$20
	:
	sta $9F23 
	stx $9F23
	ldy $9F21
	cpy #80
	bne :-
	
	rts
	

clear_line:
	sta $9F21
	stz $9F20
	ldx #$20
	stx $9F22
	
	ldy #$20
	:
	sty $9F23
	dex
	bne :-
	rts

prompt_string_text:
.res 32, 0
prompt_string:
	lda #58
	jsr clear_line
	stz $9F20
	ldx #<building_literal_string
	ldy #>building_literal_string
	jsr print_string
	lda #59
	jsr clear_line
	stz $9F20
	
	;ldx #$3A
	ldx #0
	stx $9F23
	
	ldx #0
@loop:
	phx
	:
	jsr $FFE4
	cmp #0
	beq :-
	plx 
	cmp #$0d
	beq @end
	
	cmp #$41
	bcc @eofloop
	cmp #$41 + 26 + 1
	bcs @eofloop
	
	; carry is set;
	sta prompt_string_text, X
	and #%10111111
	sta $9F23
@newletter_inx:
	inx 
	bne @loop	
	
@eofloop:
	cmp #20 ; backspace
	beq :+
	cmp #25 ; backspace
	bne @loop
	:
	cpx #1
	bcc @loop
	
	txa
	asl
	tay 
	sta $9F20
	lda #$20
	sta $9F23
	sty $9F20 
	
	dex
	bra @loop

@end:
	stz prompt_string_text, X
	lda #58
	jsr clear_line
	lda #59
	jsr clear_line
	
	ldx #<prompt_string_text
	ldy #>prompt_string_text
	rts
	
; strcmp ;
; compares memcmp_ptr1 & memcmp_ptr2 ;
strcmp_ptr1:
	.word 0
strcmp_ptr2:
	.word 0
strcmp:
	ldx strcmp_ptr1
	stx PTR1 
	ldx strcmp_ptr1 + 1
	stx PTR1 + 1
	
	ldx strcmp_ptr2
	stx PTR2
	ldx strcmp_ptr2 + 1
	stx PTR2 + 1
	
	ldy #0
@loop: 
	sec
	lda (PTR1), Y
	tax 
	sbc (PTR2), Y
	
	bne @end
	iny 
	txa 
	cmp #0
	bne @loop
@end:
	rts
	
	
RDTIM = $FFDE 

setup_handler:
	lda $0314
	sta default_handler
	lda $0315
	sta default_handler+1
	sei 
	lda #<custom_irq_handler
	sta $0314
	lda #>custom_irq_handler
	sta $0315
	cli
	rts 
	
custom_irq_handler:
	lda $9F27
	and #1
	beq @irq_done
	; vsync ;
	lda framecount
	inc A 
	cmp #60
	bcc @update_framecount
	
	lda $9F20 
	pha 
	lda $9F21
	pha
	lda $9F22 
	pha
	
	jsr second_actions
	
	pla 
	sta $9F22
	pla 
	sta $9F21
	pla 
	sta $9F20
	
	lda #0
@update_framecount:
	sta framecount
	
	dec $9F27
@irq_done:
	jmp (default_handler)
default_handler:
	.word 0
	
check_frame:
	lda framecount 
	:
	cmp framecount 
	beq :-
	rts 
framecount:
	.byte 0
	
update_map_scroll:
	lda map_scroll_x
	ldx #0
	:
	asl A
	rol TEMPWORD + 1
	asl A
	rol TEMPWORD + 1
	asl A
	rol TEMPWORD + 1
	
	sta $9F30, X
	lda TEMPWORD+1
	sta $9F31, X
	
	cpx #0
	bne :+
	ldx #2
	lda map_scroll_y
	bra :-
	:
	rts

; ID of building in A ;
get_building_size:
	pha 
	asl 
	tax
	
	lda buildings_addr, X
	sta PTR1
	lda buildings_addr + 1, X 
	sta PTR1 + 1
	
	lda (PTR1)
	tax 
	ldy #1
	lda (PTR1), Y
	tay 
	
	pla 
	rts 

; multiply_bcd ;
; X * Y -> AX ;
multiply_bcd:
; symbols ;
@xl = $30
@xh = $31
@yl = $32
@yh = $33
@result = $34
	sed
	
	txa
	and #$0F
	sta @xl
	txa 
	lsr 
	lsr 
	lsr 
	lsr
	sta @xh
	
	tya
	and #$0F
	sta @yl
	tya 
	lsr 
	lsr 
	lsr 
	lsr
	sta @yh
	
	;   a b 
	; x c d
	; = d*b + a*c+100 + d*a*10 + c*b*10
	
	; b * d	;
	lda @xl
	asl 
	asl 
	asl 
	asl 
	; we know clc ;
	adc @yl
	tax
	lda bcd_multiply_table, X
	sta @result 
	
	; a * c ;
	lda @xh
	asl 
	asl 
	asl 
	asl 
	adc @yh
	tax
	lda bcd_multiply_table, X
	sta @result + 1
	
	; a * d ;
	lda @xl
	asl 
	asl 
	asl 
	asl 
	; we know clc ;
	adc @yh
	tax
	lda bcd_multiply_table, X
	sta TEMPBYTE
	
	; b * c ;
	lda @xl
	asl 
	asl 
	asl 
	asl 
	; we know clc ;
	adc @yh
	tax
	lda bcd_multiply_table, X
	clc 
	adc TEMPBYTE
	sta TEMPBYTE
	bcc :+
	tax 
	lda @result+1
	clc
	adc #$10 ; if carray is set, increment high nibble of high byte of result
	sta @result+1
	txa ; put TEMPBYTE back in A
	:
	lsr 
	lsr 
	lsr 
	lsr ; put high nibble in low nibble 
	clc 
	adc @result+1
	sta @result+1
	
	lda TEMPBYTE
	asl 
	asl 
	asl 
	asl
	clc 
	adc @result
	tay
	; sta @result 
	lda @result + 1
	adc #0
	; sta @result + 1

	tax 
	tya
	
	cld
	rts
; for reference ;
; @xl = $30
; @xh = $31
; @yl = $32
; @yh = $33
; @result = $34
bcd_multiply_table:
	.byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00 ; 0
	.byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $00, $00, $00, $00, $00, $00 ; 1
	.byte $00, $02, $04, $06, $08, $10, $12, $14, $16, $18, $00, $00, $00, $00, $00, $00 ; 2
	.byte $00, $03, $06, $09, $12, $15, $18, $21, $24, $27, $00, $00, $00, $00, $00, $00 ; 3
	.byte $00, $04, $08, $12, $16, $20, $24, $28, $32, $36, $00, $00, $00, $00, $00, $00 ; 4
	.byte $00, $05, $10, $15, $20, $25, $30, $35, $40, $45, $00, $00, $00, $00, $00, $00 ; 5
	.byte $00, $06, $12, $18, $24, $30, $36, $42, $48, $54, $00, $00, $00, $00, $00, $00 ; 6
	.byte $00, $07, $14, $21, $28, $35, $42, $49, $56, $63, $00, $00, $00, $00, $00, $00 ; 7
	.byte $00, $08, $16, $24, $32, $40, $48, $56, $64, $72, $00, $00, $00, $00, $00, $00 ; 8
	.byte $00, $09, $18, $27, $36, $45, $54, $07, $72, $81, $00, $00, $00, $00, $00, $00 ; 9

; X, Y is position of building ;
; A is type of building ;
; 
; Increments end of buildings_array_end by 4 ;
; And writes to where it pointed before ;
add_to_buildings_list:
	phx 
	pha 

	lda buildings_array_end
	sta PTR1
	ldx buildings_array_end + 1
	stx PTR1 + 1
	
	clc 
	adc #4
	sta buildings_array_end
	txa
	adc #0
	sta buildings_array_end + 1
	
	tya
	tax 
	
	pla
	sta (PTR1)
	ldy #1
	pla 
	sta (PTR1), Y
	iny 
	txa 
	sta (PTR1), Y
	
	iny 
	
	iny 
	lda #$FF
	sta (PTR1), Y
	rts 
	