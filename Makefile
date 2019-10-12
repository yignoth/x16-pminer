# -C = Case sensitive labels
# -B = automatic bxx *+3 jmpo $xxxx

EMUDIR = ../../../x16emu

JTOOLS=../../../tools/java

FILES=\
	const.asm\
	pminer.asm\
	s_titlescreen.asm\
	s_create_terrain.asm\
	s_lander.asm\
	s_exit.asm\
	joystick.asm\
	vera.asm\
	math.asm\
	utils.asm\
	memmap.asm

ASSETS=\
	res/font-hud.bin\
	res/palette.bin\
	res/s_lander.bin\
	res/s_lander_flame.bin

test.prg: $(FILES) $(ASSETS)
	64tass -Wall -C -B --line-numbers --verbose-list --tab-size=4 --m65c02 -L pminer.lst -o PMINER.PRG pminer.asm
	cp PMINER.PRG $(EMUDIR)/PMINER.PRG
	cp res/*.bin $(EMUDIR)/res/

res/font-hud.bin: res/font-hud.png
	$(JTOOLS)/png2Font $< 0 $@

res/palette.bin: res/palette.gpl
	$(JTOOLS)/pal12Bit $< res/palette12bit.gpl
	$(JTOOLS)/pal2Bin res/palette12bit.gpl $@

res/s_lander.bin: res/s_lander.png
	$(JTOOLS)/png2Sprite $< 4 $@

res/s_lander_flame.bin: res/s_lander_flame.png
	$(JTOOLS)/png2Sprite $< 4 $@
