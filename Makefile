# Makefile for Tiny Servo Controller
#
# Usage:
# * for an ATtiny48:    make
# * for an ATmega48A:   make MCU=atmega48a
# * for an Arduino Uno: make MCU=atmega328p CPPFLAGS=-DARDUINO

MCU      = attiny48
CPPFLAGS =
CFLAGS   = -mmcu=$(MCU) -Os -Wall -Wextra

tiny-servo.elf: tiny-servo.c pulse.S
	avr-gcc $(CPPFLAGS) $(CFLAGS) $^ -o $@

clean:
	rm -f tiny-servo.elf
