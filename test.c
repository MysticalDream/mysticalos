#include<stdio.h>

int main() {
    printf("Compiled on %s at %s\n", __DATE__, __TIME__);
    printf("__STDC__:%d\n", __STDC__);
    printf("__STDC_HOSTED__:%d\n", __STDC_HOSTED__);
    printf("__STDC_IEC_559__:%d\n", __STDC_IEC_559__);
    printf("__GNUC__:%d\n", __GNUC__);
    printf("__i386__:%d\n", __i386__);
//    printf("__x86_64__:%d\n", __x86_64__);
//    printf("__ACK__:%d\n", __ACK__);
    printf("__func__:%s\n", __func__);
//    printf("__VA_ARGS__%s\n",__VA_ARGS__);
    return 0;
}

//int main()
//
//{
//
//    char a[16];
//
//    return 0;
//
//}