# opentDCS

Open Source Transcranial Direct Current Stimulation (tDCS) Device.

## Project Structure

This monorepo contains the following components:

- **[firmware/](firmware/)**: ESP32 firmware for the tDCS device.
- **[kicad/](kicad/)**: Hardware design (schematics and PCB layout).
- **[mobile/](mobile/)**: Mobile application for controlling the device via BLE.

## Bill of Materials (BOM)

The following hardware components are required for the opentDCS project. 

### Core Components
| Component | Part Number / Value | Quantity | Description | Purpose |
|-----------|---------------------|----------|-------------| ------- |
| Microcontroller | ESP32-WROOM-32 | 1 | Main controller with BLE support | Circuit controller |
| ADC | ADS1115IDGS | 1 | 16-bit precision ADC with I2C interface | Circuit monitoring |
| Voltage Regulator | LM7805 | 1 | 5V Linear Regulator | Voltage regulation |
| Current Source | LM334M | 1 | Adjustable current source | Current controller |
| MOSFET (P-Ch) | FQP27P06 | 1 | High-side power switching | Safety switching during charging |
| BJT (NPN) | 2N3904 | 1 | General purpose transistor | Power circuit control |
| Boost Converter | MT3608 Module | 1 | DC voltage boost | Boost voltage for current targets |
| Li-ion Charger | 2S BMS Charging Module | 1 | 2-cell Series Battery Management System | Battery charging |
| Battery | 3.7V 18650 Li-ion | 2 | High-capacity rechargeable power source | Power source |

### Passives & Connectors
| Type | Value | Quantity | References |
|------|-------|----------|------------|
| Resistor | 39kΩ | 3 | R1, R3, R12 |
| Resistor | 10kΩ | 4 | R2, R4, R14, R19 |
| Resistor | 100kΩ | 3 | R13, R15, R17 |
| Resistor | 4.7kΩ | 1 | R20 |
| Resistor | 1kΩ | 1 | Rdac1 |
| Resistor | 327Ω | 1 | Rshunt1 |
| Resistor | 27Ω | 1 | Rset1 |
| Capacitor | 1μF | 1 | C1 |
| Capacitor | 10μF (Polarized) | 1 | C2 |
| Connector | DC Barrel Jack | 1 | J1 |

## Quick Start

Please refer to the README files in each subdirectory for rough instructions:

- [Hardware Circuit Design](kicad/README.md)
- [Firmware Setup](firmware/README.md)
- [Mobile App](mobile/README.md)

## License

See the [LICENSE](LICENSE) file for details.
