#include </usr/include/x86_64-linux-gnu/asm/unistd_32.h>

#Author: lipska the kat

.section .data

managed_base:
.long 0	

current_break:
.long 0

#==========================
# test
#==========================

errorstring:
	.ascii "An error has occurred while allocating memory\n\0"

block1:
.long 0

block2:
.long 0

block3:
.long 0

.section .text

.globl _start
_start:

	pushl %ebp
	movl %esp, %ebp

	call init_heap_manager
	
	#------------------
	# test allocate
	#------------------

	pushl $100										# 100 32 bit words 
	call allocate									# call allocate
	addl $4, %esp									# clean up the stack
	cmpl $0, %eax									# result passed back in %eax, 0 indicates an error
	je alloc_error									# print an error string then exit
	movl %eax, block1								# save eax for later de-allocation

	pushl $200
	call allocate
	addl $4, %esp									# clean up the stack
	cmpl $0, %eax									
	je alloc_error															
	movl %eax, block2

	pushl $300
	call allocate
	addl $4, %esp									# clean up the stack
	cmpl $0, %eax									
	je alloc_error
	movl %eax, block3

	#--------------------------
	# test deallocate
	#--------------------------

	pushl block1
	call deallocate
	addl $4, %esp									# clean up the stack

	pushl block2 		 
	call deallocate
	addl $4, %esp

	pushl block3
	call deallocate
	addl $4, %esp

	pushl $150			 							# see if we can find a block 0x96 words long
	call allocate
	
	jmp exit

	alloc_error:
	call printstring

	exit:

	movl %ebp, %esp
	popl %ebp

	movl $1, %eax
	int $0x80

#==========================
# end test
#==========================
#--------------------------------------------------------------
# collection of functions to manage a simple heap, each block
# starts with a header containing an availability flag followed
# by the number of 32 bit words in the block followed by a 
# pointer to the first available address in the block
#========================= header =============================
# avail 0/yes 1/no | avail words | ptr to start of avail memory
#==============================================================
#--------------------------------------------------------------

#------------------------
# search function
#------------------------
.global find_block
.type find_block, @function
find_block:

	pushl %ebp
	movl %esp, %ebp
	
	movl managed_base, %ebx				# get the base address of our heap in %ebx
	cmpl %ebx, current_break			# compare managed_base and current_break 
	je not_found						# if they are equal then there is nothing to search
	
	#----------------------------------------
	# start search loop, managed_base in %ebx
    #----------------------------------------
    #----------------------- header -------------------------------
	# avail 0/yes 1/no | avail words | ptr to start of avail memory
	#--------------------------------------------------------------
    
    movl 8(%ebp), %ecx					# move the number of required words into %ecx

	search_loop:						# we are looking for a free block, if we find one
										# we return the start address otherwise we return 0
	cmpl $0, (%ebx)						# is this block available
	jne get_next						# if not, look at the next one
	cmpl %ecx, 4(%ebx)					# if it's available, is it big enough
	jge found							# if it is we're done searching
	
	get_next:
	movl 4(%ebx), %eax					# get the number of words in this block into %eax
	imul $4, %eax						# multiply by 4 to get bytes					
	addl 8(%ebx), %eax 					# add the first available address to the number of words
	addl $4, %eax						# get the last word
	movl %eax, %ebx						# move the new header into %ebx
	cmpl current_break, %ebx				
	je not_found
	jmp search_loop
	
	not_found:
	movl $0, %eax						# put a 0 in %eax to indicate we haven't found a suitable block
	jmp end								# return to the caller
	
	found:								# if we get here we have found a suitable block
	movl $1, (%ebx)						# mark the block as unavailable
	movl 8(%ebx), %eax					# move the start address of the block into %eax
	
	end:

	movl %ebp, %esp
	popl %ebp

	ret

#-------------------------------------
# allocation function uses
# value at 8(ebp) as required
# number of bytes, result in ebx
# save ebx before calling if required
#-------------------------------------

.global allocate
.type allocate, @function
allocate:

	pushl %ebp
	movl %esp, %ebp

	#-----------------------------------------
	# the current break is the first word
	# after the last word of available memory
	# this location is not available to use
	#-----------------------------------------

	#----------------------- header -------------------------------
	# avail 0/yes 1/no | avail words | ptr to start of avail memory
	#--------------------------------------------------------------
	
	movl 8(%ebp), %ebx					# move the required number of words into ebx
	
	pushl %ebx							# search existing blocks fist
	call find_block						# see if there's an existing block available
	addl $4, %esp						# clean up the stack
	cmpl $0, %eax						# on success the start address for the new allocation is in %eax
	jne finished						# if we found an address we can get out
	
	movl 8(%ebp), %ebx					# move the required number of words into ebx

	alloc:
	addl $4, %ebx						# plus three for our header and 1 for the trailing word which will be the start of the next header
	imul $4, %ebx						# multiply words * 4 to get bytes, the required no bytes are now in %ebx

	addl current_break, %ebx			# add the current break to %ebx to get our final figure
										# required new address in %ebx
	movl $__NR_brk, %eax  				# syscall 45
	int $0x80							# execute
										# the new address should be in %eax
	cmpl %eax, %ebx						# if the two addresses are not the same then we have an error
	jne error

	movl current_break, %edx			# save the current break, allows base index addressing
	
	movl $0x1, (%edx)			        # if we get here we have got our memory, mark it as in use
	movl 8(%ebp), %ecx				    # get required number of words	
	movl %ecx, 4(%edx)       	        # write the word count
	addl $12, current_break				# advance the current_break to the new start address
	movl current_break, %eax			# move the new start address into %eax, this is what is returned
	movl %eax, 8(%edx)					# move the new start address into the header 
	movl %ebx, current_break			# move the current break to the last available word

	jmp finished						

	error:								
	movl $0, %eax						# just continue and let caller handle the problem

	finished:

	movl %ebp, %esp
	popl %ebp

	ret

#------------------------------
# deallocate a previously
# allocated block, takes the
# start address of the block
# to deallocate from the stack
#-----------------------------
.global deallocate
.type deallocate, @function
deallocate:

	pushl %ebp
	movl %esp, %ebp

	movl 8(%ebp), %eax					# get the address to deallocate into %eax
	movl $0, -12(%eax)					# set the availability field in the header to 0

	movl %ebp, %esp
	popl %ebp

	ret

#------------------------
# initialisation function
#------------------------
.global init_heap_manager
.type init_heap_manager, @function
init_heap_manager:

	pushl %ebp
	movl %esp, %ebp

	movl $__NR_brk, %eax  				# get the current break in %eax
	movl $0x0, %ebx
	int $0x80

	movl %eax, managed_base				# save the initial break in
	movl %eax, current_break			# managed_base and also in current_break

	movl %ebp, %esp
	popl %ebp

	ret

#----------------------------------------
# Function to print a null terminated 
# string, first append a '\n'
# to the end and print it out
# max 500 characters
#----------------------------------------

.global printstring
.type printstring, @function
printstring:

	pushl %ebp
	movl  %esp, %ebp 

	movl $errorstring, %ecx
	
	movl $46, %edx         					    	# 500 in %edx
	movl $4, %eax									# write
	movl $1, %ebx									# std out

	int $0x80										# write to stdout

	movl %ebp, %esp 
	popl %ebp

	ret


