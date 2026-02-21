import 'package:flutter_test/flutter_test.dart';
import '../lib/models/models.dart';
import '../lib/services/electrical_calculator.dart';

void main() {
  group('ElectricalCalculator Tests (Uniform 39k/10k Dividers)', () {
    test('Calculates load values correctly from new ratios', () {
      // Setup with new common ratio: 10/49 ~ 0.20408
      const double ratio = 10 / 49;
      
      // Assume:
      // V_supply (14.4V) scaled: 14.4 * ratio ~ 2.9388 V
      // V_shunt_lo (14.0V) scaled: 14.0 * ratio ~ 2.8571 V
      // V_load_lo (2.5V) scaled: 2.5 * ratio ~ 0.5102 V
      
      final reading = ADCReading(
        adc1Voltage: 14.4 * ratio, // A0 (Source)
        adc2Voltage: 14.0 * ratio, // A1 (Top of load)
        adc3Voltage: 2.5 * ratio,  // A2 (Bottom of load)
        adc4Voltage: 4.2 * 0.5,     // A3 (Battery, 0.5 ratio)
        timestamp: DateTime.now(),
      );

      final calculator = ElectricalCalculator(
        reading: reading,
        targetCurrentMA: 1.0,
      );

      // 1. Source Voltage (V_actual_A0) = 14.4 V
      expect(calculator.sourceVoltage, closeTo(14.4, 0.01));

      // 2. Load Voltage (V_actual_A1 - V_actual_A2) = 14.0 - 2.5 = 11.5 V
      expect(calculator.loadVoltage, closeTo(11.5, 0.01));

      // 3. Current (V_actual_A0 - V_actual_A1) / 327 * 1000 = (0.4 / 327) * 1000 ~ 1.223 mA
      expect(calculator.loadCurrentMA, closeTo(1.223, 0.01));

      // 4. Resistance = 11.5 / 1.223 ~ 9.403 kOhm
      expect(calculator.loadResistanceKOhms, closeTo(9.40, 0.05));

      // 5. Quality should be GOOD (< 10k)
      expect(calculator.getQuality(), ConnectionQuality.good);

      // 6. Battery Voltage (A3 / 0.5) = 4.2 V
      expect(calculator.batteryVoltage, closeTo(4.2, 0.01));
    });

    test('Handles low current/disconnected state', () {
      const double ratio = 10 / 49;
      
      final reading = ADCReading(
        adc1Voltage: 14.4 * ratio,
        adc2Voltage: 14.4 * ratio, // No drop over shunt
        adc3Voltage: 14.4 * ratio, // No drop over load
        adc4Voltage: 4.2 * 0.5,
        timestamp: DateTime.now(),
      );

      final calculator = ElectricalCalculator(
        reading: reading,
        targetCurrentMA: 0.0,
      );

      expect(calculator.loadCurrentMA, 0.0);
      expect(calculator.loadResistanceKOhms, 0.0);
      expect(calculator.getQuality(), ConnectionQuality.unknown);
    });
  });
}
