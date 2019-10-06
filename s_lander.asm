;
; Template
;



StageLander: .block

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Definitions
;
L0_MAP_BASE	= $00000
L1_MAP_BASE	= $04000
SPRITE_START = $1E000
SPRITE_LANDER = SPRITE_START
SPRITE_LANDER_FLAME = (SPRITE_LANDER+512)
VERA_ENABLE_FLAME = (Vera.SPRITE_ATTS + 8 + 6)
HUD_OUT_CLR	= $8B
HUD_TXT_CLR = $61
HSCROLL_DELAY_RESET	= 1		; 1 second for every 60 delay

GETKEY		= $FFE4


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Vars
;
.section section_ZP
.send section_ZP

.section section_BSS
hScrollDelay	.byte		?
hScrollOff		.byte		?
hScrollPos		.byte		?
flameEnabled	.byte		?
mapChar			.byte		?
lastTerrHeight	.byte		?
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

update: .proc
		; main game loop
		jsr GETJOY				; process joystick input
		lda JOY1				; read joystick value
		bit #$08				; bit 3 clear means up arrow is pushed
		bne +
		lda #$08				; enable flame sprite
		sta flameEnabled
		rts
+		stz flameEnabled
		rts
.pend

render: .proc
		dec hScrollDelay			; decrease scroll delay
		bne renderDone
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
		bne renderDone

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
		#bpoke $10, Vera.cw_color
		
		; this section computes random 
		jsr GetRandHeight
		ina									; height must be 1-16 (not 0 to 15)
		sta Vera.cw_height					; store as height of table
		eor #$ff							; make negative
		clc
		adc #30								; add 28+1+1 (+1 neg +1 starting row) (height of column)
		sta Vera.cw_row

		#vaddr 1, L0_MAP_BASE
		jsr Vera.AddCwRowColToVAddr32			; draw terrain
		jsr Vera.FillWindow

		; increase HScroll column position
		lda hScrollPos
		ina
		and #$1f
		sta hScrollPos

		; show flame sprite if enabled
		#vaddr 1, VERA_ENABLE_FLAME
		lda flameEnabled
		#vpoke0A

renderDone:
		rts
.pend


init: .proc
		stz hScrollOff			; init hscroll value
		stz mapChar				; zero mapChar\
		stz flameEnabled		; no lander flame enabled

		lda #8
		sta lastTerrHeight

		lda #30					; set initial hscroll position (on Layer0 Map)
		sta hScrollPos
		lda #HSCROLL_DELAY_RESET		; scroll delay
		sta hScrollDelay

		; most everytrhing is done on data port 0
		#Vera.setDataPort 0

		; set screen to 320x240
		#Vera.setScreenRes 320,240

		; setup layer 0: mode=0/e=1, map=32x32, map=$0000, tile=font0, h/v-scroll=0
		#Vera.layerSetup 0, %01100001, $00, L0_MAP_BASE, Vera.FONT_LPETSCII, $0000, $0000
		; setup layer 1: mode=3/e=1, map=64x32, map=$4000, tile=font0, h/v-scroll=0
		#Vera.layerSetup 1, %01100001, $01, L1_MAP_BASE, Vera.FONT_LPETSCII, $0000, $0000
		; enable sprites
		#vaddr 1, Vera.SPRITE_REG
		#vpoke0 1

		; copy the palette data over to VERA
		#Vera.copyDataToVera palette, Vera.PALETTE, 512
		; copy the 'font' data into low PETSCII location only copying 64 characters
		#Vera.copyDataToVera font, Vera.FONT_LPETSCII, 64*4*8
		; copy sprite data to vera
		#Vera.copyDataToVera s_lander, SPRITE_LANDER, 512
		#Vera.copyDataToVera s_lander_flame, SPRITE_LANDER_FLAME, 512

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

		; setup lander sprite
		#vaddr 1, Vera.SPRITE_ATTS
		#vpoke0 ((SPRITE_LANDER & $1fff) >> 5)	; bits 12-5 of bitmap address
		#vpoke0 (SPRITE_LANDER >> 13)		; 4bpp + bits 16:13 of bmap addr
		#vwpoke0 104						; x = 104 (middle of hud window)
		#vwpoke0 24							; y = 24 near top
		#vpoke0 %00001000					; no-collision, zdepth=2, no-flip
		#vpoke0 %10100010					; 32x32 sprite, pal-off=32
		; setup lander_flame sprite
		#vpoke0 ((SPRITE_LANDER_FLAME & $1fff) >> 5)	; bits 12-5 of bitmap address
		#vpoke0 (SPRITE_LANDER_FLAME >> 13)		; 4bpp + bits 16:13 of bmap addr
		#vwpoke0 104						; x = 104 (middle of hud window)
		#vwpoke0 24							; y = 24 near top
		#vpoke0 %00000000					; no-collision, zdepth=2, no-flip
		#vpoke0 %10100010					; 32x32 sprite, pal-off=32

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
		adc lastTerrHeight					; add to height
		bpl +
		lda #$00							; min of zero allowed
		bra r_fin
+		cmp #$10							; max of 15 allowed
		bcc r_fin
		lda #$0f							; clip at 15
r_fin:	sta lastTerrHeight
		rts
.pend

.send section_CODE

.section section_DATA
palette:
.binary "res/palette.bin"
font:
.binary "res/font-hud.bin"
s_lander:
.binary "res/s_lander.bin"
s_lander_flame:
.binary "res/s_lander_flame.bin"
.send section_DATA

.bend