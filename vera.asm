;
; VERA Library
;
bpoke: .macro
		lda #\1
		sta \2
.endm
wpoke: .macro
		lda #<\1
		sta \2
		lda #>\1
		sta \2 + 1
.endm
lpoke: .macro
		lda #<\1
		sta \2
		lda #>\1
		sta \2 + 1
		lda #`\1
		sta \2 + 2
.endm
vaddr:	.macro			; increment, 20bit addr
		lda #<(\2)
		sta Vera.IO_VERA.addrL
		lda #>(\2)
		sta Vera.IO_VERA.addrM
		lda #`((\1 << 20) | \2)
		sta Vera.IO_VERA.addrH
.endm
vinc:	.macro
		lda Vera.IO_VERA.addrH
		and #$0f
		ora #(\1<<4)
		sta Vera.IO_VERA.addrH
.endm
vpoke0:	.macro
		lda #\1
		sta Vera.IO_VERA.data0
.endm
vwpoke0: .macro
		lda #<\1
		sta Vera.IO_VERA.data0
		lda #>\1
		sta Vera.IO_VERA.data0
.endm


Vera: .proc

; structures
S_IO: .struct
	addrL	.byte	?			; VERA_ADDR_L	LLLLLLLL: L=address bits 7-0
	addrM	.byte	?			; VERA_ADDR_M	MMMMMMMM: M=address bits 15-8
	addrH	.byte	?			; VERA_ADDR_H   IIIIHHHH: I=increment (0,1,2,4,..,16k), H=address bits 19-16
	data0	.byte	?			; VERA_DATA0
	data1	.byte	?			; VERA_DATA1
	ctrl	.byte	?			; VERA_CTRL		R------A: R=reset, A=data port (0=DATA1, 1=DATA2)
	ien		.byte	?			; VERA_IEN		----USLV: UART, Sprint_Collision, Line, VSync
	isr		.byte	?			; VERA_ISR		----USLV: UART, Sprint_Collision, Line, VSync
.ends

S_LAYER: .struct
	ctrl0		.byte	?
	ctrl1		.byte	?
	mapBase		.word	?
	tileBase	.word	?
	hScroll		.word	?
	vScroll		.word	?
.ends

.section section_IO_VERA
IO_VERA .dstruct S_IO
.send section_IO_VERA

.section section_ZP
	z0			.word	?
	z1			.word	?
.send section_ZP

.section section_BSS
.send section_BSS

SCREEN_MEM		= $00000		; start of screen memory
FONT_ASCII		= $1E800		; iso ascii font
FONT_UPETSCII	= $1F000		; PETSCII uppercase
FONT_LPETSCII	= $1F800		; PETSCII lowercase
DC_VIDEO		= $F0000		; video mode
PALETTE			= $F1000
L0_CTRL0		= $F2000		; layer 1 control port
L0_HSCROLL		= $F2006
L1_CTRL0		= $F3000		; layer 2 control port
SPRITE_REG		= $F4000
SPRITE_ATTS		= $F5000
AUDIO			= $F6000
SPI				= $F7000
UART			= $F8000


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Macros

;;;;;;;;;;;;;;;;;;;;;;;;;
; Sets the data port to DATA0 or DATA1
; veraSetDataPort <port> (0 or 1)
; Uses: A
setDataPort: .macro
		.if \1 < 0 || \1 > 1
			.error "Bad DataPort value: ", \1 , ", should be 0 or 1"
		.fi
		#bpoke \1, Vera.IO_VERA.ctrl
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;
; Sets the screen resolution
; veraSetScreenRes <W>, <H>
;	<W>: 640, 320, 160
;	<H>: 480, 240, 120
; Uses: A
setScreenRes:	.macro
		.if \1 != 640 && \1 != 320 && \1 != 160
			.error "veraSetScreenRes H=(",\1,") must be one of 640,320,160"
		.fi
		.if \2 != 480 && \2 != 240 && \2 != 120
			.error "veraSetScreenRes V=(",\2,") must be one of 480,240,120"
		.fi

		#vaddr 1, Vera.DC_VIDEO
		#vpoke0 %00000001			; set vga mode F----COO; O=Outmode (1=vga)
		#vpoke0 (\1 / 5)			; Hscale (128,64,32)
		#vpoke0 (\2 / 15)<<2		; Vscale (128,64,32)
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;
; Setup layer
; veraLayerSetup <layer> <mode> <tile/map-size> <map-base> <tile-base> <hscroll> <vscroll>
;	<layer> = layer 0 or 1
;	<mode> = MMM----E; M=mode 0-7, E=enable
;	<tile-map-size> = --HWhhww
;	<map-base> = 18 bit addr
;	<tile-base> = 18 bit addr
;	<hscroll> = 12 bit addr
;	<vscroll> = 12 bit addr
; Uses: A
layerSetup: .macro
		.if \1 == 0
			LAYER = Vera.L0_CTRL0
		.elsif \1 == 1
			LAYER = Vera.L1_CTRL0
		.else
			.error "veraLayerSetup Mode=(",\1,") must be 0,1"
		.fi

		vaddr 1, LAYER				; set layer address
		#vpoke0 \2					; set mode and enable layer
		.if \2 > 0
			#vpoke0 \3						; set tile/map size --HWhhww
			#vwpoke0 (\4 >> 2)				; set map base
			#vwpoke0 (\5 >> 2)				; set tile base
			#vwpoke0 \6						; set hscroll
			#vwpoke0 \7						; set vscroll
		.fi
.endm
	
;;;;;;;;;;;;;;;;;;;;;;;;;
; Sets <value> in last set VERA data port at current address
; veraSetData <value>
;	<value> = the value to store
; Uses: A
setData0:	.macro
		lda \1
		sta Vera.IO_VERA.data0
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;
; Fills a window with a character and color
; veraFillWindow V, X, Y, W, H, F, C
;	V = the baseMap VAddr address
;	MC= the number of map columns
;	X = the left column of the window
;	Y = the top row of the window
;	W = the width of the window
;	H = the height of the window
;	F = the fill character
;	C = the fill color
;
; NOTE: need to set VeraAddr to start of layer screen memory
;
; Uses: A, X, Y
fillWindow: .macro
		#vaddr 1, \1
		#bpoke \3, Vera.cw_col
		#bpoke \4, Vera.cw_row
		#bpoke \5, Vera.cw_width
		#bpoke \6, Vera.cw_height
		#bpoke \7, Vera.cw_char
		#bpoke \8, Vera.cw_color
		#bpoke (\2 - \5)<<1, Vera.cw_winc

		.if \2 == 32
			jsr Vera.AddCwRowColToVAddr32
		.elsif \2 == 64
			jsr Vera.AddCwRowColToVAddr64
		.elsif \2 == 128
			jsr Vera.AddCwRowColToVAddr128
		.elsif \2 == 256
			jsr Vera.AddCwRowColToVAddr256
		.fi
		jsr Vera.FillWindow
.endm

; Fills a single character on the screen
; fillCHar V, X, Y, F, C
;	V = the baseMap VAddr address
;	MC= the number of map columns
;	X = the left column of the window
;	Y = the top row of the window
;	F = the fill character
;	C = the fill color
fillChar: .macro
		#vaddr 1, \1
		#bpoke \3, Vera.cw_col
		#bpoke \4, Vera.cw_row
		#bpoke \5, Vera.cw_char
		#bpoke \6, Vera.cw_color

		.if \2 == 32
			jsr Vera.AddCwRowColToVAddr32
		.elsif \2 == 64
			jsr Vera.AddCwRowColToVAddr64
		.elsif \2 == 128
			jsr Vera.AddCwRowColToVAddr128
		.elsif \2 == 256
			jsr Vera.AddCwRowColToVAddr256
		.fi
		jsr Vera.FillChar
.endm

; \1 = CPU RAM data source location
; \2 = VERA RAM destination location
; \3 = number of bytes (DO NOT CALL WITH 0)
copyDataToVera: .macro
		#vaddr 1, \2		; set VERA address

		lda #<\1			; copy source address to z0
		sta Vera.z0
		lda #>\1
		sta Vera.z0+1

		lda #>\3
		sta Vera.z1			; store \3(hi) in z1
		ldx #<\3			; load \3(lo) into x
		beq +				; if zero then jump to decreasing \3(hi)

-		ldy #$00			; start y at 0 since VERA address increase goes by 1
-		lda (Vera.z0),y		; load A with source + y
		sta Vera.IO_VERA.data0		; store in data0
		iny
		dex
		bne -						; continue if more bytes to xfer

		inc Vera.z0+1		; increment src(hi) by 1

+		lda Vera.z1			; load A with \3(hi)
		beq +				; if zero then we are done
		dec Vera.z1			; decrease \3(hi)
		bra	--				; goto -
+
.endm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Subroutines
.section section_CODE
cw_layer		.byte	0
cw_col			.byte	0
cw_row			.byte	0
cw_width		.byte	0
cw_height		.byte	0
cw_char			.byte	0
cw_color		.byte	0
cw_winc			.byte	0
cw_rinc			.byte	0

;;;;;;;;;;;;;;;;;;;;;;;;;
; FillWindow: Fills a window on the current screen starting at current
; screen position.
;
; Req: 
;		cw_col, cw_row = row/col of start of fill
;		cw_width, cw_height = widht/height of fill window
;		cw_char, cw_color = color and character to fill
;		cw_winc, num bytes from end on window to start of next row/col.
;
; Uses: A, X, Y
FillWindow:
		ldy cw_height						; height counter
-		ldx cw_width						; width counter
-		#setData0 cw_char					; store char
		#setData0 cw_color					; store color
		dex					; dec col count
		bne -
		dey					; dec row count
		beq +
		lda cw_winc			; skip to next to
		jsr Add_A_ToVAddr
		bra --
+		rts

;;;;;;;;;;;;;;;;;;;;;;;;;
; FillChar: Fills a single character on the current screen starting at current
; screen position.
;
; Req: 
;		cw_col, cw_row = row/col of start of fill
;		cw_char, cw_color = color and character to fill
;
; Uses: A, X, Y
FillChar:
		#setData0 cw_char					; store char
		#setData0 cw_color					; store color
		rts

;;;;;;;;;;;;;;;;;;;;;;;;;
; Computes screen starting address for window with default INC=1
;
; cw_col, cw_row = starting row, 
;
; Uses: A, Y
AddCwRowColToVAddr32:		; map width of 32 (64 bytes row increment)
		lda cw_row
		asl
		asl
		asl
		asl
		asl
		asl
		clc
		adc Vera.IO_VERA.addrL
		sta Vera.IO_VERA.addrL
		bcc +
		inc Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		lda cw_row
		lsr
		lsr
		clc
		adc Vera.IO_VERA.addrM
		sta Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		jmp AddCwColToVAddr

AddCwRowColToVAddr64:		; map width of 64 (128 bytes row increment)
		lda cw_row
		lsr
		bcc ++
		lda #$80
		clc
		adc Vera.IO_VERA.addrL
		sta Vera.IO_VERA.addrL
		bcc +
		inc Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		lda cw_row
		lsr
		clc
+		adc Vera.IO_VERA.addrM
		sta Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		jmp AddCwColToVAddr

AddCwRowColToVAddr128:		; map width of 128 (256 byte row increment)
		lda cw_row
		clc
		adc Vera.IO_VERA.addrM
		sta Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		jmp AddCwColToVAddr

AddCwRowColToVAddr256:		; map width of 256 (512 byte row increment)
		lda cw_row
		clc
		adc Vera.IO_VERA.addrM
		sta Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		lda cw_row
		clc
		adc Vera.IO_VERA.addrM
		sta Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		; fall through to AddCwColToVAddr

;;;;;;;;;;;;;;;;;;;;;;;;
; Adds A to VERA Address
; A contains the value to add
AddCwColToVAddr:
		lda cw_col
		asl									; *2 for (char,byte)
Add_A_ToVAddr:
		clc
		adc Vera.IO_VERA.addrL
		sta Vera.IO_VERA.addrL
		bcc +
		lda Vera.IO_VERA.addrM
		adc #0			; carry is already set
		sta Vera.IO_VERA.addrM
		bcc +
		inc Vera.IO_VERA.addrH
+		rts

.send section_CODE

.pend
