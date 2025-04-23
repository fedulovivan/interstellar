#define F_CPU 16000000UL  // Clock speed 16MHz
#include <avr/io.h>
#include <util/delay.h>

int main(void) {
    DDRB |= (1 << PB5); // Set pin 13 (PB5) as output
    while (1) {
        PORTB ^= (1 << PB5); // Toggle LED
        _delay_ms(500);      // Wait 500ms
    }
    return 0;
}
