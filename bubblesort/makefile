all:
	as --32 -g bubblesort.asm -o bubblesort.o
	ld -m elf_i386 -o bubblesort bubblesort.o

numcalc:
	as --32 -g numcalc.asm -o numcalc.o
	ld -m elf_i386 -o numcalc numcalc.o

clean:
	rm *.o *~  
