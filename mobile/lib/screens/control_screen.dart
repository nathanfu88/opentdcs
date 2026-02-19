import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../models/models.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // Session configuration
  double _intensityMA = 0.5;
  int _durationMinutes = 20;

  // Session state
  SessionState _sessionState = SessionState.idle;
  Timer? _sessionTimer;
  int _elapsedSeconds = 0;

  // Duration presets
  final List<int> _durationPresets = [10, 20, 30];

  @override
  void dispose() {
    _stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection status
              if (!bleService.isConnected)
                Card(
                  color: Colors.orange.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Not connected to device')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/connect');
                          },
                          child: const Text('Connect'),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Session timer display
              if (_sessionState == SessionState.running) _buildTimerDisplay(),

              const SizedBox(height: 24),

              // Intensity control
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Intensity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_intensityMA.toStringAsFixed(2)} mA',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _intensityMA,
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        label: '${_intensityMA.toStringAsFixed(2)} mA',
                        onChanged: _sessionState == SessionState.idle
                            ? (value) {
                                setState(() {
                                  _intensityMA = value;
                                });
                              }
                            : null,
                      ),
                      const Text(
                        'Range: 0.00 - 2.00 mA (0.1 mA steps)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Duration control
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _durationPresets.map((minutes) {
                          final isSelected = _durationMinutes == minutes;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: ElevatedButton(
                                onPressed: _sessionState == SessionState.idle
                                    ? () {
                                        setState(() {
                                          _durationMinutes = minutes;
                                        });
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? Colors.cyan
                                      : Colors.grey.shade200,
                                  foregroundColor: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                child: Text('$minutes min'),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Session controls
              if (_sessionState == SessionState.idle)
                ElevatedButton.icon(
                  onPressed: bleService.isConnected ? _startSession : null,
                  icon: const Icon(Icons.play_arrow, size: 32),
                  label: const Text(
                    'START SESSION',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _stopSession,
                  icon: const Icon(Icons.stop, size: 32),
                  label: const Text(
                    'STOP SESSION',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerDisplay() {
    final elapsed = Duration(seconds: _elapsedSeconds);
    final total = Duration(minutes: _durationMinutes);
    final remaining = total - elapsed;

    final elapsedStr = _formatDuration(elapsed);
    final remainingStr = _formatDuration(remaining);
    final progress = _elapsedSeconds / total.inSeconds;

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'SESSION RUNNING',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.green,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      elapsedStr,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'of $_durationMinutes min',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Remaining: $remainingStr',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _startSession() async {
    final bleService = context.read<BLEService>();

    // Enable DAC and set intensity
    final enableSuccess = await bleService.enableDAC();
    if (!enableSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to enable DAC')));
      }
      return;
    }

    final setSuccess = await bleService.setIntensity(_intensityMA);
    if (!setSuccess) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to set intensity')),
        );
      }
      return;
    }

    // Start session timer
    setState(() {
      _sessionState = SessionState.running;
      _elapsedSeconds = 0;
    });

    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });

      // Auto-stop when duration complete
      if (_elapsedSeconds >= _durationMinutes * 60) {
        _stopSession();
      }
    });
  }

  Future<void> _stopSession() async {
    // Stop timer
    _sessionTimer?.cancel();
    _sessionTimer = null;

    // Disable DAC
    final bleService = context.read<BLEService>();
    await bleService.disableDAC();
    await bleService.setIntensity(0.0);

    setState(() {
      _sessionState = SessionState.idle;
      _elapsedSeconds = 0;
    });
  }
}
