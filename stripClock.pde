#include <Wire.h>
#include <RTClib.h>
#include <HL1606stripPWM.h>

#define DS1307_ADDRESS 0x68
#define STRIP_LATCH_PIN 10
#define NUM_LEDS 32
#define CLOCK_LEDS 30
#define SECONDS_PER_LED 2

RTC_DS1307 RTC;
HL1606stripPWM strip = HL1606stripPWM(NUM_LEDS, STRIP_LATCH_PIN);
int stripBuffer[CLOCK_LEDS][3];
int brightness;
int rLed, gLed, bLed;
int hour, minute, second;
volatile int newSecond;
DateTime now;

void setup() {
	// Clock setup.
	Wire.begin();
	RTC.begin();

	if(!RTC.isrunning()) {
		// __DATE__ and __TIME__ are constants set at compile time.
		RTC.adjust(DateTime(__DATE__, __TIME__));

		// Enable SQW
		Wire.beginTransmission(DS1307_ADDRESS);
		// Select SQW register.
		Wire.send(0x07);
		// Enable 1Hz square wave.
		Wire.send(0x90);
		Wire.endTransmission();
	}

	// Strip setup
	brightness = 255;

	strip.setPWMbits(5);
	strip.setSPIdivider(16);
	strip.setCPUmax(80);
	strip.begin();
	
	for(int i = 0; i < CLOCK_LEDS; i++) {
		for(int j = 0; j < 3; j++) {
			stripBuffer[i][j] = 0;
		}
	}

	resetDisplayTime();
}

void loop() {
	int newSecond, newMinute, newHour;
	int secondDifference;

	now = RTC.now();
	newSecond = now.second();
	secondDifference = newSecond - second;
	secondDifference %= 60;

	if(0 > secondDifference) {
		secondDifference += 60;
	}

	if(secondDifference >= SECONDS_PER_LED) {
		ledTick();
	}
	else {
		delay(50);
	}
}

void resetDisplayTime() {
	now = RTC.now();
	hour = now.hour();
	minute = now.minute();
	second = now.second();

	rLed = second;
	gLed = minute;
	bLed = hour;
	stripBuffer[rLed][0] = brightness;
	stripBuffer[gLed][1] = brightness;
	stripBuffer[bLed][2] = brightness;

	updateStrip(rLed);
	updateStrip(gLed);
	updateStrip(bLed);
}

void ledTick() {
	second += SECONDS_PER_LED;

	rLed = (rLed + 1) % CLOCK_LEDS;

	if(!rLed) {
		gLed = (gLed + 1) % CLOCK_LEDS;

		if(!gLed) {
			bLed = (bLed + 1 % CLOCK_LEDS);

			smoothNextLed(bLed, 2);
		}

		smoothNextLed(gLed, 1);
	}

	smoothNextLed(rLed, 0);
}

/* Parameters:
 * ledNumber: index of LED to change.
 * ledColor: Color of LED to change. 0 == red; 1 == green; 2 == blue
 *
 * Magic numbers:
 * fadeSlowness: Amount to delay between each fade brightness change. Too much
 *	delay and the fade will take longer than a clock tick. Too little delay
 *	and it won't look like a fade.
 * fadeSmoothness: Ranges from 1 to brightness, with 1 being smoothest. How
 * 	much to increase brightness each iteration of the loop. Lower numbers
 *	will take more CPU cycles per fade.
 * ledsAtOnce: Number of LEDs to have lit when not fading. This applies to all
 * 	colors.
 */
void smoothNextLed(int ledNumber, int ledColor) {
	int prevLed, fadeSlowness, fadeSmoothness, ledsAtOnce;

	// My numbers are magic.
	ledsAtOnce = 24;
	fadeSlowness = 6;
	fadeSmoothness = 1;

	prevLed = (ledNumber + (CLOCK_LEDS - ledsAtOnce)) % CLOCK_LEDS;

	for(int i = 0; i <= brightness; i += fadeSmoothness) {
		stripBuffer[ledNumber][ledColor] = i;
		stripBuffer[prevLed][ledColor] = brightness - i;

		updateStrip(ledNumber);
		updateStrip(prevLed);
		delay(fadeSlowness);
	}

	// In the event that fadeSmoothness doesn't max and min out the values
	stripBuffer[ledNumber][ledColor] = brightness;
	stripBuffer[prevLed][ledColor] = 0;

	updateStrip(ledNumber);
	updateStrip(prevLed);
}

void updateStrip(int ledNumber) {
	int r, g, b;

	r = stripBuffer[ledNumber][0];
	g = stripBuffer[ledNumber][1];
	b = stripBuffer[ledNumber][2];

	strip.setLEDcolorPWM(ledNumber, r, g, b);
}
