.macro __test_exit status:req, target
  // TODO: implement a proper test exit sequence
  li ra, \status
1:
  j 1b
  wfi
.endm

.text
_entry:
mv sp, zero
mv ra, zero
mv gp, zero
mv tp, zero
mv s0, zero
mv s1, zero
mv s2, zero
mv s3, zero
mv s4, zero
mv s5, zero
mv s6, zero
mv s7, zero
mv s8, zero
mv s9, zero
mv s10, zero
mv s11, zero
mv a0, zero
mv a1, zero
mv a2, zero
mv a3, zero
mv a4, zero
mv a5, zero
mv a6, zero
mv a7, zero
mv t0, zero
mv t1, zero
mv t2, zero
mv t3, zero
mv t4, zero
mv t5, zero
mv t6, zero

__test_exit 0, exit
