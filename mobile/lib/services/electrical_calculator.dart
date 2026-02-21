import '../models/models.dart';

/// Calculates electrical values from ADC readings
///
/// A0: Top of Shunt (14.4V rail scaled by 10k/(39k+10k) ~= 0.204)
/// A1: Bottom of Shunt / Top of Load (scaled by ~0.204)
/// A2: Bottom of Load (scaled by ~0.204)
/// A3: Battery Monitor (100k/100k divider = 0.5 ratio)
class ElectricalCalculator {
  final ADCReading reading;
  final double targetCurrentMA;

  // Constants from hardware design
  static const double divRatioADC = 10000 / (39000 + 10000); // ~0.20408
  static const double divRatioBat = 100000 / (100000 + 100000); // 0.5
  static const double rShunt = 327.0;

  const ElectricalCalculator({
    required this.reading,
    required this.targetCurrentMA,
  });

  /// 1. Actual Voltage at A0 (Top of Shunt / V_supply)
  double get actualV0 => reading.adc1Voltage / divRatioADC;

  /// 2. Actual Voltage at A1 (Bottom of Shunt / Top of Load)
  double get actualV1 => reading.adc2Voltage / divRatioADC;

  /// 3. Actual Voltage at A2 (Bottom of Load)
  double get actualV2 => reading.adc3Voltage / divRatioADC;

  /// 4. Source Voltage (V_supply from A0)
  double get sourceVoltage => actualV0;

  /// 5. Voltage over Load (V_Rpct = V_actual_A1 - V_actual_A2)
  double get loadVoltage {
    final vLoad = actualV1 - actualV2;
    return vLoad > 0 ? vLoad : 0.0;
  }

  /// 6. Current through load (mA)
  /// I_Rpct = (V_actual_A0 - V_actual_A1) / R_shunt
  double get loadCurrentMA {
    final vShunt = actualV0 - actualV1;
    // (V / R) * 1000 = mA
    final current = (vShunt / rShunt) * 1000.0;

    // Safety check for unrealistic or negative current
    if (current < 0.01) return 0.0;
    return current;
  }

  /// 7. Measured Load Resistance (kOhms)
  /// R = V / I
  double get loadResistanceKOhms {
    final current = loadCurrentMA;
    if (current <= 0.05) return 0.0;
    // V / mA = kOhm
    return loadVoltage / current;
  }

  /// 8. Battery Voltage (A3)
  double get batteryVoltage => reading.adc4Voltage / divRatioBat;

  /// 9. Connection quality assessment based on impedance
  ConnectionQuality getQuality() {
    final impedance = loadResistanceKOhms;
    if (impedance <= 0.0) return ConnectionQuality.unknown;
    if (impedance < 10.0) return ConnectionQuality.good; // Typical target < 10k
    if (impedance < 20.0) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
}
