#Author: lipska the kat

heap: heap.o
	ld -m elf_i386 heap.o -o heap.out

heap.o: heap.S
	gcc -m32 -c -g heap.S -o heap.o
	
clean:
	rm *.o *~  
