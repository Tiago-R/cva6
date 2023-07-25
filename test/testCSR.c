#include <stdio.h>

int main(int argc, char const *argv[])
{
    float a = 0.3, b = 0.5;
    __asm__ volatile("addi a1, x0, 3"
                    :
                    :
                    :);
    __asm__ volatile("addi a7, x0, 10"
                    :
                    :
                    :);
    __asm__ volatile("ecall"
                    :
                    :
                    :);

    __asm__ volatile("addi a1, x0, 9"
                    :
                    :
                    :);
    __asm__ volatile("addi a7, x0, 9"
                    :
                    :
                    :);
    __asm__ volatile("ecall"
                    :
                    :
                    :);

    for (int i = 0; i < 5; i++)
    {
        a = a + b;
        printf("Jump\n");
    }
    return 0;
}