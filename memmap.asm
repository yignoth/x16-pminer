;
; Memory map
;
*	= $04
.dsection section_ZP
.cerror * >= $90, "To many ZP variables"

*	= $0400
.dsection section_BSS
.cerror * >= $0800, "To many BSS variables"

*	= $0801
.dsection section_CODE
.cerror * >= $9f00, "CODE size is to big"
.dsection section_DATA
.cerror * >= $9f00, "DATA size is to big"

*	= $9f00
.dsection section_IO_AUDIO
*	= $9f20
.dsection section_IO_VERA
*	= $9f60
.dsection section_IO_VIA1
*	= $9f70
.dsection section_IO_VIA2
*	= $9f80
.dsection section_IO_RTC

*	= $A000
.dsection section_HIMEM
.cerror * > $bfff, "HIMEM data size to big"