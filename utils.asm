;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros
;

PRINTXY: .macro
	lda #0
	ldy #\1
	ldx #\2
	jsr $fff0		; position x,y on text screen
	ldx #<\3
	ldy #>\3
	jsr Utils.sprint	; print text string
.endm

PRINTCHARXYA: .macro
	pha
	lda #0
	jsr $fff0		; position x,y on text screen
	pla
	jsr $ffd2		; print character
.endm

CLS: .macro
	lda #\1			; the colors (16*bg + fg)
	sta $286
	lda #$93		; clears the screen
	jsr $ffd2		; chr out
.endm

PRINTA: .macro
	jsr $ffd2
.endm


Utils: .block

.section section_CODE

sprint:
	stx ptext+1
	sty ptext+2
	ldy #0
ptext:
-	lda $0000, y
	beq +
	jsr $ffd2
	iny
	bra -
+	rts

.send section_CODE

.bend