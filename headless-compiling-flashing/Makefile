# MCU and F_CPU (Clock Speed)
MCU=atmega328p
F_CPU=16000000UL

# Compiler and Flags
CC=avr-gcc
CXX=avr-g++
CFLAGS=-mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -Wall
CXXFLAGS=$(CFLAGS) -fno-exceptions
OBJCPY=avr-objcopy
AVRDUDE=avrdude

# Arduino Core Paths (Update These)
ARDUINO_CORE=/Users/ivanf/Desktop/Projects/ArduinoCore-avr/cores/arduino
ARDUINO_VARIANTS=/Users/ivanf/Desktop/Projects/ArduinoCore-avr/variants/standard

# Programmer and Port
PROGRAMMER=usbasp
PORT=/dev/ttyUSB0

# Source Files
SRC=blink.cpp
OBJ=$(SRC:.cpp=.o)
ELF=blink.elf
HEX=blink.hex

# Compile Blink Sketch
all: $(HEX)

$(OBJ): $(SRC)
	$(CXX) $(CXXFLAGS) -I$(ARDUINO_CORE) -I$(ARDUINO_VARIANTS) -c $< -o $@

$(ELF): $(OBJ)
	$(CXX) $(CXXFLAGS) -L$(ARDUINO_CORE) -o $@ $^

$(HEX): $(ELF)
	$(OBJCPY) -O ihex -R .eeprom $< $@

# Flash the Microcontroller
flash: $(HEX)
	$(AVRDUDE) -c $(PROGRAMMER) -p $(MCU) -U flash:w:$(HEX):i

# Clean Up
clean:
	rm -f $(OBJ) $(ELF) $(HEX)
