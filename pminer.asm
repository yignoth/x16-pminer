;
; Planet Miner
;
; The s_xxxx.asm files are the different stages of the program.
; Currently there are:
;	V0:
;	* titlescreen = shows the title screen (very basic at the moment)
;	* lander = the actual land on planet game portion (still can't land yet)
;

set: .macro
	lda \2
	sta \1
.endm

CHANGE_STAGE: .macro
	#set MAIN.stage_changed, #1
	lda #<\1.jumpTable
	sta MAIN.stage_table
	lda #>\1.jumpTable
	sta MAIN.stage_table + 1
.endm

GAME_OVER: .macro
	lda #1
	sta MAIN.game_over
.endm

;
; Definitions
;
ISR_ADDR	= $0314
ROM_BANK	= $9f60


MAIN: .block

;
; Variables
;
.section section_ZP
	render_completed	.byte	?
	render_enabled		.byte	?
.send section_ZP

.section section_BSS
	old_isr			.word	?
	game_over		.byte	?
	stage_changed	.byte	?
	stage_table		.word	?
.send section_BSS

.section section_CODE
	.byte $0e, $08, $0a, $00, $9e, $20, $28, $32, $30, $36, $34, $29, $00, $00, $00	; start at $0810
;	.byte $01, $08, $0b, $08, $20, $03, $9e, $32, $30, $36, $31, $00, $00, $00		; Start at $080E



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		; switch to kernel bank (7)
;		jmp debug

		lda #7
		sta ROM_BANK

		; set random seed
		#Math.setRndSeed $001

		; save system interrupt address (to be restored at end of game)
		sei
		#set old_isr, ISR_ADDR
		#set old_isr+1, ISR_ADDR+1

		stz render_enabled						; so ISR will not do anything

		#set ISR_ADDR, #<mainIsr				; update to our ISR
		#set ISR_ADDR+1, #>mainIsr
		cli

		; start game until and run until done
		stz game_over
		#CHANGE_STAGE StageTitle
		jsr outerGameLoop

		; restore OLD ISR address
		sei
		#set ISR_ADDR, old_isr
		#set ISR_ADDR+1, old_isr+1
		cli

		; switch to basic bank (0)
		stz ROM_BANK

		rts

debug:
		#vaddr 1, 0
		stz Vera.IO_VERA.data0
		jmp *

;
; The Main Game loop
;
outerGameLoop:
		stz render_enabled					; disable stage rendering
		stz stage_changed					; clear stage changed

		lda stage_table+1					; copy init-H pointer
		sta INIT_PTR+2
		lda stage_table						; copy init-L pointer
		sta INIT_PTR+1
		clc									; add 3 to stage_table addr to point to jmp_update
		adc #3
		sta stage_table
		bcc +
		inc stage_table+1
+		lda stage_table+1					; copy update-H pointer
		sta UPDATE_PTR+2
		lda stage_table						; copy update-L pointer
		sta UPDATE_PTR+1
		clc									; add 3 to stage_table addr to point to jmp_render
		adc #3
		sta stage_table
		bcc +
		inc stage_table+1					; copy render-L pointer (since it's already in A)
+		sta RENDER_PTR+1
		lda stage_table+1					; copy render_H pointer
		sta RENDER_PTR+2

		INIT_PTR:
		jsr $0000							; call stage init code

gameLoop:
		stz render_completed				; clear rendering completed flag
		#set render_enabled, #1				; enable stage rendering

-		lda render_completed				; Wait for rendering to be completed
		beq -

		stz render_enabled					; disable stage rendering

		UPDATE_PTR:
		jsr $0000							; call stage update code

		lda stage_changed					; check if there is a pending stage change
		bne outerGameLoop					; yes, so change stage

		lda game_over						; check if game over
		beq gameLoop						; no, then continue game loop

		rts

;
; The Main ISR function
;
mainIsr:
		lda Vera.IO_VERA.isr	; Check if this was a VSYNC interrupt
		and #1 					; the vsync bit
		beq ++ 					; if vsync bit not set, skip to end

;		#set Vera.IO_VERA.isr, #$01	; clear VERA interrupt status	TODO: do we need this?

		lda render_enabled			; check if game is ready to process graphics
		beq +

		RENDER_PTR:
		jsr $0000					; call render the stage code

+		#set render_completed, #1	; set rendering completed (for VBlank ISR only)
+		jmp (old_isr)			; jump to finish kernel portion of interrupt (needed for JOY1)

.send section_CODE

.bend

;
; included libraries
;
.include "memmap.asm"
.include "const.asm"
.include "s_titlescreen.asm"
.include "s_create_terrain.asm"
.include "s_lander.asm"
.include "joystick.asm"
.include "vera.asm"
.include "math.asm"
.include "utils.asm"
