# Quick Start Guide ⚡

Follow these streamlined instructions to get your Smart Home BLE application and hardware up and running in minutes.

---

## 📋 Prerequisites

1.  **Flutter SDK** installed (version `>=3.0.0 <4.0.0`).
2.  **Android Studio** or **VS Code** with Flutter and Dart plugins installed.
3.  A **physical Android device** (emulators do not support Bluetooth scanning).
4.  An **HM-10 BLE Bluetooth module** wired to your Arduino.

---

## 🔌 Hardware Setup

Connect your hardware components as follows:

*   **HM-10 TX** ➔ **Arduino Pin 2 (RX)**
*   **HM-10 RX** ➔ **Arduino Pin 3 (TX)**
*   **HM-10 VCC & GND** ➔ **Arduino 5V & GND**
*   **NeoPixel Ring Data Input (DI)** ➔ **Arduino Pin 6**
*   **NeoPixel VCC & GND** ➔ **Arduino 5V & GND**
*   **Relay IN1 (Light)** ➔ **Arduino Pin 8**
*   **Relay IN2 (Fan)** ➔ **Arduino Pin 9**
*   **Relay VCC & GND** ➔ **Arduino 5V & GND**

---

## 💻 Step-by-Step Installation

### Step 1: Upload the Arduino Sketch
1.  Connect your Arduino Uno to your PC via a USB cable.
2.  Open the [SmartHome_HM10.ino](file:///c:/Users/HAK/Desktop/Robotik/SmartHomeApp/arduino/SmartHome_HM10/SmartHome_HM10.ino) sketch in the Arduino IDE.
3.  Install the **Adafruit NeoPixel** library from the Library Manager if you haven't already.
4.  Select your board (Arduino Uno) and port, then click **Upload**.

### Step 2: Install Flutter Dependencies
Open your terminal in the root of this project and run:
```bash
flutter pub get
```

### Step 3: Run the App
With your Android phone connected to your PC (via USB with USB debugging enabled), execute:
```bash
flutter run
```
*(Or build a release APK: `flutter build apk --release`)*

---

## 📱 Testing Your Setup

### 1. BLE Connection
1.  Ensure your **Location/GPS** and **Bluetooth** are turned ON in your phone settings (BLE scanning requires Location Services to locate devices).
2.  Open the app and go to the **Connect Host** tab.
3.  Tap the **Search icon** in the top right to start scanning.
4.  Locate your HM-10 device (often named "HM-10", "MLT-BT05", or "CC2541") and tap **Connect**.
5.  The status bar will turn green upon connection.

### 2. Relay Control
1.  Go to the **Relays** tab.
2.  Tap **Light ON** or **Fan ON**.
3.  Check the physical relay board (status LED should light up, and the corresponding relay switch should click).

### 3. Lighting Control
1.  Go to the **Lighting** tab.
2.  Tap a solid color preset (e.g., **Red**, **Green**, **Blue**) to verify the WS2812B NeoPixel ring changes color.
3.  Adjust the custom RGB sliders and tap **Send RGB**.
4.  Change the brightness using the **Brightness Slider** (applied instantly when you release the slider).
5.  Test dynamic effects by tapping effect buttons like **Rain**, **Breath**, or **Police**.

### 4. Voice Commands
1.  Tap the **Microphone icon** on the Lighting tab or go to the voice tab.
2.  Choose your language (English, Turkish, or Arabic).
3.  Tap the central **Microphone Button** and say a command (e.g., *"light on"* or *"mavi"*).
4.  Confirm the recognized text. If successful, the app sends the corresponding command to the Arduino.

### 5. Automated Scheduling
1.  Go to the **Schedules** tab.
2.  Tap the **`+` (Add)** button.
3.  Set the schedule name, command (e.g., `light off`), and execution time (e.g., 2 minutes from now).
4.  Tap **Save**. Keep the app open/backgrounded, and confirm that the command runs and triggers a local notification alert when the scheduled time arrives.

---

## 🔧 Essential Troubleshooting

*   **No devices in scan list?** Check that **Location/GPS** is turned on. On newer Android versions, Bluetooth scanning will fail silently if GPS is disabled.
*   **Arduino not responding?** Make sure you didn't swap the TX/RX lines. HM-10 TX goes to Pin 2, and RX goes to Pin 3.
*   **NeoPixel doesn't light up?** Verify the pixel count configuration in `SmartHome_HM10.ino` (configured for a 16-LED ring by default) and make sure the data pin is connected to Pin 6.
