AS= lwasm --decb --pragma=condundefzero,nodollarlocal,noindex0tonone

all: gtw.dsk

gtw.zip: gtw.dsk README.TXT
	rm -f gtw.zip
	zip gtw.zip gtw.dsk README.TXT

gtw.dsk: gtw.bin
	rm -f gtw.dsk
	decb dskini gtw.dsk
	decb copy -r -2 -b gtw.bin gtw.dsk,GTW.BIN
	decb copy -lr -0 -a AUTOEXEC.BAS gtw.dsk,AUTOEXEC.BAS

gtw.bin: grfx.asm 
	$(AS) grfx.asm -o$@ -lgtw.lst -mgtw.map

clean:
	rm -f gtw.bin gtw.lst gtw.dsk gtw.bin
