;
; Prints Hello World to a bitmap screen
;

; TODO
; $FFE4 = get keyboard input:
;	- jsr $ffe4
;	  cmp #0
;	  beq -


.section section_ZP
hScrollDelay		.byte		?
hScrollOff			.byte		?
hScrollPos			.byte		?
.send section_ZP

.section section_BSS
oldISR		.word		?
mapChar		.byte		?
rndIdx		.byte		?
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
		sta rndIdx
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
		#Vera.layerSetup 0, %01100001, $00, L0_MAP_BASE, Vera.FONT_LPETSCII, $0000, $0000
		; setup layer 1: mode=3/e=1, map=64x32, map=$4000, tile=font0, h/v-scroll=0
		#Vera.layerSetup 1, %01100001, $01, L1_MAP_BASE, Vera.FONT_LPETSCII, $0000, $0000

		; copy the palette data over to VERA
		#Vera.copyDataToVera palette, Vera.PALETTE, 512
		; copy the 'font' data into low PETSCII location only copying 64 characters
		#Vera.copyDataToVera font, Vera.FONT_LPETSCII, 64*4*8

		; fill window: mapBase, numMapCols, c, r, w, h, chr, clr
		#Vera.fillWindow L0_MAP_BASE, 32, 0, 0, 32, 32, $20, $10		; fill layer0 with dots
		#Vera.fillWindow L1_MAP_BASE, 64, 1, 1, 28, 28, 0, 0			; HUD clear viewport to see layer0
		#Vera.fillWindow L1_MAP_BASE, 64, 0, 0, 40, 1, 3, 0				; HUD top H line
		#Vera.fillWindow L1_MAP_BASE, 64, 0, 29, 40, 1, 3, 0			; HUD bottom H line
		#Vera.fillWindow L1_MAP_BASE, 64, 0, 0, 1, 30, 4, 0				; HUD left V line
		#Vera.fillWindow L1_MAP_BASE, 64, 29, 0, 1, 30, 4, 0			; HUD mid V line
		#Vera.fillWindow L1_MAP_BASE, 64, 39, 0, 1, 30, 4, 0			; HUD right V line
		#Vera.fillWindow L1_MAP_BASE, 64, 30, 1, 9, 9, 1, 0				; HUD smallmap text area fill
		#Vera.fillWindow L1_MAP_BASE, 64, 29, 9, 11, 1, 3, 0			; HUD smallmap separator
		#Vera.fillChar L1_MAP_BASE, 64, 0, 0, 5, 0						; HUD top left corner
		#Vera.fillChar L1_MAP_BASE, 64, 29, 0, 9, 0						; HUD top mid T
		#Vera.fillChar L1_MAP_BASE, 64, 39, 0, 6, 0						; HUD top right corner
		#Vera.fillChar L1_MAP_BASE, 64, 0, 29, 7, 0						; HUD bot left corner
		#Vera.fillChar L1_MAP_BASE, 64, 29, 29, 10, 0					; HUD bot mid T
		#Vera.fillChar L1_MAP_BASE, 64, 39, 29, 8, 0					; HUD bot right corner
		#Vera.fillChar L1_MAP_BASE, 64, 29, 9, 11, 0					; HUD smallmap left T
		#Vera.fillChar L1_MAP_BASE, 64, 39, 9, 12, 0					; HUD smallmap right T
		#Vera.fillWindow L1_MAP_BASE, 64, 30, 10, 9, 19, 2, 0			; HUD right text area fill
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

		; clear next column with FillWindow
		#bpoke 1, Vera.cw_row
		#bpoke 1, Vera.cw_width
		#bpoke 28, Vera.cw_height
		#bpoke $20, Vera.cw_char				; clear/blank char
		#bpoke $10, Vera.cw_color
		#bpoke (32 - 1)<<1, Vera.cw_winc

		lda hScrollPos							; set column to current hscroll col
		sta Vera.cw_col

		#vaddr 1, L0_MAP_BASE					; fill with blanks
		jsr Vera.AddCwRowColToVAddr32
		jsr Vera.FillWindow

		; fill next column with terrain
		#bpoke $21, Vera.cw_char				; change to terrain character

		inc rndIdx								; inc random table index
		ldx rndIdx
		lda rndTable,x						; get random table value
		and #$0f
		sta Vera.cw_height
		eor #$ff								; make negative
		clc
		adc #30									; add 28+1+1 (+1 neg +1 starting row) (height of column)
		sta Vera.cw_row

	#bpoke $10, Vera.cw_color

		#vaddr 1, L0_MAP_BASE
		jsr Vera.AddCwRowColToVAddr32			; draw terrain
		jsr Vera.FillWindow

		; increase HScroll column position
		lda hScrollPos
		ina
		and #$1f
		sta hScrollPos

isr_done:
		ply
		plx
		pla
		rti
		;jmp oldISR				; jump to old ISR

palette:
.binary "res/palette.bin"
font:
.binary "res/font-hud.bin"
rndTable:
	.byte		2,2,2,2,5,3,6,9,10,5,1,7,5,7,4,1,7,4,10,10,5,6,1,8,6,4,10,8,1,1,8,4,3,5,6,3,1,5
	.byte		6,7,1,2,1,4,7,7,7,7,10,9,5,5,3,5,2,8,3,5,4,5,10,6,9,10,5,9,8,7,7,2,9,10,1,3,7,10
	.byte		8,4,3,1,1,1,8,7,7,2,3,2,3,7,4,1,9,4,8,10,2,3,10,8,1,1,8,1,9,8,8,7,2,6,6,1,6,10,1
	.byte		6,9,3,9,4,3,8,2,10,7,9,4,9,8,10,7,7,10,8,2,10,1,10,5,1,10,7,2,5,6,9,3,2,10,6,1,10
	.byte		8,7,2,7,1,5,5,9,5,4,6,2,2,3,2,5,5,5,6,10,9,9,10,5,3,7,1,2,8,3,7,8,2,9,2,2,7,10,1,2
	.byte		6,8,8,6,1,2,1,8,1,3,3,10,9,2,2,9,10,2,9,10,3,6,10,4,8,4,8,9,7,3,7,4,3,9,6,9,8,4,8
	.byte		10,8,9,8,1,3,3,2,3,9,5,9,6,4,2,3,5,7,3,4,1,6,10,8,2

;#include "debug.asm"
.send section_CODE

;
; included libraries
;
.include "vera.asm"
.include "memmap.asm"
