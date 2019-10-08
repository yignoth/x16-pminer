;
; Template
;

StageCreateTerrain: .block

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Definitions
;
PHASE_TERRAIN	= 0
PHASE_TCHARS	= 1
PHASE_ORE		= 2
PHASE_DONE		= 3
TERRAIN_WIDTH	= 1024

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Vars
;
.section section_ZP
.send section_ZP

.section section_BSS
.send section_BSS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros
;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Code
;
.section section_CODE

jumpTable:
	jmp init
	jmp update
	jmp render

; vars
phase			.byte	?				; the current phase
										; phase 0 = generate terrain heights
										; phase 1 = generate terrain characters
										; phase 2 = generate ore locations
										; phase 3 = done, switch to next stage
tcol			.word	?				; the current column being generated
tcol_addr		.word	?				; the HIMEM address of the current column
last_height		.byte	?				; the current terrain height
btmp			.byte	?				; tmp byte


init:
	#CLS $01
	#PRINTXY 40-19/2, 10, text_create

	lda #PHASE_TERRAIN
	sta phase							; initialize stage variables
	lda #8
	sta last_height

	stz tcol							; initialize tcol and mem storage address
	stz tcol+1
	lda #<HIMEM
	sta tcol_addr
	lda #>HIMEM
	sta tcol_addr+1

	rts


update:
	lda phase
	cmp #PHASE_TERRAIN
	bne +
	jsr generateTerrainHeight
	bra udone

+	cmp #PHASE_TCHARS
	bne +
	jsr generateTerrainChars
	bra udone

+	cmp #PHASE_ORE
	bne +
	jsr generateOreLocations
	bra udone

+	#CHANGE_STAGE StageLander
udone:
	rts


render:
	#vaddr 2, 0
	lda tcol
	clc
	adc Vera.IO_VERA.addrL
	sta Vera.IO_VERA.addrL
	lda phase
	#vpoke0A
	rts


generateOreLocations:
	lda #PHASE_DONE
	sta phase
	rts

generateTerrainChars:
	lda #PHASE_ORE
	sta phase
	rts

generateTerrainHeight:
	jsr GetRandHeight		; get a random height (return value in A)
	sta tcol_addr			; store it
	inc tcol				; inc tcol by 1
	bcc +
	inc tcol+1

+	inc tcol_addr			; inc tcol_addr by 1
	bcc +
	inc tcol_addr+1

+	lda tcol+1
	cmp #>TERRAIN_WIDTH
	bne generateTerrainHeight
	lda tcol
	cmp #<TERRAIN_WIDTH
	bne generateTerrainHeight

	lda #PHASE_TCHARS
	sta phase
	rts


; This routine gets a random number and then
; converts it to a terrain height adjustment of
; -5 to +5 with 0 being the most common.
; The height cannot be less than 1 or greater than 16, else
; it is clipped
GetRandHeight: .proc
		jsr Math.Random						; get a random number
		lda Math.rndSeed
		cmp #84								; check top of neg range
		bcc r_neg
		cmp #171							; check bottom of pos range
		bcs r_pos
		ldx #0								; no change
		bra r_done
r_neg:	ldx #$ff								; -1 height decrease
		cmp #41								; check for -2
		bcs r_done
		dex
		cmp #19								; check for -3
		bcs r_done
		dex
		cmp #8								; check for -4
		bcs r_done
		dex
		cmp #3								; check for -5
		bcs r_done
		dex
		bra r_done
r_pos:	ldx #1								; +1 height increase
		cmp #215							; check for +2
		bcc r_done
		inx
		cmp #237							; check for +3
		bcc r_done
		inx
		cmp #248							; check for +4
		bcc r_done
		inx
		cmp #253							; check for +5
		bcc r_done
		inx
r_done:	txa									; x to A
		clc
		adc last_height						; add to height
		bpl +
		lda #$00							; min of zero allowed
		bra r_fin
+		cmp #$10							; max of 15 allowed
		bcc r_fin
		lda #$0f							; clip at 15
r_fin:	sta last_height
		ina									; add 1 so value is between 1 & 16
		rts
.pend



text_create:
	.text 'TRAVELING TO PLANET', 0

.send section_CODE

.bend