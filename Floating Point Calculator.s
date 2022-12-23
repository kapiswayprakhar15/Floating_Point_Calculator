.section .data

mantissa: .word 0b00000000000001111111111111111111
exponent: .word 0b01111111111110000000000000000000
significand: .word 0b00000000000010000000000000000000
sign: .word 0b10000000000000000000000000000000          
numbers:  .word 0x7FF08000,0x7FE60000


.section .text
.global _start

load:                               
stmfd sp!, {lr}
ldr r5, =sign                          
ldr r5, [r5]
ldr r6, =exponent                           
ldr r6, [r6]
ldr r7, =mantissa                       
ldr r7, [r7]
ldr r0, [r1]                            
and r2, r0, r5                          
and r3, r0, r6                          
and r4, r0, r7                         
ldr r0, [r1,#4]                         
and r5, r0, r5                          
and r6, r0, r6                          
and r7, r0, r7                          
ldmfd sp!, {pc}


nfpAdd:
stmfd sp!, {r0, r2-r9, lr}              @ creating activation block for the function nfpAdd
bl load                                 

@ mantissa to significand
orr r4, r4, #0b00000000000010000000000000000000 
orr r7, r7, #0b00000000000010000000000000000000 

@ We check if the sign bit is or 1. If it is 1, the number is negative, and we take the complement.
tst r2, #0x80000000                     
beq firstpositive                             
mvn r4, r4 
add r4,r4,#1                       @ taking 2's complement of mantissa of first number


firstpositive:                                
tst r5, #0x80000000                     
beq secondnegative                             
mvn r7, r7
add r7,r7,#1                       @ taking 2's complement of mantissa of second number

secondnegative:
@ Maintaing sign of the exponent
lsl r3, #1                              
lsl r6, #1
asr r3, #20                             
asr r6, #20
cmp r3, r6
@ Storing final exponent
moveq r8, r3                            
movgt r8, r3
movlt r8, r6

@ Moving the exponent in original position
lsl r8, #19                             

                             
beq equal                              @ We branch if there is no need to adjust the significand positions
subgt r9, r3, r6
asrgt r7, r9
sublt r9, r6, r3
asrlt r4, r9

                            
equal:                                  @ Exponent is same and the mantissa in the correct place
add r9, r4, r7                          @ Final sum of mantissa
                                       
ands r0, r9, #0x80000000                @ Sign bit of added sum
beq norm          
mvn r9, r9
add r9,r9,#1                        @ Converting it in 2's complememt to get the correct answer if it is negative

norm:
                                       
mov r10, #0b0000000000100000000000000000000     @ `1` at 21st position
tst r9, r10                                     @ 1 at 21st bit position, then only single step normalisation is required
lsr r10, #1                                     @ r10 will always check 20th bit position (used in while loop)
beq while                                       @ 0 at 21st bit position, then go to while
lsr r9, #1                                      @ actual normalisation (shifting one bit right)
add r8, r8, #0b00000000000010000000000000000000 @ adding 1 to exponent
b normalisationDone

while:
tst r9, r10                         
bne normalisationDone                   	@ if 1 is there at 20th position, then normalisation is done
lsl r9, r9, #1                         	 	@ shifting the significand one bit towards left
sub r8, r8, #0b00000000000010000000000000000000 @ reducing the exponent by 1
b while



normalisationDone:
and r8, #0x7fffffff                     @ clearing the 32 bit position of exponent so that it does not interfere with the sign
ldr r10, =mantissa
ldr r10, [r10]
and r9, r9, r10                         @ filtering out only mantissa bits

orr r0, r0, r8                          @ putting together all three pieces of number together
orr r0, r0, r9                          @ answer is in `r0`
bl storeAnswer
ldmfd sp!, {r0, r2-r9, pc}


storeAnswer:
stmfd sp!, {lr}
str r0, [r1,#8]
@ add r1, r1, #4
ldmfd sp!,{pc}



nfpmultiply:
stmfd sp!,{r0,r2-r9,lr}
@Taking numbers to be multiplied from the memory
ldr r2,[r1]     	@firstnumber 
ldr r4,[r1,#4]     	@secondnumber
@ We store the numbers in r2 and r4 registers

@ Trying to extract mantissa from numbers
ldr r8,=mantissa           
ldr r9,[r8]
and r5,r9,r2    @mantissa of first number
and r6,r9,r4    @mantissa of second number
@ Mantissa are stored in r5 and r6 registers

@ We now try to get significand by adding 1
ldr r7,=significand
ldr r7,[r7]
add r5,r5,r7
add r6,r6,r7
@ Significand are stored in r5 and r6 registers

@ Trying to extract exponent from numbers
ldr r8,=exponent
ldr r8,[r8]
and r9,r8,r2    @shifted exponent of first number
and r0,r8,r4    @shifted exponent of second number
lsr r9,r9,#19   @2's complimemt exponent of first number
lsr r0,r0,#19   @2's comliment final exponent of second number
@ Exponents are stored in r9 and r0 registers 

@ Trying to extract sign bit by shifting numbers
lsr r7,r2,#31   @sign bit num1
lsr r8,r4,#31   @sign bit num2
@ Sign bit is stored in r7 and r8




@ Calculating the Final sign of multiplication i.e XOR of both the sign
eor r7,r7,r8     @Final sign bit is stored in r7
@ Registers whose value cannot be changed currently are r1,r5,r6,r8,r9,r0 and r7(final sign)

@Calculating final exponent i.e Addition of exponent
add r9,r9,r0     @Final exponent is stored in r9
@Registers whose value cannot be changed currently are r1,r5,r6,r8,r0,r7(final sign) and r9(final exponent)

lsr r5,r5,#4  	@making significand 16 bit
lsr r6,r6,#4   	@making significand 16 bit
mul r0,r6,r5   	@multiplying significand and storing final significanf in r0
@Registers whose value cannot be changed currently are r1,r5,r6,r8,r7(final sign),r9(final exponent) and r0(final significand)

@Checking Normalisation
mov r8,r0   @Making copy of significand
lsr r8,r8,#30   
cmp r8,#1
bgt nor 
bl store 

nor:
	add r9,r9,#1     @adding 1 in exponent
	mov r0,r0,lsr #1 @Doing normalisation
	bl store

store:
	lsl r7,r7,#31   @Shifting Sign Bit to get the it to correct position
	lsl r9,r9,#19   @Shifting Exponent Bit to get the it to correct position
     	lsl r9,r9,#1
	lsr r9,r9,#1
	lsl r0,r0,#2
     lsr r0,r0,#13   	@Removing signifacand to get mantissa
	add r7,r7,r9
	add r7,r7,r0   	@multiplied number
     str r7,[r1,#12]   	@Result stored after numbers
	ldmfd sp!, {r0,r2-r9,pc}
      nop

_start:
ldr r1, =numbers    	@pointing r1 to memory address to the numbers as input(given in the question)

@ Addition function
bl nfpAdd

@ Multiplication function
bl nfpmultiply
nop