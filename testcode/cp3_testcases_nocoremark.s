.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    li	x1,0
    li	x2,0
    li	x3,0
    li	x4,0
    li	x5,0
    li	x6,0
    li	x7,0
    li	x8,0
    li	x9,0
    li	x10,0
    li	x11,0
    li	x12,0
    li	x13,0
    li	x14,0
    li	x15,0
    li	x16,0
    li	x17,0
    li	x18,0
    li	x19,0
    li	x20,0
    li	x21,0
    li	x22,0
    li	x23,0
    li	x24,0
    li	x25,0
    li	x26,0
    li	x27,0
    li	x28,0
    li	x29,0
    li	x30,0
    li	x31,0
    addi x1, x0, 4  # x1 <= 4
loop:
    addi x3, x1, 2  # x3 <= x1 + 8

    
    lw x1, store_check1
    lw x2, store_check2
    lh x3, store_check3
    lb x4, store_check4

    lbu x20, store_check1
    lhu x21, store_check2

    lw x5, store_addr1
    lw x6, store_addr2
    lw x7, store_addr3
    lw x8, store_addr4

    lw x10, new_data1
    lw x11, new_data2
    lw x12, new_data3
    lw x13, new_data4

    # Uncomment this to test jumps
    # jal x1, done

    sb x10, 4(x5)
    # jal x1, done
    sh x11, 4(x6)
    sh x12, 4(x7)
    sw x13, 4(x8)

    lw x1, store_check1
    lw x2, store_check2
    lw x3, store_check3
    lw x4, store_check4

    li	x1,10
    li	x2,0
    li	x3,3
    li	x4,0
    li	x5,0
    li	x6,0
    li	x7,0
    li	x8,0
    li	x9,0
test_branch_1:
    beq	x6,x7, test_branch_2
    mul x7, x7, x3
test_branch_2:    
    add x2, x2, 1
    bne	x3,x8, test_branch_3
test_branch_3:   
    blt	x2,x1,test_branch_2
test_branch_4:
    bge	x2,x1,test_branch_5
test_branch_5:
    bltu	x2,x1,test_branch_2
test_branch_6:
    bgeu	x2,x1,done

done:
    slti x0, x0, -256

halt:                 # Infinite loop to keep the processor
    beq x0, x0, halt  # from trying to execute the data below.
                      # Your own programs should also make use
                      # of an infinite loop at the end.

.section .rodata

store_addr1:        .word store_check1
store_addr2:        .word store_check2
store_addr3:        .word store_check3
store_addr4:        .word store_check4

store_check1:       .word 0xdeadbeef
store_check2:       .word 0x00000040
store_check3:       .word 0x00000000
store_check4:       .word 0x600d600d
new_data1:           .word 0xba5eba11
new_data2:           .word 0xca11ab1e
new_data3:           .word 0xf005ba11
new_data4:           .word 0x00ddba11
