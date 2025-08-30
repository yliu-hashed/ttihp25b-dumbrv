# startup code for DUMBRV
.text
  .section .init
  .type   _start, @function
  .global _start
_start:
  # setup SP and GP
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, _sp

  # clear BBS Section to 0
  la t0, __bss_start
  la t1, _end
0:
  beq t0, t1, 1f
  sw zero, 0(t0)
  addi t0, t0, 4
  j 0b
1:

  # copy data section from ROM to RAM
  la t0, _data     # dst ptr
  la t1, _edata    # dst end
  la t2, _data_lma # src ptr
0:
  beq t0, t1, 1f
  lw a0, 0(t2)
  sw a0, 0(t0)
  addi t0, t0, 4
  addi t2, t2, 4
  j 0b
1:

  # call main
  li a0, 0
  li a1, 0
  call main

  # infinite Loop
loop:
  j loop
