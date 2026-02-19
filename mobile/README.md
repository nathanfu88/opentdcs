# opentDCS Mobile Controller App

A minimal Flutter application for controlling ESP32-based opentDCS via Bluetooth.

## Features

### Core Functionality
- **BLE Connection**: Scan and connect to ESP32 devices
- **Intensity Control**: Set output current (0-2mA) with safety validation
- **Duration Control**: Set session duration (10/20/30 minutes)
- **ADC Monitoring**: ADC data reporting (4 channels)
- **Session Timer**: Auto-stop when duration completes
- **Safety Validation**: Range checks and DAC conversion validation

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                    # App entry + navigation
│   ├── models/
│   │   └── models.dart              # SessionConfig, ADCReading, ConnectionState
│   ├── services/
│   │   └── ble_service.dart         # BLE communication (~280 lines)
│   └── screens/
│       ├── connect_screen.dart      # Device scanning & connection
│       ├── control_screen.dart      # Intensity/duration controls + session
│       └── monitor_screen.dart      # ADC data display
└── pubspec.yaml                     # Dependencies
```

## Quickstart

1.  **Install Flutter**: Follow the [official guide](https://flutter.dev/docs/get-started/install)
2.  **Run the App**:
    ```bash
    cd mobile
    flutter pub get
    flutter run
    ```

## BLE Protocol

- **Service**: `000000ff-0000-1000-8000-00805f9b34fb`
- **Characteristic**: `0000ff01-0000-1000-8000-00805f9b34fb`
- **Device Name**: `opentDCS`

## Related Projects

- **[Firmware](../firmware)**: ESP32 firmware source code
- **[Hardware](../kicad)**: KiCad schematics
