/*
 * test-master.ino: Simple test for the Tiny Servo Controller.
 *
 * This program is intended both as a basic test and as an example on
 * how to drive the Tiny Servo Controller. It periodically sends random
 * targets and reads them back to make sure they have been understood
 * correctly.
 *
 * Usage:
 *  - Connect the Arduino's SDA and SCL to the corresponding pins of
 *    tiny-servo. Pull-up resistors on those lines are optional if the
 *    connections are short, as both the Arduino and tiny-servo use
 *    their internal pull-ups.
 *  - Connect one/several outputs of tiny-servo to the signal input(s)
 *    of your servo(s).
 *  - Check the serial console for diagnostic messages.
 */

#include <Wire.h>

#define SLAVE_ADDRESS 0x53
#define NB_CHANNELS     20

/* Special registers. */
#define REG_SPEED       20
#define REG_MODE        21

/* Possible values for the MODE register. */
#define MODE_IDLE        0
#define MODE_HOLD        1
#define MODE_MOVE        3

void setup() {

    /* Communications. */
    Wire.begin();        // I2C
    Serial.begin(9600);  // for diagnostic messages

    /* Try to get some randomness. */
    randomSeed(analogRead(A0));

    /* Wait to make sure the slave is awake. */
    delay(10);

    /* Set speed = 5, i.e. full range in 1.02 s. */
    Wire.beginTransmission(SLAVE_ADDRESS);
    Wire.write(REG_SPEED);              // register address
    Wire.write(5);                      // register value
    Wire.endTransmission();
}

void loop() {
    uint8_t targets[NB_CHANNELS];
    unsigned long start, end;           // for timing

    /* Choose random targets. */
    for (uint8_t i = 0; i < NB_CHANNELS; i++)
        targets[i] = random(256);

    /* Send "mode = IDLE" to speed up the following transfers. */
    Wire.beginTransmission(SLAVE_ADDRESS);
    Wire.write(REG_MODE);               // register address
    Wire.write(MODE_IDLE);              // register value
    Wire.endTransmission();

    /* Send the 20 targets and time the transfer. */
    Serial.print("Sending... ");
    start = micros();
    Wire.beginTransmission(SLAVE_ADDRESS);
    Wire.write(0x00);                   // address of first register
    Wire.write(targets, NB_CHANNELS);
    Wire.endTransmission();
    end = micros();
    Serial.print("done in ");
    Serial.print((end - start) / 1e3);
    Serial.println(" ms.");

    /* Reset the register pointer. */
    Wire.beginTransmission(SLAVE_ADDRESS);
    Wire.write(0x00);                   // register address
    Wire.endTransmission();

    /* Read back. */
    Serial.print("Reading back... ");
    start = micros();
    Wire.requestFrom(SLAVE_ADDRESS, NB_CHANNELS);  // blocking read
    end = micros();
    Serial.print(" (");
    Serial.print((end - start) / 1e3);
    Serial.print(" ms): ");
    int available = Wire.available();
    if (available != NB_CHANNELS) {
        Serial.println("FAILED!");
        Serial.print("  Incomplete read, got only ");
        Serial.print(available);
        Serial.println("bytes.");
        return;
    }
    else {
        for (uint8_t i = 0; i < NB_CHANNELS; i++) {
            uint8_t c = Wire.read();
            if (c != targets[i]) {
                Serial.println("FAILED!");
                Serial.print("  Bad read, targets[");
                Serial.print(i);
                Serial.print("] = ");
                Serial.print(targets[i]);
                Serial.print(", received = ");
                Serial.println(c);
                return;
            }
        }
        Serial.println(" OK.");
    }

    /* Start moving. */
    Wire.beginTransmission(SLAVE_ADDRESS);
    Wire.write(REG_MODE);               // register address
    Wire.write(MODE_MOVE);              // register value
    Wire.endTransmission();

    delay(2000);
}
