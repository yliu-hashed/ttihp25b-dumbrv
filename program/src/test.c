// Test program for DUMBRV
// This program records the input GPIO pins continuously, and outputs the recorded sequence on the output GPIO pins after a delay.

#include "platform.h"

char buffer[32768];

void main(void) {
    int i = 0;
    while (1) {
        buffer[i] = readInputGPIO();
        i = (i + 1) % 32768;
        writeOutputGPIO(buffer[i]);
    }
}
