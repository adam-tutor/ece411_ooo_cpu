.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 4  # x1 <= 4
loop:
    addi x3, x1, 2  # x3 <= x1 + 8

    
    lw x1, store_check1
    lw x2, store_check2
    lw x3, store_check3
    lw x4, store_check4

    lw x5, store_addr1
    lw x6, store_addr2
    lw x7, store_addr3
    lw x8, store_addr4
    # jal x1, stores
    lw x10, new_data1
    lw x11, new_data2
    lw x12, new_data3
    lw x13, new_data4
    jal x31, stores
    lw x1, store_check1
    lw x2, store_check2
    lw x3, store_check3
    lw x4, store_check4
    # jal x1, done
stores:
    sh x10, 4(x5)
    jal x30, done
    sh x11, 4(x6)
    sh x12, 4(x7)
    sh x13, 4(x8)

    lw x1, store_check1
    lw x2, store_check2
    lw x3, store_check3
    lw x4, store_check4

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
