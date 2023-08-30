#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

uintptr_t sysCallMmap()
{
    long result = 0;

    __asm__ volatile("addi a7, x0, 222" // Syscall to mmap
                    :
                    :
                    :);
    __asm__ volatile("addi a0, x0, 0" // Address = NULL
                    :
                    :
                    :);
    __asm__ volatile("addi a1, x0, 8" // Length = 8B
                    :
                    :
                    :);
    __asm__ volatile("addi a2, x0, 3" // prot = PROT_READ|PROT_WRITE
                    :
                    :
                    :);
    __asm__ volatile("addi a3, x0, 22" // flags = MAP_PRIVATE|MAP_ANONYMOUS
                    :
                    :
                    :);
    __asm__ volatile("addi a4, x0, -1" // fd = -1
                    :
                    :
                    :);
    __asm__ volatile("addi a5, x0, 0" // offset = 0
                    :
                    :
                    :);
    __asm__ volatile("ecall"
                    :
                    :
                    :);
    __asm__ volatile("mv %0, x10"
                    :"=r"(result)
                    :
                    :);
    return result;
}

int main(int argc, char const *argv[])
{
    float a = 0.3, b = 0.5;
    uintptr_t *ptr = NULL;

    ptr = (uintptr_t *)sysCallMmap();

    __asm__ volatile("add a1, x0, %0"
                    :
                    :"r"(ptr)
                    :);
    __asm__ volatile("addi a7, x0, 12"
                    :
                    :
                    :);
    __asm__ volatile("ecall"
                    :
                    :
                    :);
    
    // printf("ptr: %p\n", ptr);

    // __asm__ volatile("addi a1, x0, 1000"
    //                 :
    //                 :
    //                 :);
    // __asm__ volatile("addi a7, x0, 10"
    //                 :
    //                 :
    //                 :);
    // __asm__ volatile("ecall"
    //                 :
    //                 :
    //                 :);

    // __asm__ volatile("addi a1, x0, 9"
    //                 :
    //                 :
    //                 :);
    // __asm__ volatile("addi a7, x0, 9"
    //                 :
    //                 :
    //                 :);
    // __asm__ volatile("ecall"
    //                 :
    //                 :
    //                 :);

    // for (int i = 0; i < 5; i++)
    // {
    //     a = a + b;
    //     printf("Jump\n");
    // }

    // __asm__ volatile("addi a1, x0, 0"
    //                 :
    //                 :
    //                 :);
    // __asm__ volatile("addi a7, x0, 10"
    //                 :
    //                 :
    //                 :);
    // __asm__ volatile("ecall"
    //                 :
    //                 :
    //                 :);

    return 0;
}