#ifndef __INCLUDE_GUARD_RISCV_STDLIB__
#define __INCLUDE_GUARD_RISCV_STDLIB__

void exit(int status) __attribute__ ((noreturn));

static inline int abs(int val) {
    return val < 0 ? -val : val;
}

static inline long int labs(long int val) {
    return val < 0l ? -val : val;
}

static inline long long int llabs(long long int val) {
    return val < 0ll ? -val : val;
}

#endif /* end of include guard: __INCLUDE_GUARD_RISCV_STDLIB__ */
