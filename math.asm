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

; Shifts a SIGNED 1-4byte ADDR1 by N bits.
; <ADDR1> = signed 1-4 byte number which will be shifted by N bits to right.
; <N> = the number of bits to shift right.
shiftSignedByNToCopy: .macro
	.if \2 == 1
		lda \1
		asl a
		.if size(\1) == 4
			ror \1+3
		.fi
		.if size(\1) >= 3
			ror \1+2
		.fi
		.if size(\1) >= 2
			ror \1+1
		.fi
		ror \1
	.else
		ldy \1+2
		.rept \2
			cpy #$80
			.if size(\1) == 4
				ror \1+3
			.fi
			.if size(\1) >= 3
				ror \1+2
			.fi
			.if size(\1) >= 2
				ror \1+1
			.fi
			ror \1
		.next
	.fi
.endm


; Divides an unsigned 3-byte number at ADDR1 by 64 and puts result into ADDR2 (3bytes).
; Divide is done by shifting right 6-bits.  Number must be UNSIGNED (won't work for signed numbers).
; ADDR1 remains untouched.
; <ADDR1> = unsigned 3 byte number
; <ADDR2> = unsigned 3 byte result.
divideUnsignedLongBy64ToCopy: .macro
		stz \2				
		stz \2+1
		stz \2+2
		lda \1
		asl a
		rol \2
		asl a
		rol \2
		lda \1+1
		asl a
		rol \2+1
		asl a
		rol \2+1
		ora \2
		sta \2
		lda \1+2
		asl a
		rol \2+2
		asl a
		rol \2+2
		ora \1+1
		sta \1+1
.endm

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