#ifndef __PLATFORM_H
#define __PLATFORM_H

volatile unsigned char *const _gpio_addr = (unsigned char *)0x02000000;

inline void writeOutputGPIO(char data) {
    *_gpio_addr = data;
}

inline char readInputGPIO() {
    return *_gpio_addr;
}

#endif // !__PLATFORM_H
