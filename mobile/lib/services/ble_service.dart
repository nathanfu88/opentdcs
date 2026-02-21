import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Core BLE service for ESP32 tDCS communication
/// Implements Option B: Lean production with safety validation
class BLEService extends ChangeNotifier {
  // Persistence keys
  static const String _lastDeviceKey = 'last_connected_device_id';

  // BLE Configuration
  static const String _serviceUuid = '000000ff-0000-1000-8000-00805f9b34fb';
  static const String _characteristicUuid =
      '0000ff01-0000-1000-8000-00805f9b34fb';

  // Safety constants
  static const double maxCurrentMA = 2.0;
  static const double defaultIntensityMA = 0.5;
  static const int dacEnableCommand = 254;
  static const int dacDisableCommand = 253;
  static const int dacOffValue = 255;

  // State
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  BLEConnectionState _connectionState = BLEConnectionState.disconnected;
  String? _errorMessage;
  List<BluetoothDevice> _discoveredDevices = [];
  Timer? _adcPollTimer;
  ADCReading? _lastReading;

  // Session State
  SessionState _sessionState = SessionState.idle;
  int _elapsedSeconds = 0;
  int _sessionDurationSeconds = 0;
  Timer? _sessionTimer;
  double _currentIntensityMA = 0.0;

  // Getters
  BLEConnectionState get connectionState => _connectionState;
  String? get errorMessage => _errorMessage;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  BluetoothDevice? get connectedDevice => _device;
  ADCReading? get lastReading => _lastReading;
  bool get isConnected => _connectionState == BLEConnectionState.connected;
  
  SessionState get sessionState => _sessionState;
  int get elapsedSeconds => _elapsedSeconds;
  int get sessionDurationSeconds => _sessionDurationSeconds;
  double get currentIntensityMA => _currentIntensityMA;
  bool get isSessionRunning => _sessionState == SessionState.running;

  /// Attempt to reconnect to the last used device
  Future<void> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastId = prefs.getString(_lastDeviceKey);

      if (lastId != null && _connectionState == BLEConnectionState.disconnected) {
        debugPrint('Attempting auto-connect to $lastId');
        final device = BluetoothDevice.fromId(lastId);
        await connect(device);
      }
    } catch (e) {
      debugPrint('Auto-connect failed: $e');
    }
  }

  /// Scan for ESP32 devices
  Future<void> scanForDevices() async {
    try {
      _setConnectionState(BLEConnectionState.scanning);
      _discoveredDevices.clear();
      _errorMessage = null;

      // Check Bluetooth adapter
      if (await FlutterBluePlus.isSupported == false) {
        throw Exception('Bluetooth not supported on this device');
      }

      // Start scan
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(_serviceUuid)],
        androidScanMode: AndroidScanMode.lowLatency,
      );

      // Listen for scan results
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        _discoveredDevices = results
            .where((r) =>
                r.device.platformName.toLowerCase().contains('opentdcs') ||
                r.device.platformName.toLowerCase().contains('tdcs'))
            .map((r) => r.device)
            .toList();
        notifyListeners();
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 10));
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      _setConnectionState(BLEConnectionState.disconnected);
    } catch (e) {
      _setError('Scan failed: $e');
    }
  }

  /// Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _setConnectionState(BLEConnectionState.connecting);
      _errorMessage = null;
      _device = device;

      // Connect with timeout
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
        mtu: null,
      );

      // Discover services
      final services = await device.discoverServices();
      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == _serviceUuid.toLowerCase(),
        orElse: () => throw Exception('Service not found'),
      );

      // Find characteristic
      _characteristic = service.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() == _characteristicUuid.toLowerCase(),
        orElse: () => throw Exception('Characteristic not found'),
      );

      // Enable notifications if supported
      if (_characteristic!.properties.notify) {
        await _characteristic!.setNotifyValue(true);
      }

      // Save device ID for auto-reconnect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDeviceKey, device.remoteId.toString());

      _setConnectionState(BLEConnectionState.connected);
      _startADCPolling(const Duration(seconds: 5)); // Initial idle polling
      
      HapticFeedback.mediumImpact();
      return true;
    } catch (e) {
      _setError('Connection failed: $e');
      await disconnect();
      return false;
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      await stopSession();
      _stopADCPolling();
      await _device?.disconnect();
      _device = null;
      _characteristic = null;
      _lastReading = null;
      _setConnectionState(BLEConnectionState.disconnected);
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  /// Start a stimulation session
  Future<bool> startSession(double intensityMA, int durationMinutes) async {
    if (!isConnected) return false;

    // 1. Enable DAC
    final enabled = await enableDAC();
    if (!enabled) {
      HapticFeedback.vibrate();
      return false;
    }

    // 2. Set intensity
    final setIntensitySuccess = await setIntensity(intensityMA);
    if (!setIntensitySuccess) {
      await disableDAC();
      HapticFeedback.vibrate();
      return false;
    }

    // 3. Initialize state
    _sessionState = SessionState.running;
    _elapsedSeconds = 0;
    _sessionDurationSeconds = durationMinutes * 60;
    _currentIntensityMA = intensityMA;

    // 4. Update polling frequency to 1s for safety during stimulation
    _startADCPolling(const Duration(seconds: 1));

    // 5. Start session timer
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      
      if (_elapsedSeconds >= _sessionDurationSeconds) {
        stopSession();
      }
      notifyListeners();
    });

    HapticFeedback.heavyImpact();
    notifyListeners();
    return true;
  }

  /// Stop the current session
  Future<void> stopSession() async {
    _sessionTimer?.cancel();
    _sessionTimer = null;

    if (isConnected) {
      await setIntensity(0.0);
      await disableDAC();
      // Revert to slower polling when idle
      _startADCPolling(const Duration(seconds: 5));
    }

    if (_sessionState == SessionState.running) {
      HapticFeedback.mediumImpact();
    }

    _sessionState = SessionState.idle;
    _elapsedSeconds = 0;
    _currentIntensityMA = 0.0;
    notifyListeners();
  }

  /// Set intensity (0-2mA)
  Future<bool> setIntensity(double currentMA) async {
    if (!isConnected) {
      _setError('Not connected to device');
      return false;
    }

    // Validate range
    if (currentMA < 0.0 || currentMA > maxCurrentMA) {
      _setError('Invalid intensity: $currentMA mA (max: $maxCurrentMA mA)');
      return false;
    }

    try {
      final dacValue = _currentToDAC(currentMA);
      await _writeDAC(dacValue);
      _currentIntensityMA = currentMA;
      HapticFeedback.selectionClick();
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to set intensity: $e');
      return false;
    }
  }

  /// Enable DAC output
  Future<bool> enableDAC() async {
    if (!isConnected) return false;
    try {
      await _writeDAC(dacEnableCommand);
      return true;
    } catch (e) {
      _setError('Failed to enable DAC: $e');
      return false;
    }
  }

  /// Disable DAC output
  Future<bool> disableDAC() async {
    if (!isConnected) return false;
    try {
      await _writeDAC(dacDisableCommand);
      return true;
    } catch (e) {
      _setError('Failed to disable DAC: $e');
      return false;
    }
  }

  /// Read ADC values from device
  Future<ADCReading?> readADC() async {
    if (!isConnected || _characteristic == null) return null;

    try {
      if (!_characteristic!.properties.read) {
        throw Exception('Characteristic does not support reading');
      }

      final data = await _characteristic!.read();
      if (data.length < 8) {
        throw Exception('Invalid ADC data length: ${data.length}');
      }

      _lastReading = ADCReading.fromBytes(data);
      notifyListeners();
      return _lastReading;
    } catch (e) {
      debugPrint('ADC read error: $e');
      return null;
    }
  }

  /// Start automatic ADC polling with specific interval
  void _startADCPolling(Duration interval) {
    _stopADCPolling();
    _adcPollTimer = Timer.periodic(interval, (_) {
      readADC();
    });
  }

  /// Stop ADC polling
  void _stopADCPolling() {
    _adcPollTimer?.cancel();
    _adcPollTimer = null;
  }

  /// Convert current (mA) to DAC value (0-255)
  /// Circuit characteristic: Higher DAC voltage = Lower current
  /// DAC 0V (value 0) = Max current (~2.48 mA)
  /// DAC 3.3V (value 255) = Min current (~0 mA)
  int _currentToDAC(double currentMA) {
    if (currentMA <= 0.0) return dacOffValue; // 255 = off
    if (currentMA >= 2.48) return 0; // Max current

    // Reverse calculation: V = 2.5 * (2.48 - I) / 2.48
    const double maxOutputCurrentMA = 2.48;
    const double currentCutoffVoltage = 2.5;
    const double dacVoltageMax = 3.3;

    final requiredVoltage =
        currentCutoffVoltage * (maxOutputCurrentMA - currentMA) / maxOutputCurrentMA;
    final dacValue = ((requiredVoltage / dacVoltageMax) * 255.0).round();
    return dacValue.clamp(0, 255);
  }

  /// Write DAC value to characteristic
  Future<void> _writeDAC(int value) async {
    if (_characteristic == null) {
      throw Exception('Characteristic not available');
    }

    if (value < 0 || value > 255) {
      throw ArgumentError('DAC value must be 0-255, got $value');
    }

    await _characteristic!.write(
      [value],
      withoutResponse: _characteristic!.properties.writeWithoutResponse,
    );
  }

  /// Update connection state
  void _setConnectionState(BLEConnectionState state) {
    _connectionState = state;
    notifyListeners();
  }

  /// Set error message
  void _setError(String message) {
    _errorMessage = message;
    _connectionState = BLEConnectionState.error;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    if (_connectionState == BLEConnectionState.error) {
      _connectionState = BLEConnectionState.disconnected;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopADCPolling();
    disconnect();
    super.dispose();
  }
}
