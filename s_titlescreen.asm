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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Code
;
.section section_CODE

jumpTable:
	jmp init
	jmp update
	jmp render


init:
	#CLS $01
	#PRINTXY 40-16/2, 10, text_title
	#PRINTXY 40-27/2, 15, text_hak
	rts


update:
	jsr GETJOY				; process joystick input
	lda JOY1				; read joystick value
	bit #$20				; bit 6 clear means SPACE is pushed
	bne +
	#CHANGE_STAGE StageCreateTerrain
+	rts


render:
	lda #$93
	sta $ffd2
	rts

text_title:
	.text 'PLANET LANDER V0', 0
text_hak:
	.text 'HIT SPACE (TWICE?) TO START', 0

.send section_CODE

.bend