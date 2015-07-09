# Tiny Servo Controller

This firmware is intended to turn an AVR microcontroller into a
20-channel servo controller with an I2C interface. It is targeted at the
low-cost ATtiny48, but can run on a few other AVRs, as well as on some
of the most common Arduino boards.

The AVR needs no additional hardware other than a power supply, although
decoupling capacitors and a reset pull-up are recommended, as usual.

**Status**: Welcoming alpha-testers. Do not expect the interface to be
stable.

## Features

20 channels, 8-bit resolution, ultra-low jitter (cycle-accurate
timings), speed control, I2C interface, synchronized start possible with
many controllers.

In the default configuration, the pulse widths can be adjusted from
1000&nbsp;µs to 2020&nbsp;µs in 4&nbsp;µs steps. These limits can be
changed at compile-time, with the following constraints:

* The minimum width can be no less than 100&nbsp;µs.
* The step size should be a multiple of 0.125&nbsp;µs
  and can be no less than 3.25&nbsp;µs.
* maximum width = (minimum width) + 255 × (step size).
* This maximum can be no more than 3000&nbsp;µs.

## Caveats

The cycle-accurate timings are achieved by using busy delay loops with
interrupts disabled. This has the drawback of slowing down the I2C
interface. The communications should not be compromised as long as the
master supports clock stretching. Beware that, although most hardware
I2C interfaces do support clock stretching, some naive software
implementations do not.

If the servos are not fighting a substantial load, this issue can be
alleviated by disabling the sending of the control pulses (setting the
mode to `IDLE`) just before any substantial bus transaction, and
enabling it afterwards.

Other limitations that could be lifted in future versions:

* It should be possible to extend the range of pulse widths while
  keeping a 4&nbsp;µs resolution, but that would require 16-bit control.
* There is currently a single speed setting affecting all channels. It
  should be possible to have a per-channel speed.

## Compatible microcontrollers

This program is expected to work on at least the following:
* ATtiny: 48, 88
* ATmega: 48A, 48PA, 88A, 88PA, 168A, 168PA, 328, 328P.

It should also work on Arduino boards based on any of the above,
including the Uno, Diecimila, Pro, Mini, Nano, Ethernet and third-party
compatible boards. On these boards, however, only 18 channels are
available.

## Pinout

Here is the mapping from servo channels to AVR pins:

| channel |  AVR pin  |
|:-------:|:---------:|
|  0 –  7 | PD0 – PD7 |
|  8 – 15 | PB0 – PB7 |
| 16 – 19 | PC0 – PC3 |

And here is the mapping to the Arduino pins:

| channel | Arduino pin |
|:-------:|:-----------:|
|  0 – 13 |    0 – 13   |
| 14 – 15 | unavailable |
| 16 – 19 |   A0 – A3   |

Channels 14 and 15 are not available on the Arduino because their
corresponding AVR pins are used by the on-board 16&nbsp;MHz resonator.
The I2C interface is on pins A4 (SDA) and A5 (SCL).

## Compiling

Assuming you have an ATtiny48:

    avr-gcc -mmcu=attiny48 -Os tiny-servo.c pulse.S -o tiny-servo.elf

For other AVRs, set the `-mmcu` option accordingly.

Or you could the supplied Makefile: see the comments in that file.

The program is intended to work with the fuses at their default
settings. The MCU is then clocked by its internal oscillator and runs at
8&nbsp;MHz irrespective of the CKDIV8 fuse setting, as the clock
prescaler is set to 1 by software at program startup.

The compilation can be customized with the following options:

* `-DARDUINO` sets the clock prescaler to 2, instead of 1, in order for
  the timings to be correct on the 16&nbsp;MHz Arduinos.
* `-DI2C_ADDRESS=...` sets the 7-bit slave I2C address. Default is
  `0x53` (because it's a “53RVO” controller).
* `-DNO_PULLUP` disables the internal pullups on the I2C lines.
* `-DPULSE_MIN=...` sets the minimum pulse width in clock cycles.
  Minimum: 800 (100&nbsp;µs), default: 8000 (1000&nbsp;µs).
* `-DPULSE_STEP=...` sets the step size for adjusting the pulse width.
  Minimum: 26 (3.25&nbsp;µs), default: 32 (4&nbsp;µs).

## Usage

The chip exposes a set of 24 8-bit registers through the I2C interface:

| register | access |    function    |
|:--------:|:------:|:--------------:|
|  0 – 19  |  R/W   | targets 0 – 19 |
|    20    |  R/W   |    speed       |
|    21    |  R/W   |    mode        |
|    22    |   R    |    status      |
|    23    |   R    |    version     |

The “targets” are the values the set points should eventually reach. The
width of the pulse sent to the servo is (minimum\_width + step\_size ×
set\_point). In the default configuration, this is (1000 + 4 ×
set\_point) microseconds, ranging from 1.0&nbsp;ms to 2.02&nbsp;ms.

The “speed” is the maximum amount the set points can change on each
update. As there are 50 updates per second, the time needed for the set
points to travel the full range (0 to 255) is 255÷(speed×50) seconds.
Setting the speed to 255 will allow instantaneous tracking of the
targets.

The “mode” should be either:
* 0 = `IDLE`: the servos are not driven
* 1 = `HOLD`: the servos are driven at their current set points,
  changing the targets will have no immediate effect
* 3 = `MOVE`: the set points will be moved towards their respective
  targets at the specified speed.

The “status” register is read-only. It can be either:
* 0: all the set points have reached their respective targets
* 1: at least one set point has not yet reached its target

The “version” register is also read-only. It should read 1 with the
current firmware version.

In order to write one or several registers, the I2C master has to
issue the following on the bus:
* start condition
* I2C slave address + write bit (1 byte)
* address of first register to be written to (1 byte)
* register data (1 – 22 bytes)
* stop condition

The registers are accessed through an auto-incremented pointer. Any
number of consecutively numbered registers can then be written to in a
single transaction.

**Example**: Using the Arduino Wire library, assume we want to set the
target for channel 12 at 100 (i.e. 1.4&nbsp;ms) and the target for
channel 13 at 200 (i.e. 1.8&nbsp;ms). Since the channels are
consecutive, this is done in a single transaction as follows:

```C++
Wire.beginTransmission(0x53);  // default slave address
Wire.write(12);                // start at register 12
Wire.write(100);               // target for channel 12
Wire.write(200);               // target for channel 13
Wire.endTransmission();
```

See the file [test-master.ino](test-master.ino) for a more complete
example, including reading the registers back.

The controller responds both to its own I2C address and to the General
Call Address (`0x00`, used for I2C broadcast). The general call
semantics is, however, not honored: both addressed and general call
messages are interpreted in the same way. This feature can be used to
synchronize several controllers by broadcasting “mode =&nbsp;MOVE”.

## If you use this firmware...

...I would gladly appreciate if you drop me a note telling me how it
helped in your project. And I would appreciate even more if, in your
project's documentation, you link back here. If you modify and improve
the firmware, you are encouraged to contribute your changes back to the
free software community, either by forking and submitting a pull request
on GitHub, or by submitting a patch, or by publishing them independently
under a free software licence.

Please note that the points above are **not** legal requirements. This
firmware is licensed under the terms of the MIT license, and only the
terms in the file [LICENSE](LICENSE) are legally binding.
