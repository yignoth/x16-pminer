;
; Prints Hello World to a bitmap screen
;

.section section_ZP
hScrollDelay		.byte		?
hScrollOff			.byte		?
hScrollPos			.byte		?
.send section_ZP

.section section_BSS
oldISR:		.word		?
mapChar		.byte		?
.send section_BSS

.section section_CODE
	.byte $0e, $08, $0a, $00, $9e, $20, $28, $32, $30, $36, $34, $29, $00, $00, $00		; Start at $0810

ISR_ADDR	= $0314
L0_MAP_BASE	= $00000
L1_MAP_BASE	= $04000
HUD_OUT_CLR	= $8B
HUD_TXT_CLR = $61
HSCROLL_DELAY_RESET	= 1		; 1 second for every 60 delay

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		jsr titleScreen
		jsr initGame

		jsr init

		jmp *
		;rts

init:
		sei			; disable interrupts

		;save previous interrupt location
		lda ISR_ADDR
		sta oldISR
		lda ISR_ADDR+1
		sta oldISR+1

		lda #<myIsr				; hook to myisr
		sta ISR_ADDR
		lda #>myIsr
		sta ISR_ADDR+1

		lda #$00				; init hscroll value
		sta hScrollOff
		sta mapChar
		lda #30
		sta hScrollPos
		lda #HSCROLL_DELAY_RESET		; scroll delay
		sta hScrollDelay

		cli			; enable interrupts
		rts


titleScreen:
		rts

initGame:
		; most everytrhing is done on data port 0
		#Vera.setDataPort 0

		; set screen to 320x240
		#Vera.setScreenRes 320,240

		; setup layer 0: mode=0/e=1, map=32x32, map=$0000, tile=font0, h/v-scroll=0
		#Vera.layerSetup 0, $01, $00, L0_MAP_BASE, Vera.FONT_UPETSCII, $0000, $0000
		; setup layer 1: mode=0/e=1, map=64x32, map=$4000, tile=font0, h/v-scroll=0
		#Vera.layerSetup 1, $01, $01, L1_MAP_BASE, Vera.FONT_UPETSCII, $0000, $0000


		; fill window: mapBase, numMapCols, c, r, w, h, chr, clr
		#Vera.fillWindow L0_MAP_BASE, 32, 0, 0, 32, 32, $2e, $04
		#Vera.fillWindow L1_MAP_BASE, 64, 1, 1, 28, 28, $20, $00
		#Vera.fillWindow L1_MAP_BASE, 64, 0, 0, 40, 1, $40, HUD_OUT_CLR
		#Vera.fillWindow L1_MAP_BASE, 64, 0, 29, 40, 1, $40, HUD_OUT_CLR
		#Vera.fillWindow L1_MAP_BASE, 64, 0, 0, 1, 30, $42, HUD_OUT_CLR
		#Vera.fillWindow L1_MAP_BASE, 64, 29, 0, 1, 30, $42, HUD_OUT_CLR
		#Vera.fillWindow L1_MAP_BASE, 64, 39, 0, 1, 30, $42, HUD_OUT_CLR
		#Vera.fillWindow L1_MAP_BASE, 64, 30, 1, 9, 28, $20, HUD_TXT_CLR
		rts

myIsr:
		lda #$01				; clear VERA interrupt status
		sta Vera.IO_VERA.isr

		dec hScrollDelay		; decrease scroll delay
		bne isr_done
		lda #HSCROLL_DELAY_RESET	; reset if at zero
		sta hScrollDelay

		#vaddr 0, Vera.L0_HSCROLL
		inc Vera.IO_VERA.data0

		lda hScrollOff
		ina
		cmp #8
		bne +
		lda #0
+		sta hScrollOff
		bne isr_done

		; setup for FillWindow routine
		#vaddr 1, L0_MAP_BASE
		#bpoke 1, Vera.cw_row
		#bpoke 1, Vera.cw_width
		#bpoke 28, Vera.cw_height
		#bpoke 1, Vera.cw_color
		#bpoke (32 - 1)<<1, Vera.cw_winc

		; column pos
		lda hScrollPos
		sta Vera.cw_col
		ina
		and #$1f
		sta hScrollPos

		; fill with mapChar
		lda mapChar
		sta Vera.cw_char
		inc mapChar

		; do fill
		jsr Vera.AddCwRowColToVAddr32
		jsr Vera.FillWindow

isr_done:
		ply
		plx
		pla
		rti
		;jmp oldISR				; jump to old ISR

;#include "debug.asm"
.send section_CODE

;
; included libraries
;
.include "vera.asm"
.include "memmap.asm"

