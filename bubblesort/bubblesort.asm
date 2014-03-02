.section .data

.section .bss

.equ BUFSIZE, 500

.lcomm SORT_BUFFER, BUFSIZE
.lcomm PRINT_BUFFER, BUFSIZE

.section .text

.globl _start
_start:

pushl %ebp
movl  %esp, %ebp

movl 4(%ebp), %eax						# get argc
decl %eax

cmpl $0, %eax							# if there are no args on
jle end_processing						# the stack, exit

movl 12(%ebp), %ebx						# get a pointer to the argument stack
movl $0, %esi							# so use the source index
										
.equ BASE, 0x0A
.equ STDOUT, 1
.equ SYS_WRITE, 4
.equ LINUX_SYSCALL, 0x80

#------------------------------------
# fetch the arguments from the stack.
# Convert the characters in the digit
# string to integers and push them 
# back on the stack
#------------------------------------ 
	 									
pushl $-1								# flag the end of the input

get_chars:
    
    cmpl $0, %eax 						# check argc
    je end_input						# move on when we've processed the args
    
	movb (%ebx, %esi, 1), %dl			# get a character from the stack
										# and put it in %dl
    
    incl %esi							# inc source index
	
	cmpl $0, %edx						# check for null terminator
	je terminator_found
	jmp no_terminator
	
	terminator_found:					
    decl %eax							# decrease the arg count
    pushl $-2							# terminate this sequence with -2
    jmp get_chars						# get next char
	
	no_terminator:
	subb $0x30, %dl						# convert to digit
	
	no_convert:
	movzbl %dl, %edx					# 0 fill %edx
	pushl %edx							# place digit on the stack
		
	jmp get_chars
	end_input:
	jmp convert

	
#---------------------------------
# input 123 4 5678
# stack -2 8765 -2 4 -2 321 -1
#---------------------------------

#---------------------------------
# convert each sequence into
# integers and store them in
# 32 bit words in the input buffer
# all registers available
#---------------------------------

convert:

movl $0, %edi								# destination
popl %ebx									# lose first null

movl $1, %ecx	 							# counter
movl $0, %ebx   							# current digit
movl $0, %eax	 							# accumulator					
movl $0, %esi	 							# spare

movl $SORT_BUFFER, %edx						# integer destination buffer

movl $0, %edi	 							# dest index

calculate_ints:
    popl %ebx								# current digit in %edx
    cmpl $-2, %ebx							# end of sequence
    je store_result				
    cmpl $-1, %ebx							# end of input
    je store_result
    movl %ecx, %esi							# copy the counter into the spare register 
    imul %ebx, %esi     					# multiply the digit by the spare
    addl %esi, %eax     					# add result to accumulator
    imul $BASE, %ecx						# multiply the base by the counter
    jmp calculate_ints 
    
    store_result:												        
	movl %eax, (%edx, %edi, 4)				# result in eax
    incl %edi								# inc destination counter
	movl $0, %eax							# clear the accumulator
	movl $1, %ecx							# clear the counter
	cmpl $-1, %ebx							# if end of input goto sort
    je sort							
	jmp calculate_ints	
	
#----------------------------
# sort the integers in situ	
# in the sort buffer
#---------------------------		
	
sort:
    
    movl $0, %esi							# just so we don't bug out first iteration
    movl $1, %edi							# ditto
	
	reset_index:
	cmpl %edi, %esi							# if the count and edi are the same (0)
											# it means we have completed one iteration
											# without any swaps so print result
	je int_to_ascii	
							
	movl 4(%ebp), %edi						# get argc 
	subl $2, %edi							# set up index
	movl %edi, %esi							

	compare:
	cmpl $0, %edi							# we have reached the end of this iteration
	je reset_index							# so start again
											
	movl (%edx, %edi, 4), %ebx 				# move a number into ebx
	decl %edi								# decrease index
	movl (%edx, %edi, 4), %ecx				# move the next number into ecx
	cmpl %ebx, %ecx						    # compare and jump
	jl swap	
	decl %esi								# decrease the 'not swapped' count						
	jmp compare								
	
	swap:									# swap the two numbers in situ
	incl %edi
	movl %ecx, (%edx, %edi, 4)				
	decl %edi
	movl %ebx, (%edx, %edi, 4)									
	jmp compare								# keep going
	
int_to_ascii:
#------------------------------------------
# The need to do some division apparently
# reqires the use of some implied registers
# so move things around accordingly
#------------------------------------------

	movl $SORT_BUFFER, %ebx					# source of sorted integers
    movl $0, %esi							# set the read index
    
    movl 4(%ebp), %ecx						# get argc
    decl %ecx								# ignore progname
    
    movl $BASE, %edi						# divisor base 10
    
    pushl $-1								# indicate end of input
    
    conversion_loop:
    cmpl $0, %ecx
    je print								# finished converting so print
    
    movl (%ebx, %esi, 4), %eax				# move an integer into %eax
    incl %esi								# increment the source index
    decl %ecx								# decrease arg count
    
    converting:
											# Division is actually performed on the
											# combined %edx:%eax register, so first
	movl $0, %edx							# clear out %edx
	
											# Divide %edx:%eax (which are implied) by 10.
											# Store the quotient in %eax and the remainder
	divl %edi								# in %edx (both of which are implied).
	
	addl $0x30, %edx						# convert to character
	pushl %edx								# push char on the stack
	
	cmpl $0, %eax							# finished this integer
	je pushcrlf
	
	jmp converting
	
	pushcrlf:								# push cr/lf onto the stack
	pushl $0x0a								# lf
	pushl $0x0d								# cr
	je conversion_loop

print:
#-------------------------------------
# pop all the characters off the stack
# and into a buffer ready to be 
# written to standard out
#-------------------------------------

	movl $PRINT_BUFFER, %ebx
	movl $0, %esi
	
	# lose the first cr/lf
	popl %eax
	popl %eax
	
	pop_loop:
	popl %eax
	cmpl $-1, %eax
	je print_stdout
	movl %eax, (%ebx, %esi, 4)
	incl %esi
	jmp pop_loop
    
    print_stdout:
    
    incl %esi
	movl $0x0a, (%ebx, %esi, 4)				# lf
	incl %esi
	movl $0x0d, (%ebx, %esi, 4)				# cr
    
	movl $BUFSIZE, %edx         			# 500 in %edx
    movl $SYS_WRITE, %eax					# 4
    movl $STDOUT, %ebx						# std out
    
    #location of the buffer
    movl $PRINT_BUFFER, %ecx
    int $LINUX_SYSCALL

end_processing:

movl %ebp, %esp 
popl %ebp 

movl $1, %eax
int $LINUX_SYSCALL

