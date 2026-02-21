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
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        final isConnected = bleService.isConnected;
        final hasData = bleService.lastReading != null;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Header & Status
              _buildHeader(context, bleService),

              const SizedBox(height: 20),

              if (!isConnected)
                Expanded(
                  child: Center(
                    child: _MonitorEmptyState(
                      icon: Icons.bluetooth_disabled,
                      title: 'Device Disconnected',
                      subtitle: 'Connect to an opentDCS device to view real-time data.',
                    ),
                  ),
                )
              else if (!hasData)
                const Expanded(
                  child: Center(
                    child: _MonitorEmptyState(
                      icon: Icons.sensors_off,
                      title: 'No Data Yet',
                      subtitle: 'Waiting for the first reading from the device...',
                    ),
                  ),
                )
              else
                Expanded(child: _buildADCDisplay(context, bleService)),

              // Manual refresh button (Optional in MD3, but useful here)
              if (isConnected)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: FilledButton.icon(
                    onPressed: () => bleService.readADC(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('REFRESH NOW'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasData = bleService.lastReading != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Live Monitoring',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (hasData)
              Text(
                'Last updated: ${_formatTime(bleService.lastReading!.timestamp)}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        if (bleService.isConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 14, color: colorScheme.onSecondaryContainer),
                const SizedBox(width: 4),
                Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: colorScheme.onSecondaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildADCDisplay(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    final reading = bleService.lastReading!;
    final intensity = bleService.currentIntensityMA > 0
        ? bleService.currentIntensityMA
        : 0.0;

    final referenceCurrent = intensity > 0 ? intensity : _idleReferenceCurrentMA;

    final calculator = ElectricalCalculator(
      reading: reading,
      targetCurrentMA: referenceCurrent,
    );

    final quality = calculator.getQuality();

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Quality & Impedance Summary
        _buildQualityCard(context, quality, calculator.loadResistanceKOhms),

        const SizedBox(height: 20),

        // Calculated Values Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.3,
          children: [
            _buildADCCard(
              context,
              'Source',
              '${calculator.sourceVoltage.toStringAsFixed(2)} V',
              colorScheme.primary,
              Icons.power,
            ),
            _buildADCCard(
              context,
              'Current',
              '${calculator.loadCurrentMA.toStringAsFixed(2)} mA',
              colorScheme.secondary,
              Icons.bolt,
            ),
            _buildADCCard(
              context,
              'Load',
              '${calculator.loadVoltage.toStringAsFixed(2)} V',
              Colors.orange,
              Icons.ev_station,
            ),
            _buildADCCard(
              context,
              'Resistance',
              '${calculator.loadResistanceKOhms.toStringAsFixed(1)} kΩ',
              Colors.purple,
              Icons.straighten,
            ),
          ],
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
        label = 'GOOD CONTACT';
        icon = Icons.check_circle;
        break;
      case ConnectionQuality.fair:
        color = Colors.orange;
        label = 'FAIR CONTACT';
        icon = Icons.info;
        break;
      case ConnectionQuality.poor:
        color = colorScheme.error;
        label = 'POOR CONTACT';
        icon = Icons.error;
        break;
      case ConnectionQuality.unknown:
        color = colorScheme.onSurfaceVariant;
        label = 'CALCULATING...';
        icon = Icons.help;
        break;
    }

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: color,
                  ),
                ),
              ],
            ),
            if (impedance != null) ...[
              const SizedBox(height: 16),
              Text(
                '${impedance.toStringAsFixed(2)} kΩ',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Load Resistance',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildADCCard(BuildContext context, String label, String value, Color color, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

class _MonitorEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _MonitorEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 80, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2)),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

