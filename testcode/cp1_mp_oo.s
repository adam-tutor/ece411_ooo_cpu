.section .text
.globl _start
    # Refer to the RISC-V ISA Spec for the functionality of
    # the instructions in this test program.
_start:
    # Note that the comments in this file should not be taken as
    # an example of good commenting style!!  They are merely provided
    # in an effort to help you understand the assembly style.

    addi x1, x0, 1  # x1 <= 1
    addi x2, x0, 2  # x1 <= 2
    addi x3, x0, 3  # x1 <= 3
    addi x4, x0, 4  # x1 <= 4
    addi x5, x0, 5  # x1 <= 5
    addi x6, x0, 6  # x1 <= 6
    addi x7, x0, 7  # x1 <= 7
    addi x8, x0, 8  # x1 <= 8
    addi x9, x1, 9  # x3 <= 9
    addi x1, x0, 1  # x1 <= 1
    addi x2, x0, 2  # x1 <= 2
    addi x3, x0, 3  # x1 <= 3
    addi x4, x0, 4  # x1 <= 4
    addi x5, x0, 5  # x1 <= 5
    addi x6, x0, 6  # x1 <= 6
    addi x7, x0, 7  # x1 <= 7
    addi x8, x0, 8  # x1 <= 8
    addi x9, x1, 9  # x3 <= 9
   

    # Add your own test cases here!

    slti x0, x0, -256 # this is the magic instruction to end the simulation

    addi x1, x0, 1  # x1 <= 1
    addi x2, x0, 2  # x1 <= 2
    addi x3, x0, 3  # x1 <= 3
    addi x4, x0, 4  # x1 <= 4
    addi x5, x0, 5  # x1 <= 5
    addi x6, x0, 6  # x1 <= 6
    addi x7, x0, 7  # x1 <= 7
    addi x8, x0, 8  # x1 <= 8
    addi x9, x1, 9  # x3 <= 9
    addi x1, x0, 1  # x1 <= 1
    addi x2, x0, 2  # x1 <= 2
    addi x3, x0, 3  # x1 <= 3
    addi x4, x0, 4  # x1 <= 4
    addi x5, x0, 5  # x1 <= 5
    addi x6, x0, 6  # x1 <= 6
    addi x7, x0, 7  # x1 <= 7
    addi x8, x0, 8  # x1 <= 8
    addi x9, x1, 9  # x3 <= 9