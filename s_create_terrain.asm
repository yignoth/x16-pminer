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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Vars
;
.section section_ZP
tcol_addr		.word	?				; pointer to terrain map address of the current column
tchar_addr		.word	?
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
last_height		.byte	?				; the current terrain height
btmp			.byte	?				; tmp byte
thL				.byte	?				; terrain height value 1, 2, 3
thM				.byte	?
thR				.byte	?


init: .proc
	#CLS $01
	#PRINTXY 40-19/2, 10, text_create

	lda #PHASE_TERRAIN
	sta phase							; initialize stage variables

	rts
.pend


update: .proc
	lda phase
	cmp #PHASE_TERRAIN
	bne +
	jsr generateTerrainHeight
	bra done

+	cmp #PHASE_TCHARS
	bne +
	jsr generateTerrainChars
	bra done

+	cmp #PHASE_ORE
	bne +
	jsr generateOreLocations
	bra done

+	#CHANGE_STAGE StageLander
done:
	rts
.pend


render:	.proc
	#vaddr 2, 0
	lda phase
	clc
	adc Vera.IO_VERA.addrL
	sta Vera.IO_VERA.addrL
	lda phase
	#vpoke0A
	rts
.pend


generateOreLocations: .proc
	lda #PHASE_DONE
	sta phase
	rts
.pend

generateTerrainChars: .proc
	lda #<TERRAIN_HEIGHT_ADDR+1	; initialize tcol and tchar addresses
	sta tcol_addr
	lda #>TERRAIN_HEIGHT_ADDR+1
	sta tcol_addr+1
	lda #<TERRAIN_CHAR_ADDR
	sta tchar_addr
	lda #>TERRAIN_CHAR_ADDR
	sta tchar_addr+1

	lda TERRAIN_HEIGHT_ADDR + TERRAIN_MAP_WIDTH -1		; init thL, thM:  TERRAIN_CHAR_ADDR = TERRAIN
	sta thL												; store height left of us
	lda TERRAIN_HEIGHT_ADDR
	sta thM												; store height at our column

loop:
	;
	; figure out which brick to use
	lda (tcol_addr)				; load height to right of us
	sta thR						; store thR

	lda thM
	cmp thL						; compare M to L
	bge cs1						; if M >= L then cs1
	cmp thR
	bge +
	lda #BRICK_PIT				; "v"
	bra lstore
+	beq +
	lda #BRICK_RIGHT			; "\_
	bra lstore
+	lda #BRICK_SOLID			; "--
	bra lstore
cs1:
	bne cs2						; if M > L then cs2
	cmp thR
	beq +
	blt + 
	lda #BRICK_RIGHT			; -\_
	bra lstore
+	lda #BRICK_SOLID			; ---, --"
	bra lstore
cs2:
	cmp thR
	beq +
	blt +
	lda #BRICK_TOP
	bra lstore
+	lda #BRICK_LEFT
lstore:
	sta (tchar_addr)			; store terrain character

	inc tchar_addr				; inc tchar_addr
	bne +
	inc tchar_addr+1
+
	lda tchar_addr
	cmp #<TERRAIN_ORE_ADDR		; check if we are done
	bne +
	lda tchar_addr+1
	cmp #>TERRAIN_ORE_ADDR
	beq done

+
	inc tcol_addr				; inc tcol_addr
	bne +
	inc tcol_addr+1
+
	lda tcol_addr
	cmp #<TERRAIN_CHAR_ADDR		; check if we have rolled over
	bne loop2

	lda tcol_addr+1
	cmp #>TERRAIN_CHAR_ADDR
	bne loop2

	lda #<TERRAIN_HEIGHT_ADDR	; reset address
	sta tcol_addr
	lda #>TERRAIN_HEIGHT_ADDR
	sta tcol_addr+1
loop2:
	lda thM						; shift M to L
	sta thL
	lda thR						; shift R to M
	sta thM

	bra loop

done:
	lda #PHASE_ORE
	sta phase
	rts
.pend

generateTerrainHeight: .proc
	lda #<TERRAIN_HEIGHT_ADDR	; initialize tcol addr
	sta tcol_addr
	lda #>TERRAIN_HEIGHT_ADDR
	sta tcol_addr+1
	lda #8						; initial height value
	sta last_height

-
	jsr GetRandHeight		; get a random height (return value in A)
	sta (tcol_addr)			; store it

	inc tcol_addr			; inc tcol_addr by 1
	bne +
	inc tcol_addr+1

+	lda tcol_addr+1				; check if we are done
	cmp #>TERRAIN_CHAR_ADDR
	bne -
	lda tcol_addr
	cmp #<TERRAIN_CHAR_ADDR
	bne -

	lda #PHASE_TCHARS		; switch phases
	sta phase
	rts
.pend


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