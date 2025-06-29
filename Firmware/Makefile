all: miniboot.rom miniboot.burn loadsd

miniboot.bin: miniboot.s
	m6811-elf-as -o miniboot.obj miniboot.s
	# relocate sections and dump binary
	m6811-elf-ld miniboot.obj -T miniboot.ld -o miniboot.elf
	m6811-elf-objcopy -O binary --gap-fill 0 miniboot.elf miniboot.bin

miniboot.rom: miniboot.bin
	dd if=miniboot.bin bs=16384 skip=3 >miniboot.tmp
	cat miniboot.tmp miniboot.tmp >miniboot.rom


loadsd.bin: loadsd.s
	m6811-elf-as -o loadsd.obj loadsd.s
	m6811-elf-objcopy --dump-section .text=loadsd.bin loadsd.obj

loadsd: loadsd.bin
	dd if=loadsd.bin bs=384 count=1 >loadsd

mkmini11: mkmini11.c

miniboot.burn: mkmini11 miniboot.rom
	./mkmini11 <miniboot.rom >miniboot.burn

clean:
	rm -f miniboot.rom miniboot.burn miniboot.tmp
	rm -f *~ *.obj *.elf *.bin mkmini11 loadsd
