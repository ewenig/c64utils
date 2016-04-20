	.include "macros.inc"

	; zero-page variables
	rindex=$10    ; rotation table index
	cindex=$11    ; cardioid table index
	speed=$12     ; current rotation speed
	tablectr=$13  ; current rotation table delay countdown
	rotctr=$14    ; current rotation table delay countdown

    *=$1000

	#disint
	#cls

	lda #$00  ; colors
	sta $d021 ; background color
	sta $d01c ; all sprites high-res
	sta rindex ; initialzers

	lda #$ff
	sta $d017 ; scale x
	sta $d01d ; scale y
	sta $d015 ; enable sprites

	; pointers
	lda #$20 ; initial ptr
	ldx #$f8 
ptrlp:
	sta $0700,x
	inx
	bmi ptrlp ; will overflow when x rolls over to $00

	lda #$14
	sta $d018 ; set screen/character memory offsets 

	; shit from  http://codebase64.org/doku.php?id=base:double_irq_explained
    lda #$01
    sta $d01a ; enable raster interrupt
	lda #$1b
	sta $d011 ; clear high bit of IRQ

	; set up raster interrupt
	ldy #<startframe
	ldx #>startframe
	lda #$00
	sty $0314
	stx $0315
	sta $d012

	#enint

;;; MAIN LOOP ;;;
	jmp *
;;; MAIN LOOP ;;;

; mid-frame interrupt
midframe:
	; move sprite 1 to new position
	lda $d004
	sta $d000
	lda $d00d
	sta $d001

	; set overflow mask if necessary
	lda $d010
	tax
	and #%00000100
	beq mloadnxt
	txa
	ora #%00000001
	sta $d010

mloadnxt: ; load next interrupt
	lda #<startframe
	ldx #>startframe
	ldy #00
	sta $0314
	stx $0315
	sty $d012

	asl $d019 ; ack interrupt
	#ret

; start-frame interrupt
startframe:
	; move all sprites
	ldx cindex ; cardioid index
	lda xbuf,x
	sta $d000
	sta $d006
	sta $d00c
	adc #48
	sta $d002
	sta $d008
	sta $d00e
	adc #48
	sta $d004
	sta $d00a
	lda ybuf,x
	sta $d001
	sta $d003
	sta $d005
	adc #42
	sta $d007
	sta $d009
	sta $d00b
	adc #42
	sta $d00d
	sta $d00f

	lda ofbuf,x    ; current offset byte
	sta $d010      ; store in the offset mask register

	inx
	stx cindex ; inc and store the index

	; rotate the sprites
rotate: 
	ldx tablectr ; ... unless we hit 0 on the table delay counter
	cpx #$00
	beq advance_table
	ldx rindex
	ldy rotctr
	bne tick_ctrs ; nop if rotctr > 0
	lda rot_spd,x
	beq tick_ctrs ; nop if speed is 0
	bmi rotate_backward
rotate_forward:
	ldy $07f8
	iny
	cpy #$2e
	bne store_ptrs
	ldy #$20 ; wrap around (here is where you can increase the # of allowed sprites)
	jmp store_ptrs
rotate_backward:
	ldy $07f8
	dey
	cpy #$1f
	bne store_ptrs
	ldy #$2e ; wrap around, the other way
store_ptrs:
	tya
	ldx #$f8
ptrlp2:
	sta $0700,x
	inx
	bmi ptrlp2
	; load next rotation counter
	ldx rindex
	; find the absolute value of the speed from the table
	; from https://atariage.com/forums/topic/71120-6502-killer-hacks/page-4
find_rotctr:
	lda rot_spd,x
	bpl set_rotctr
	eor #$ff
	clc
	adc #1
set_rotctr:
	sta rotctr
	jmp loadnxt
tick_ctrs:
	ldy tablectr
	dey
	sty tablectr
	ldy rotctr
	dey
	sty rotctr
	jmp loadnxt

advance_table: ; if we hit 0 on the table delay counter, advance the table index
	ldx rindex
	cpx rot_size
	beq reset_rindex
	inx 
	.byte $2c ; hack to skip the next instruction
reset_rindex:
	; if we're at the end of the table, restart
	ldx #$00
set_rindex:
	stx rindex
	; calculate the new tablectr and rotctr
	lda rot_dly,x
	sta tablectr
	; we can just reuse the absolute value-finding code from the last function
	; since it ends after that.
	jmp find_rotctr ; XXX i think this incurs a 1 frame delay?

loadnxt:
	; load next interrupt
	ldy #<midframe
	ldx #>midframe
	lda $d007
	sty $0314
	stx $0315
	sta $d012

	asl $d019 ; ack interrupt
	#ret

	* = $800
	.include "sprites/sprite1.dat"
	.include "sprites/sprite2.dat"
	.include "sprites/sprite3.dat"
	.include "sprites/sprite4.dat"
	.include "sprites/sprite5.dat"
	.include "sprites/sprite6.dat"
	.include "sprites/sprite7.dat"
	.include "sprites/sprite8.dat"
	.include "sprites/sprite9.dat"
	.include "sprites/sprite10.dat"
	.include "sprites/sprite11.dat"
	.include "sprites/sprite12.dat"
	.include "sprites/sprite13.dat"
	.include "sprites/sprite14.dat"

	* = $2000
	.include "data/cardioid.dat"
	.include "data/rotation.dat"
