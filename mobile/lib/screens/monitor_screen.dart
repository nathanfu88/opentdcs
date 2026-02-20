import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../services/electrical_calculator.dart';
import '../models/models.dart';

class MonitorScreen extends StatelessWidget {
  /// Current used for impedance/quality calculations when session is idle (0mA)
  static const double _idleReferenceCurrentMA = 0.5;

  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: colorScheme.error),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Not connected. Connect to view ADC data.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // ADC readings header
              Text(
                'ADC Readings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (bleService.lastReading != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    'Last updated: ${_formatTime(bleService.lastReading!.timestamp)}',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ADC values display
              if (bleService.lastReading != null)
                Expanded(child: _buildADCDisplay(context, bleService))
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sensors_off,
                          size: 64,
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bleService.isConnected
                              ? 'Waiting for ADC data...'
                              : 'No data available',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Manual refresh button
              if (bleService.isConnected)
                ElevatedButton.icon(
                  onPressed: () => bleService.readADC(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('REFRESH NOW'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildADCDisplay(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    final reading = bleService.lastReading!;
    final intensity = bleService.currentIntensityMA > 0
        ? bleService.currentIntensityMA
        : 0.0;

    // Use actual intensity or default reference for calculations
    final referenceCurrent = intensity > 0 ? intensity : _idleReferenceCurrentMA;

    final calculator = ElectricalCalculator(
      reading: reading,
      targetCurrentMA: referenceCurrent,
    );

    final quality = reading.getQuality(referenceCurrent);

    return Column(
      children: [
        // Quality & Impedance Summary
        _buildQualityCard(context, quality, calculator.loadResistanceKOhms),

        const SizedBox(height: 16),

        // Calculated Values Grid
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildADCCard(
                'Source Voltage',
                '${calculator.sourceVoltage.toStringAsFixed(2)} V',
                colorScheme.secondary,
              ),
              _buildADCCard(
                'Current',
                '${calculator.loadCurrentMA.toStringAsFixed(2)} mA',
                colorScheme.primary,
              ),
              _buildADCCard(
                'Load Voltage',
                '${calculator.loadVoltage.toStringAsFixed(2)} V',
                Colors.orangeAccent,
              ),
              _buildADCCard(
                'Resistance',
                '${calculator.loadResistanceKOhms.toStringAsFixed(1)} kΩ',
                Colors.purpleAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQualityCard(
    BuildContext context,
    ConnectionQuality quality,
    double? impedance,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    Color color;
    String label;
    IconData icon;

    switch (quality) {
      case ConnectionQuality.good:
        color = colorScheme.secondary;
        label = 'GOOD CONNECTION';
        icon = Icons.check_circle;
        break;
      case ConnectionQuality.fair:
        color = Colors.orangeAccent;
        label = 'FAIR CONNECTION';
        icon = Icons.warning;
        break;
      case ConnectionQuality.poor:
        color = colorScheme.error;
        label = 'POOR CONNECTION';
        icon = Icons.error;
        break;
      case ConnectionQuality.unknown:
        color = colorScheme.onSurface.withValues(alpha: 0.5);
        label = 'MEASURING...';
        icon = Icons.help_outline;
        break;
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            if (impedance != null) ...[
              const SizedBox(height: 12),
              Text(
                '${impedance.toStringAsFixed(2)} kΩ',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Estimated Impedance',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildADCCard(String label, String value, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final second = time.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
