// Simplified models for minimal tDCS app

/// Session configuration
class SessionConfig {
  final double intensityMA; // 0-2mA
  final int durationSeconds; // Session duration

  const SessionConfig({
    required this.intensityMA,
    required this.durationSeconds,
  });

  // Validation
  bool get isValid =>
      intensityMA >= 0.0 && intensityMA <= 2.0 && durationSeconds > 0;

  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    if (seconds == 0) return '${minutes}m';
    return '${minutes}m ${seconds}s';
  }
}

/// ADC reading from ESP32
class ADCReading {
  final double adc1Voltage; // ADC1 in volts
  final double adc2Voltage; // ADC2 in volts
  final double adc3Voltage; // ADC3 in volts
  final double adc4Voltage; // ADC4 in volts
  final DateTime timestamp;

  ADCReading({
    required this.adc1Voltage,
    required this.adc2Voltage,
    required this.adc3Voltage,
    required this.adc4Voltage,
    required this.timestamp,
  });

  /// Parse 8-byte ADC data from ESP32
  /// Format: [AD1_MSB, AD1_LSB, AD2_MSB, AD2_LSB, AD3_MSB, AD3_LSB, AD4_MSB, AD4_LSB]
  factory ADCReading.fromBytes(List<int> data) {
    if (data.length < 8) {
      throw ArgumentError('Invalid ADC data length: ${data.length}');
    }

    // Reconstruct 16-bit signed values
    int toSigned16(int msb, int lsb) {
      final unsigned = (msb << 8) | lsb;
      return unsigned > 32767 ? unsigned - 65536 : unsigned;
    }

    final adc1 = toSigned16(data[0], data[1]);
    final adc2 = toSigned16(data[2], data[3]);
    final adc3 = toSigned16(data[4], data[5]);
    final adc4 = toSigned16(data[6], data[7]);

    // Convert to voltage (ADS1115: 0.125mV per LSB)
    const resolution = 0.000125; // 0.125mV in volts

    return ADCReading(
      adc1Voltage: adc1 * resolution,
      adc2Voltage: adc2 * resolution,
      adc3Voltage: adc3 * resolution,
      adc4Voltage: adc4 * resolution,
      timestamp: DateTime.now(),
    );
  }

  /// Calculate impedance in kOhms (R = V/I)
  /// Assumes adc1Voltage is the voltage across the electrodes
  double? calculateImpedance(double intensityMA) {
    if (intensityMA <= 0.05) return null; // Too low to measure accurately
    return (adc1Voltage / intensityMA) * 1000.0; // V / mA = kOhm
  }

  /// Connection quality assessment based on impedance
  ConnectionQuality getQuality(double intensityMA) {
    final impedance = calculateImpedance(intensityMA);
    if (impedance == null) return ConnectionQuality.unknown;
    if (impedance < 10.0) return ConnectionQuality.good; // Typical target < 10k
    if (impedance < 20.0) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
}

/// Connection quality levels
enum ConnectionQuality {
  unknown,
  good,
  fair,
  poor,
}

/// BLE connection state (renamed to avoid conflict with Flutter's ConnectionState)
enum BLEConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

/// Session state
enum SessionState {
  idle, // Connected but not running
  running, // Session in progress
  stopped, // Session manually stopped
}
