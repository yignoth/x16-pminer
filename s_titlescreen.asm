;
; Template
;

StageTitle: .block

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Definitions
;

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
printxy: .macro
	lda #0
	ldy #\1
	ldx #\2
	jsr $fff0
	ldx #<\3
	ldy #>\3
	jsr sprint
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Code
;
.section section_CODE

jumpTable:
	jmp init
	jmp update
	jmp render


init:
	lda #01
	sta $286
	lda #$93
	jsr $ffd2
	#printxy 40-16/2, 10, text_title
	#printxy 40-27/2, 15, text_hak
	rts


update:
	jsr GETJOY				; process joystick input
	lda JOY1				; read joystick value
	bit #$20				; bit 6 clear means SPACE is pushed
	bne +
	#CHANGE_STAGE StageLander
+	rts


render:
	lda #$93
	sta $ffd2
	rts

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

text_title:
	.text 'PLANET LANDER V0', 0
text_hak:
	.text 'HIT SPACE (TWICE?) TO START', 0

.send section_CODE

.bend