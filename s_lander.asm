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

GETKEY		= $FFE4


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Vars
;
.section section_ZP
	btmp				.byte		?
	wtmp				.word		?
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

; vars
hScrollValue		.byte		?
hScrollPos			.byte		?
flameEnabled		.byte		?
landerXPos			.word		?			; bits 12-3 (are terrain pos), bit 2-0 (scroll pos)
landerYPos			.word		?
terrainHeight		.byte		?
terrainChar			.byte		?
curr_height			.byte		?
vera_addr			.long		?


update: .proc
		; main game loop
		jsr GETJOY				; process joystick input
		lda JOY1				; read joystick value
		tax
		bit #JOY_UP				; bit 3 clear means up arrow is pushed
		bne +
		lda #$08				; enable flame sprite
		sta flameEnabled
		bra ++
+		stz flameEnabled
+
		txa
		bit #JOY_RIGHT
		bne +
		lda landerXPos
		clc
		adc #8
		sta landerXPos
		bcc +
		;inc landerXPos
		;bne +
		inc landerXPos+1
+
		txa
		bit #JOY_LEFT
		bne +
		lda landerXPos
		sec
		sbc #8
		sta landerXPos
		cmp #$f8
		blt +
		;dea
		;sta landerXPos
		;cmp #$ff
		;bne +
		dec landerXPos+1
+
		rts
.pend

render: .proc
		; show flame sprite if enabled
		#vaddr 1, VERA_ENABLE_FLAME
		lda flameEnabled
		#vpoke0A

		; get the terrain height address (landerXPos >> 3 is the terrain map position)
		lda landerXPos+1
		sta btmp
		lda landerXPos
		lsr btmp						; divide by 8 (to get scroll value)
		ror
		lsr btmp
		ror
		lsr btmp
		ror
		sta hScrollValue				; save intermediate 8 bit scroll value

		lsr btmp						; divide by 8 more to get terrain map position
		ror
		lsr btmp
		ror
		lsr btmp
		ror
		sta hScrollPos					; save lower byte of Xpos in hScrollPos

		clc								; add terrain height addr
		adc #<TERRAIN_HEIGHT_ADDR
		sta wtmp						; store
		lda btmp
+		adc #>TERRAIN_HEIGHT_ADDR
		sta wtmp+1

		; get height from current terrain height address
		lda (wtmp)
		sta terrainHeight

		; add address for terrain character
		lda wtmp
		clc
		adc #<TERRAIN_MAP_WIDTH
		sta wtmp
		lda wtmp+1
		adc #>TERRAIN_MAP_WIDTH
		sta wtmp+1

		; get terrain character
		lda (wtmp)
		sta terrainChar

		#vaddr 0, Vera.L0_HSCROLL				; set VERA scroll counter
		lda hScrollValue
		sta Vera.IO_VERA.data0

		; get the off map fill position
		lda hScrollPos						; get x-pos scroll byte
		clc
		adc #30								; add 30 to write in invisible column
		and #$1f							; and to 0-31 (map size is 32)
		asl									; 2 bytes per tile
		
		; set vera address to L0 base + current fill column (row=0, col=hScrollPos)
		clc
		adc #<L0_MAP_BASE				; get lo byte of vera addr
		sta Vera.IO_VERA.addrL			; store VaddrL
		sta vera_addr
		lda #>L0_MAP_BASE
		adc #0
		sta vera_addr+1
		sta Vera.IO_VERA.addrM
		lda #`L0_MAP_BASE
		adc #0
		ora #$70						; set VADDR increment to 7 = 64 bytes
		sta vera_addr+2
		sta Vera.IO_VERA.addrH

		; now set vera1 address
		#Vera.setDataPort 1
		clc
		lda vera_addr
		adc #1
		sta Vera.IO_VERA.addrL
		lda vera_addr+1
		adc #0
		sta Vera.IO_VERA.addrM
		lda vera_addr+2
		adc #0
		sta Vera.IO_VERA.addrH
		#Vera.setDataPort 0

		; Initialize drawing loop counter
		lda #30
		sta btmp							; fill 30 rows in current column

		; XXXXXXXXXXXX landerYPos also needs to be a word because of scroll (3 bytes)
		lda landerYPos						; start 7 rows above lander position
		clc
		adc #7
		sta curr_height

		; Main draw loop
loop1:
		lda curr_height						; compare curr_height to terrain height
		cmp terrainHeight
		beq out1							; if equal (goto draw char)
		blt loop2							; else if we are below it goto loop2

		lda #BRICK_NONE
		sta Vera.IO_VERA.data0
		lda #$10
		sta Vera.IO_VERA.data1

		dec btmp
		beq loopDone
		dec curr_height
		bra loop1

out1:
		lda terrainChar
		sta Vera.IO_VERA.data0
		lda #$10
		sta Vera.IO_VERA.data1

		dec btmp
		beq loopDone
		dec curr_height

loop2:
;		lda curr_height
;		cmp ORE_HEIGHT
;		bne +
		lda #BRICK_SOLID
;		bra ++
;+		lda #BRICK_ORE
;+
		sta Vera.IO_VERA.data0
		lda #$10
		sta Vera.IO_VERA.data1

		dec btmp
		beq loopDone
		dec curr_height
		bra loop2

loopDone:
renderDone:
		rts
.pend


init: .proc
		stz hScrollValue			; init hscroll value
		stz flameEnabled		; no lander flame enabled

		stz landerXPos			; lander initial x position
		stz landerXPos+1
		lda #22
		sta landerYPos			; lander initial y position

		lda #29					; set initial hscroll position (on Layer0 Map)
		sta hScrollPos

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
		#vwpoke0 108						; x = 108 (middle of hud window)
		#vwpoke0 64							; y = 64 above middle
		#vpoke0 %00001000					; no-collision, zdepth=2, no-flip
		#vpoke0 %10100010					; 32x32 sprite, pal-off=32
		; setup lander_flame sprite
		#vpoke0 ((SPRITE_LANDER_FLAME & $1fff) >> 5)	; bits 12-5 of bitmap address
		#vpoke0 (SPRITE_LANDER_FLAME >> 13)		; 4bpp + bits 16:13 of bmap addr
		#vwpoke0 108						; x = 108 (middle of hud window)
		#vwpoke0 64							; y = 64 above middle
		#vpoke0 %00000000					; no-collision, zdepth=2, no-flip
		#vpoke0 %10100010					; 32x32 sprite, pal-off=32

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