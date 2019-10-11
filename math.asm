;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Math Routines
;

Math: .block

.section section_ZP
.send section_ZP

.section section_BSS
	rndSeed			.byte   ?
	rndTableIdx		.byte   ?
	rndTableCount	.byte	?
.send section_BSS


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros
;

; Set random seed:  12 bit value
; \1 = 12 bit random alg seed
setRndSeed:	.macro
		lda #<\1
		sta Math.rndSeed				; store random seed
		lda #>(\1 & $0f00)
		sta Math.rndTableIdx			; store table index
		stz Math.rndTableCount		; 0 count, so we have 256 values
		jsr Math.Random.doInc
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Code section
;
.section section_CODE

; Given an initial seed, this will generate 256 different values
; before repeating.
;
; Number is stored in #Math.rndSeed
Random: .proc
		lda rndSeed
		beq doEor
		asl a
		beq noEor ;if the input was $80, skip the EOR
		bcc noEor
doEor:	eor #$1d
noEor:  sta rndSeed

doInc:	inc rndTableCount	; increment table count
		beq +
		lda rndTableIdx		; if tablecount rolls over, increment table index
		inc a
		and #$0f			; we only have 15 values so clip it
		sta rndTableIdx
		tax
		lda randomEorTable,x	; load new EOR value
		sta doEor+1				; store in random code
+		rts
.pend

; a list of EOR values (doEor line) that will produce 256 different values
randomEorTable:
	.byte $1d,$2b,$2d,$4d,$5f,$63,$65,$69,$71,$87,$8d,$a9,$c3,$cf,$e7,$f5

.send section_CODE

.bend