#include <stdio.h>

int main(int argc, char const *argv[])
{
    int result = 0;
    // char buf[100];
    float a = 0.3, b = 0.5;

    __asm__ volatile("csrw 0x323, %0"
                     :
                     //  : "r"(0x9)
                     : "r"(0x6)
                     :); // b01001 branch instructions

    for (int i = 0; i < 10; i++)
    {
        a = a + b;
        // __asm__ volatile("csrr %0, hpmcounter3"
        __asm__ volatile("csrr %0, 0xb03"
                         // __asm__ volatile("csrr %0, 0x323"
                         : "=r"(result)
                         :
                         :);

        if (result == 0)
            printf("BOOM\n");

        printf("Jump\n");
    }
    return 0;
}