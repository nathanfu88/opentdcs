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
  // Session configuration (local until start)
  double _intensityMA = 0.5;
  int _durationMinutes = 20;

  // Duration presets
  final List<int> _durationPresets = [10, 20, 30];

  @override
  Widget build(BuildContext context) {
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        final isRunning = bleService.isSessionRunning;
        final isConnected = bleService.isConnected;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // System Status Banner (Only when connected)
              if (isConnected) _SystemStatusBanner(bleService: bleService),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Connection status (Modernized)
                    if (!isConnected)
                      _DisconnectedCard(onConnect: () {
                        Navigator.pushNamed(context, '/connect');
                      }),

                    const SizedBox(height: 12),

                    // Session timer display (Optimized with Selector)
                    if (isRunning)
                      const _SessionTimerDisplay()
                    else
                      const SizedBox.shrink(),

                    if (isRunning) ...[
                      const SizedBox(height: 24),
                      _EmergencyStopButton(onPressed: () => bleService.stopSession()),
                    ],

                    const SizedBox(height: 24),

                    // Intensity control
                    _IntensityControlCard(
                      isRunning: isRunning,
                      currentIntensityMA: isRunning ? bleService.currentIntensityMA : _intensityMA,
                      onChanged: (value) {
                        setState(() {
                          _intensityMA = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Duration control
                    _DurationControlCard(
                      isRunning: isRunning,
                      selectedDuration: isRunning
                          ? (bleService.sessionDurationSeconds ~/ 60)
                          : _durationMinutes,
                      presets: _durationPresets,
                      onChanged: (value) {
                        setState(() {
                          _durationMinutes = value;
                        });
                      },
                    ),

                    const SizedBox(height: 32),

                    // Pre-start quality check
                    if (!isRunning && isConnected)
                      _buildPreStartQuality(context, bleService),

                    const SizedBox(height: 24),

                    // Session controls
                    if (!isRunning)
                      SwipeToStart(
                        onComplete: isConnected
                            ? () => bleService.startSession(_intensityMA, _durationMinutes)
                            : null,
                        enabled: isConnected,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreStartQuality(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    final reading = bleService.lastReading;
    if (reading == null) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'Checking lead quality...',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final quality = reading.getQuality(_intensityMA > 0.1 ? _intensityMA : 0.5);
    Color color;
    String label;
    IconData icon;

    switch (quality) {
      case ConnectionQuality.good:
        color = colorScheme.secondary;
        label = 'Good Contact';
        icon = Icons.check_circle;
        break;
      case ConnectionQuality.fair:
        color = Colors.orange;
        label = 'Fair Contact';
        icon = Icons.info;
        break;
      case ConnectionQuality.poor:
        color = colorScheme.error;
        label = 'Poor Contact';
        icon = Icons.error;
        break;
      case ConnectionQuality.unknown:
        color = colorScheme.onSurfaceVariant;
        label = 'Unknown Contact';
        icon = Icons.help;
        break;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusBanner extends StatelessWidget {
  final BLEService bleService;

  const _SystemStatusBanner({required this.bleService});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String status = 'SYSTEM READY';
    Color color = colorScheme.secondary;
    IconData icon = Icons.check_circle_outline;

    if (bleService.isSessionRunning) {
      final quality = bleService.lastReading?.getQuality(
        bleService.currentIntensityMA,
      );
      if (quality == ConnectionQuality.poor) {
        status = 'LEAD FAULT DETECTED';
        color = colorScheme.error;
        icon = Icons.warning_amber;
      } else {
        status = 'SESSION ACTIVE';
        color = colorScheme.primary;
        icon = Icons.bolt;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: color.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisconnectedCard extends StatelessWidget {
  final VoidCallback onConnect;

  const _DisconnectedCard({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(Icons.bluetooth_disabled, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'No Device Connected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to an openTDC device to begin stimulation.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.search),
              label: const Text('SEARCH FOR DEVICES'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntensityControlCard extends StatelessWidget {
  final bool isRunning;
  final double currentIntensityMA;
  final ValueChanged<double> onChanged;

  const _IntensityControlCard({
    required this.isRunning,
    required this.currentIntensityMA,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isRunning ? colorScheme.surface : colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Intensity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${currentIntensityMA.toStringAsFixed(2)} mA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _IntensityButton(
                  icon: Icons.remove,
                  onPressed: !isRunning
                      ? () => onChanged((currentIntensityMA - 0.1).clamp(0.0, 2.0))
                      : null,
                ),
                Expanded(
                  child: Slider(
                    value: currentIntensityMA,
                    min: 0.0,
                    max: 2.0,
                    divisions: 20,
                    onChanged: !isRunning ? onChanged : null,
                  ),
                ),
                _IntensityButton(
                  icon: Icons.add,
                  onPressed: !isRunning
                      ? () => onChanged((currentIntensityMA + 0.1).clamp(0.0, 2.0))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Range: 0.00 - 2.00 mA (0.1 mA steps)',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntensityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _IntensityButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _DurationControlCard extends StatelessWidget {
  final bool isRunning;
  final int selectedDuration;
  final List<int> presets;
  final ValueChanged<int> onChanged;

  const _DurationControlCard({
    required this.isRunning,
    required this.selectedDuration,
    required this.presets,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isRunning ? colorScheme.surface : colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: presets.map((m) {
                  return ButtonSegment<int>(
                    value: m,
                    label: Text('$m min'),
                  );
                }).toList(),
                selected: {selectedDuration},
                onSelectionChanged: !isRunning
                    ? (Set<int> newSelection) {
                        onChanged(newSelection.first);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyStopButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmergencyStopButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.stop, size: 28),
      label: const Text(
        'EMERGENCY STOP',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// A slider that requires a full swipe to trigger an action
class SwipeToStart extends StatefulWidget {
  final VoidCallback? onComplete;
  final bool enabled;

  const SwipeToStart({super.key, this.onComplete, this.enabled = true});

  @override
  State<SwipeToStart> createState() => _SwipeToStartState();
}

class _SwipeToStartState extends State<SwipeToStart> {
  double _position = 0.0;
  bool _isComplete = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      height: 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.enabled ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(35),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxSlide = constraints.maxWidth - 70;
          return Stack(
            children: [
              const Center(
                child: Text(
                  'SWIPE TO START',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Positioned(
                left: _position,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.enabled
                      ? (details) {
                          setState(() {
                            _position = (_position + details.delta.dx).clamp(0.0, maxSlide);
                          });
                        }
                      : null,
                  onHorizontalDragEnd: widget.enabled
                      ? (details) {
                          if (_position > maxSlide * 0.8) {
                            setState(() {
                              _position = maxSlide;
                              _isComplete = true;
                            });
                            widget.onComplete?.call();
                            // Reset after a delay
                            Future.delayed(const Duration(seconds: 1), () {
                              if (mounted) {
                                setState(() {
                                  _position = 0.0;
                                  _isComplete = false;
                                });
                              }
                            });
                          } else {
                            setState(() {
                              _position = 0.0;
                            });
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: widget.enabled
                          ? (_isComplete ? colorScheme.secondary : colorScheme.primary)
                          : colorScheme.onSurface.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isComplete ? Icons.check : Icons.arrow_forward_ios,
                      color: widget.enabled ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Specialized timer display that only rebuilds when elapsed time changes
class _SessionTimerDisplay extends StatelessWidget {
  const _SessionTimerDisplay();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Selector<BLEService, (int, int)>(
      selector: (_, service) => (service.elapsedSeconds, service.sessionDurationSeconds),
      builder: (context, data, _) {
        final elapsedSeconds = data.$1;
        final totalSeconds = data.$2;
        
        final elapsed = Duration(seconds: elapsedSeconds);
        final total = Duration(seconds: totalSeconds);
        final remaining = total - elapsed;

        final elapsedStr = _formatDuration(elapsed);
        final remainingStr = _formatDuration(remaining);
        final progress = totalSeconds > 0 ? elapsedSeconds / totalSeconds : 0.0;

        return Card(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  'SESSION RUNNING',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.secondary,
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
                        backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.secondary,
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
                          'of ${totalSeconds ~/ 60} min',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
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
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
