#include <Adafruit_NeoPixel.h>
#include <SoftwareSerial.h>

// ---------- Bluetooth (HM-10 BLE) ----------
// Wiring:
// HM-10 TX -> Arduino Pin 2
// HM-10 RX -> Arduino Pin 3
// HM-10 VCC -> 5V
// HM-10 GND -> GND
SoftwareSerial BT(2, 3); // RX, TX
String cmd = "";

// ---------- Relays (ACTIVE HIGH - For Simulation) ----------
#define RELAY_LIGHT 8
#define RELAY_FAN 9

// ---------- NeoPixel ----------
#define PIXEL_PIN 6
#define PIXEL_COUNT 16
Adafruit_NeoPixel ring(PIXEL_COUNT, PIXEL_PIN, NEO_GRB + NEO_KHZ800);

// remember last solid color
uint8_t lastR = 255, lastG = 255, lastB = 255;
uint8_t brightnessVal = 60;


    // ---------- Effect state ----------
    enum EffectMode {
      E_NONE,
      E_RAIN,
      E_BREATH,
      E_POLICE,
      E_FIRE,
      E_PARTY
    };
EffectMode effect = E_NONE;

unsigned long lastStep = 0;
int stepIdx = 0;
int breathVal = 0;
int breathDir = 1;

// ---------- Helpers ----------
void relaysAllOn() {
  digitalWrite(RELAY_LIGHT, HIGH);
  digitalWrite(RELAY_FAN, HIGH);
}
void relaysAllOff() {
  digitalWrite(RELAY_LIGHT, LOW);
  digitalWrite(RELAY_FAN, LOW);
}

void neonOff() {
  ring.clear();
  ring.show();
}

void setAllPixels(uint8_t r, uint8_t g, uint8_t b) {
  lastR = r;
  lastG = g;
  lastB = b;
  for (int i = 0; i < PIXEL_COUNT; i++)
    ring.setPixelColor(i, ring.Color(r, g, b));
  ring.show();
}

void allOn() {
  relaysAllOn();
  setAllPixels(lastR, lastG, lastB);
}
void allOff() {
  relaysAllOff();
  neonOff();
}

int clampInt(int v, int lo, int hi) {
  if (v < lo)
    return lo;
  if (v > hi)
    return hi;
  return v;
}

uint32_t wheel(byte pos) {
  pos = 255 - pos;
  if (pos < 85)
    return ring.Color(255 - pos * 3, 0, pos * 3);
  if (pos < 170) {
    pos -= 85;
    return ring.Color(0, pos * 3, 255 - pos * 3);
  }
  pos -= 170;
  return ring.Color(pos * 3, 255 - pos * 3, 0);
}

void stopEffectKeepColor() {
  effect = E_NONE;
  // restore last solid color
  setAllPixels(lastR, lastG, lastB);
}

// ---------- Effects (non-blocking) ----------
void effectRain() {
  // every 80ms: fade all a bit + add one blue sparkle
  if (millis() - lastStep < 80)
    return;
  lastStep = millis();

  // fade (simple: reduce each pixel)
  for (int i = 0; i < PIXEL_COUNT; i++) {
    uint32_t c = ring.getPixelColor(i);
    uint8_t r = (uint8_t)(c >> 16);
    uint8_t g = (uint8_t)(c >> 8);
    uint8_t b = (uint8_t)c;

    r = (uint8_t)(r * 0.6);
    g = (uint8_t)(g * 0.6);
    b = (uint8_t)(b * 0.75);
    ring.setPixelColor(i, ring.Color(r, g, b));
  }

  int p = random(0, PIXEL_COUNT);
  ring.setPixelColor(p, ring.Color(0, 0, 255));
  ring.show();
}

void effectBreath() {
  if (millis() - lastStep < 25)
    return;
  lastStep = millis();

  breathVal += breathDir * 3;
  if (breathVal >= 120) {
    breathVal = 120;
    breathDir = -1;
  }
  if (breathVal <= 0) {
    breathVal = 0;
    breathDir = 1;
  }

  // breath using last color scaled
  uint8_t r = (uint8_t)((lastR * breathVal) / 120);
  uint8_t g = (uint8_t)((lastG * breathVal) / 120);
  uint8_t b = (uint8_t)((lastB * breathVal) / 120);
  for (int i = 0; i < PIXEL_COUNT; i++)
    ring.setPixelColor(i, ring.Color(r, g, b));
  ring.show();
}

void effectPolice() {
  if (millis() - lastStep < 150)
    return;
  lastStep = millis();
  stepIdx++;

  // alternate half ring red/blue
  bool toggle = (stepIdx % 2 == 0);
  for (int i = 0; i < PIXEL_COUNT; i++) {
    if (i < PIXEL_COUNT / 2)
      ring.setPixelColor(i, toggle ? ring.Color(255, 0, 0)
                                   : ring.Color(0, 0, 255));
    else
      ring.setPixelColor(i, toggle ? ring.Color(0, 0, 255)
                                   : ring.Color(255, 0, 0));
  }
  ring.show();
}

void effectFire() {
  if (millis() - lastStep < 60)
    return;
  lastStep = millis();

  // random orange/yellow flicker
  for (int i = 0; i < PIXEL_COUNT; i++) {
    int r = random(180, 255);
    int g = random(20, 120);
    int b = random(0, 30);
    ring.setPixelColor(i, ring.Color(r, g, b));
  }
  ring.show();
}

void effectParty() {
  if (millis() - lastStep < 120)
    return;
  lastStep = millis();

  for (int i = 0; i < PIXEL_COUNT; i++) {
    uint32_t c = wheel((byte)random(0, 256));
    ring.setPixelColor(i, c);
  }
  ring.show();
}

void runEffect() {
  switch (effect) {
  case E_RAIN:
    effectRain();
    break;
  case E_BREATH:
    effectBreath();
    break;
  case E_POLICE:
    effectPolice();
    break;
  case E_FIRE:
    effectFire();
    break;
  case E_PARTY:
    effectParty();
    break;
  default:
    break;
  }
}

// ---------- Command handler ----------
void handleCommand(String c) {
  c.trim();
  c.toLowerCase();

  Serial.print("CMD: ");
  Serial.println(c);

  // ALL
  if (c == "all on") {
    allOn();
    return;
  }
  if (c == "all off") {
    allOff();
    return;
  }

  // Relays
  if (c == "light on") {
    digitalWrite(RELAY_LIGHT, HIGH);
    return;
  }
  if (c == "light off") {
    digitalWrite(RELAY_LIGHT, LOW);
    return;
  }
  if (c == "fan on") {
    digitalWrite(RELAY_FAN, HIGH);
    return;
  }
  if (c == "fan off") {
    digitalWrite(RELAY_FAN, LOW);
    return;
  }

  // Brightness
  if (c.startsWith("bright ")) {
    int b = clampInt(c.substring(7).toInt(), 0, 255);
    brightnessVal = (uint8_t)b;
    ring.setBrightness(brightnessVal);
    ring.show();
    return;
  }

  // Any RGB
  if (c.startsWith("rgb ")) {
    String rest = c.substring(4);
    rest.trim();
    int s1 = rest.indexOf(' ');
    int s2 = rest.indexOf(' ', s1 + 1);
    if (s1 > 0 && s2 > 0) {
      int r = clampInt(rest.substring(0, s1).toInt(), 0, 255);
      int g = clampInt(rest.substring(s1 + 1, s2).toInt(), 0, 255);
      int b = clampInt(rest.substring(s2 + 1).toInt(), 0, 255);
      effect = E_NONE;
      setAllPixels((uint8_t)r, (uint8_t)g, (uint8_t)b);
      return;
    }
    Serial.println("Use: rgb 255 0 0");
    return;
  }

  // Solid named colors (also stop effect)
  if (c == "red") {
    effect = E_NONE;
    setAllPixels(255, 0, 0);
    return;
  }
  if (c == "green") {
    effect = E_NONE;
    setAllPixels(0, 255, 0);
    return;
  }
  if (c == "blue") {
    effect = E_NONE;
    setAllPixels(0, 0, 255);
    return;
  }
  if (c == "white") {
    effect = E_NONE;
    setAllPixels(255, 255, 255);
    return;
  }
  if (c == "yellow") {
    effect = E_NONE;
    setAllPixels(255, 255, 0);
    return;
  }
  if (c == "purple") {
    effect = E_NONE;
    setAllPixels(128, 0, 255);
    return;
  }
  if (c == "orange") {
    effect = E_NONE;
    setAllPixels(255, 80, 0);
    return;
  }
  if (c == "pink") {
    effect = E_NONE;
    setAllPixels(255, 20, 147);
    return;
  }
  if (c == "cyan") {
    effect = E_NONE;
    setAllPixels(0, 255, 255);
    return;
  }
  if (c == "magenta") {
    effect = E_NONE;
    setAllPixels(255, 0, 255);
    return;
  }

  // Effects
  if (c == "rain") {
    effect = E_RAIN;
    return;
  }
  if (c == "breath") {
    effect = E_BREATH;
    return;
  }
  if (c == "police") {
    effect = E_POLICE;
    return;
  }
  if (c == "fire") {
    effect = E_FIRE;
    return;
  }
  if (c == "party") {
    effect = E_PARTY;
    return;
  }

  // Stop / Off
  if (c == "stop") {
    stopEffectKeepColor();
    return;
  }
  if (c == "neon off") {
    effect = E_NONE;
    neonOff();
    return;
  }

  Serial.println("Unknown command");
}

void setup() {
  pinMode(RELAY_LIGHT, OUTPUT);
  pinMode(RELAY_FAN, OUTPUT);
  relaysAllOff();

  Serial.begin(9600);
  BT.begin(9600); // HM-10 default is usually 9600

  ring.begin();
  ring.setBrightness(brightnessVal);
  neonOff();

  Serial.println("READY: HM-10 Mode");
}

void loop() {
  // run effect continuously
  runEffect();

  // read bluetooth commands (needs newline/enter)
  while (BT.available()) {
    char ch = (char)BT.read();
    // HM-10 often sends chars immediately, but app sends \n
    if (ch == '\n' || ch == '\r') {
      if (cmd.length() > 0)
        handleCommand(cmd);
      cmd = "";
    } else {
      cmd += ch;
      if (cmd.length() > 80)
        cmd = "";
    }
  }
}
