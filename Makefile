# -C = Case sensitive labels
# -B = automatic bxx *+3 jmpo $xxxx

EMUDIR = ../../../x16emu

test.prg: pminer.asm \
		memmap.asm \
		vera.asm
	64tass -C -B --line-numbers --tab-size=4 --m65c02 -L pminer.lst -o pminer.prg pminer.asm
	cp pminer.prg $(EMUDIR)/PMINER.PRG
	cp res/*.bin $(EMUDIR)/res/

