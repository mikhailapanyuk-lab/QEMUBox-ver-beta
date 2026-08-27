# JIT test helper - small C program
# Attempts to mmap and mprotect a page to PROT_EXEC. Exit 0 = success (JIT possible).

#include <sys/mman.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
    void *p = mmap(NULL, 4096, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (p == MAP_FAILED) {
        return 2;
    }
    if (mprotect(p, 4096, PROT_READ | PROT_EXEC) != 0) {
        return 1;
    }
    return 0;
}
