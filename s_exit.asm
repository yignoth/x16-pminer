;
; Template
;

StageExit: .block

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
	; disable layer 1
	#Vera.layerSetup 1, $00, $01, L1_MAP_BASE, Vera.FONT_LPETSCII, $0000, $0000
	
	lda #1
	sta MAIN.game_over
	rts


update:
	lda #1
	sta MAIN.game_over
	rts


render:
	lda #1
	sta MAIN.game_over
	rts


.send section_CODE

.bend