import '../models/models.dart';

/// Calculates electrical values from ADC readings
class ElectricalCalculator {
  final ADCReading reading;
  final double targetCurrentMA;

  const ElectricalCalculator({
    required this.reading,
    required this.targetCurrentMA,
  });

  /// 1. Source Voltage (Reference Voltage from ADC2)
  double get sourceVoltage => reading.adc2Voltage;

  /// 2. Voltage over Load (Measured Voltage from ADC1)
  double get loadVoltage => reading.adc1Voltage;

  /// 3. Current through load (mA)
  /// Currently using the target setpoint as the estimated current.
  /// In hardware with a current sense resistor, this would be calculated: V_shunt / R_shunt.
  double get loadCurrentMA => targetCurrentMA;

  /// 4. Measured Load Resistance (kOhms)
  /// R = V / I
  double get loadResistanceKOhms {
    if (loadCurrentMA <= 0.05) return 0.0;
    // V / mA = kOhm
    return loadVoltage / loadCurrentMA;
  }
}
