#include <defines.S>
#include <boot.S>

.text
main:
    li a0, 0x11111
    li a6, 0x0

    div t1, a0, a6
    li t2, 0xFFFFFFFF
    bne t1, t2, failed
PASSED

failed:
FAILED 1


