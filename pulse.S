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

; Register assignments.
.set len0, 18    ; first pulse length
.set len1, 19
.set len2, 20
.set len3, 21
.set port, 22    ; copy of the PORT register
.set msk0, 23    ; bit mask with initial bit
.set mask, 24    ; moving bit mask
.set cntl, 26    ; 8-bit counter, or LSB of 16-bit counter
.set cnth, 27    ; MSB of 16-bit counter

; Apply mask to port if register equals counter,
; then rotate mask to the left, filling with 1.
; Constant execution time: 5 cycles.
.macro mask_if_eq_cnt reg
    cp \reg, cntl
    brne 0f
    and port, mask
0:  sec
    rol mask
.endm

.global pulse
pulse:

    ; Get pulse lengths.
    movw r30, r20
    ld len0, Z+
    ld len1, Z+
    ld len2, Z+
    ld len3, Z+

    movw r30, r24   ; Z = &port

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

    ; Delay 1 + 4 * 1994 = 7977 cycles.
    ldi cntl, lo8(1994)
    ldi cnth, hi8(1994)
3:  sbiw cntl, 1
    brne 3b

    ; Invert mask.
    com msk0

4:
    ; 1 cycle.
    mov mask, msk0

    ; End pulses when needed: 20 cycles.
    mask_if_eq_cnt len0
    mask_if_eq_cnt len1
    mask_if_eq_cnt len2
    mask_if_eq_cnt len3

    ; Write to port: 2 cycles.
    st Z, port

    ; Delay 6 cycles.
    rjmp .
    rjmp .
    rjmp .

    ; Loop back: 3 cycles.
    inc cntl
    brne 4b

    sei
    ret

.size pulse, .-pulse
