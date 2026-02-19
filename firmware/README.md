# opentDCS Firmware

ESP32 firmware for the opentDCS device, built with ESP-IDF.

## Features

- **BLE Control**: GATT server for remote control via mobile app
- **Safety**: DAC control with failsafe defaults
- **Monitoring**: ADS1115 16-bit ADC for precise current/voltage monitoring. ADC values over BLE

## Hardware Pinout

| Function | ESP32 Pin | Description |
|----------|-----------|-------------|
| I2C SDA  | GPIO 21   | ADS1115 Data |
| I2C SCL  | GPIO 22   | ADS1115 Clock |
| DAC Out  | GPIO 25   | Current Control (DAC Chan 0) |

## BLE Specification

- **Service UUID**: `000000ff-0000-1000-8000-00805f9b34fb` (16-bit: `0x00FF`)
- **Characteristic UUID**: `0000ff01-0000-1000-8000-00805f9b34fb` (16-bit: `0xFF01`)
- **Device Name**: `tDCS`

### Data Protocol

- **Write (1 byte)**: Set DAC value.
    - `0-252`: Set DAC output (Note: 0 is Max Current, 255 is Min Current)
    - `253`: Disable DAC (Safe Mode)
    - `254`: Enable DAC

- **Read (8 bytes)**: Raw ADC values from ADS1115.
    - Bytes 0-1: Channel 0
    - Bytes 2-3: Channel 1
    - Bytes 4-5: Channel 2
    - Bytes 6-7: Channel 3
    - (Big Endian)

## Quickstart

1.  **Install ESP-IDF**: Follow the [official guide](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/get-started/)
2.  **Build & Flash**:
    ```bash
    idf.py set-target esp32
    idf.py build
    idf.py -p <YOUR_PORT> flash monitor
    ```
