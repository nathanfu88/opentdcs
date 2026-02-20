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
    final colorScheme = Theme.of(context).colorScheme;
    
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        final isRunning = bleService.isSessionRunning;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Connection status
              if (!bleService.isConnected)
                Card(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: colorScheme.error),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Not connected to device')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/connect');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                          child: const Text('Connect'),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Session timer display (Optimized with Selector)
              if (isRunning)
                const _SessionTimerDisplay()
              else
                const SizedBox.shrink(),

              if (isRunning) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => bleService.stopSession(),
                    icon: const Icon(Icons.stop, size: 40),
                    label: const Text(
                      'EMERGENCY STOP',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],

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
                            isRunning
                                ? '${bleService.currentIntensityMA.toStringAsFixed(2)} mA'
                                : '${_intensityMA.toStringAsFixed(2)} mA',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: !isRunning
                                ? () {
                                    setState(() {
                                      _intensityMA = (_intensityMA - 0.1).clamp(0.0, 2.0);
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: colorScheme.primary,
                          ),
                          Expanded(
                            child: Slider(
                              value: isRunning ? bleService.currentIntensityMA : _intensityMA,
                              activeColor: colorScheme.primary,
                              inactiveColor: colorScheme.primary.withValues(alpha: 0.2),
                              min: 0.0,
                              max: 2.0,
                              divisions: 20,
                              label: isRunning
                                  ? '${bleService.currentIntensityMA.toStringAsFixed(2)} mA'
                                  : '${_intensityMA.toStringAsFixed(2)} mA',
                              onChanged: !isRunning
                                  ? (value) {
                                      setState(() {
                                        _intensityMA = value;
                                      });
                                    }
                                  : null,
                            ),
                          ),
                          IconButton(
                            onPressed: !isRunning
                                ? () {
                                    setState(() {
                                      _intensityMA = (_intensityMA + 0.1).clamp(0.0, 2.0);
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: colorScheme.primary,
                          ),
                        ],
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
                          final isSelected = isRunning
                              ? (bleService.sessionDurationSeconds ~/ 60) == minutes
                              : _durationMinutes == minutes;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: ElevatedButton(
                                onPressed: !isRunning
                                    ? () {
                                        setState(() {
                                          _durationMinutes = minutes;
                                        });
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  foregroundColor: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                  elevation: isSelected ? 2 : 0,
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

              const SizedBox(height: 32),

              // Pre-start quality check
              if (!isRunning && bleService.isConnected)
                _buildPreStartQuality(context, bleService),

              const SizedBox(height: 16),

              // Session controls
              if (!isRunning)
                SwipeToStart(
                  onComplete: bleService.isConnected
                      ? () => bleService.startSession(_intensityMA, _durationMinutes)
                      : null,
                  enabled: bleService.isConnected,
                ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildPreStartQuality(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    final reading = bleService.lastReading;
    if (reading == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
          ),
          const SizedBox(width: 8),
          const Text(
            'Checking lead quality...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    // Use current intensity setting or 0.5 as reference
    final quality = reading.getQuality(_intensityMA > 0.1 ? _intensityMA : 0.5);
    Color color;
    String label;
    IconData icon;

    switch (quality) {
      case ConnectionQuality.good:
        color = colorScheme.secondary;
        label = 'Good Contact';
        icon = Icons.check_circle_outline;
        break;
      case ConnectionQuality.fair:
        color = Colors.orangeAccent;
        label = 'Fair Contact';
        icon = Icons.info_outline;
        break;
      case ConnectionQuality.poor:
        color = colorScheme.error;
        label = 'Poor Contact';
        icon = Icons.error_outline;
        break;
      case ConnectionQuality.unknown:
        color = colorScheme.onSurface.withValues(alpha: 0.5);
        label = 'Unknown Contact';
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
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
        color: widget.enabled ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLow,
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
