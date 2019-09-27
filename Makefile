# -C = Case sensitive labels
# -B = automatic bxx *+3 jmpo $xxxx

EMUDIR = ../../../x16emu

JTOOLS=../../../tools/java

FILES=pminer.asm\
	memmap.asm\
	vera.asm

ASSETS=res/font-hud.bin\
	res/palette.bin

test.prg: $(FILES) $(ASSETS)
	64tass -C -B --line-numbers --verbose-list --tab-size=4 --m65c02 -L pminer.lst -o pminer.prg pminer.asm
	cp pminer.prg $(EMUDIR)/PMINER.PRG
	cp res/*.bin $(EMUDIR)/res/

res/font-hud.bin: res/font-hud.png
	$(JTOOLS)/png2Font res/font-hud.png 0 res/font-hud.bin

res/palette.bin: res/palette.gpl
	$(JTOOLS)/pal2Bin res/palette.gpl res/palette.bin
