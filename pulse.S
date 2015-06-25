; pulse.S: Send pulses to 4 consecutive bits of port,
;          starting at first_bit.
;
; C prototype:
;   extern void pulse(volatile uint8_t *port,
;           uint8_t first_bit, uint8_t lengths[4]);
;
; Inputs:
;   r25:r24 = mem address of the IO port
;       r22 = first bit to pulse
;   r21:r20 = address of lengths array
;
; Copyright (c) 2015 Edgar Bonet Orozco.
; This file is part of the Tiny Servo Controller project, licensed
; under the terms of the MIT license. See file LICENSE for details.

; Minimum pulse width and pulse step, in cycles.
#ifndef PULSE_MIN
#  define PULSE_MIN 8000
#endif
#ifndef PULSE_STEP
#  define PULSE_STEP 32
#endif

; Sanity checks
.if PULSE_MIN < 800
  .error "PULSE_MIN should be >= 800."
.endif
.if PULSE_STEP < 26
  .error "PULSE_STEP should be >= 26."
.endif
.if PULSE_MIN + 255 * PULSE_STEP > 24000
  .error "Maximum pulse should be <= 24000 cycles."
.endif

; Register assignments.
.set len0, 18    ; first pulse length
.set len1, 19
.set len2, 20
.set len3, 21
.set port, 22    ; copy of the PORT register
.set msk0, 23    ; bit mask with initial bit
.set mask, 24    ; moving bit mask
.set cntl, 26    ; inner loop counter, or LSB of 16-bit counter
.set cnth, 27    ; outer loop counter, or MSB of 16-bit counter

; Delay for the specified number of cycles.
; Uses and clears:
;  - cntl for delays between 9 and 770 cycles
;  - cnth:cntl for delays of more than 770 cycles
.macro delay cycles
  .if \cycles >= 262149
    .error "delay macro invoked with excessive cycle count."
  .elseif \cycles >= 771
    ldi   cntl, lo8((\cycles - 1) / 4)
    ldi   cnth, hi8((\cycles - 1) / 4)
0:  sbiw  cntl, 1
    brne  0b
    delay (\cycles - 1) % 4
  .elseif \cycles >= 9
    ldi   cntl, (\cycles / 3) % 256
0:  dec   cntl
    brne  0b
    delay \cycles % 3
  .elseif \cycles >= 2
    rjmp  .
    delay \cycles - 2
  .elseif \cycles == 1
    nop
  .elseif \cycles != 0
    .error "delay macro invoked with invalid cycle count."
  .endif
.endm

; Apply mask to port if register equals counter,
; then rotate mask to the left, filling with 1.
; Constant execution time: 5 cycles.
.macro mask_if_eq_cnt reg
    cp \reg, cnth
    brne 0f
    and port, mask
0:  sec
    rol mask
.endm

.global pulse
pulse:

    ; Load pulse lengths.
    movw r30, r20
    ld len0, Z+
    ld len1, Z+
    ld len2, Z+
    ld len3, Z+

    ; Have Z point to the PORT I/O register.
    movw r30, r24

    ; Build single-bit mask.
    ldi msk0, 1
    tst r22
    breq 2f
1:  lsl msk0
    dec r22
    brne 1b
2:

    ; Build 4-bit mask.
    mov mask, msk0
    lsl mask
    or mask, msk0
    lsl mask
    or mask, msk0
    lsl mask
    or mask, msk0

    ; Start pulse.
    cli
    ld port, Z
    or port, mask
    st Z, port

    ; This clears cnth:cntl.
    delay (PULSE_MIN - 24)

    ; Invert mask: 1 cycle.
    com msk0

3:
    ; Reset moving mask: 1 cycle.
    mov mask, msk0

    ; End pulses when needed: 20 cycles.
    mask_if_eq_cnt len0
    mask_if_eq_cnt len1
    mask_if_eq_cnt len2
    mask_if_eq_cnt len3

    ; Write to port: 2 cycles.
    st Z, port

    delay (PULSE_STEP - 26)

    ; Loop back: 3 cycles.
    inc cnth
    brne 3b

    sei
    ret

.size pulse, .-pulse
