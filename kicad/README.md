# opentDCS Hardware

KiCad schematic file for the opentDCS hardware. PCB file is not confirmed nor validated yet.

## Files

- **opentDCS.kicad_sch**: Current control circuit schematic file. The ESP32 block is not shown in the schematic. Named pins in the schematic connect to the designated ESP32 pins.
- **power.kicad_sch**: Power circuit schematic file. 2BMS charger circuit is not shown in the schematic, nor is the DC boost unit (MT3608). Connect the named pins in the schematic to the respective circuit.

## Quickstart

1.  **Install KiCad**: Download from [kicad.org](https://www.kicad.org/)
2.  **Open Project**:
    -   Launch KiCad
    -   Open `opentDCS.kicad_pro`
    -   Open `opentDCS.kicad_sch` to view schematics
