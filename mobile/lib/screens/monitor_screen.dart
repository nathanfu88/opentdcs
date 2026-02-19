import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../models/models.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

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
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text('Not connected. Connect to view ADC data.'),
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
              const SizedBox(height: 8),
              Text(
                'Updates every 5 seconds',
                style: TextStyle(color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              // ADC values display
              if (bleService.lastReading != null)
                Expanded(
                  child: _buildADCDisplay(bleService.lastReading!),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sensors_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bleService.isConnected
                              ? 'Waiting for ADC data...'
                              : 'No data available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
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
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildADCDisplay(ADCReading reading) {
    return Column(
      children: [
        // Timestamp
        Card(
          color: Colors.grey.shade100,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Last updated: ${_formatTime(reading.timestamp)}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ADC values
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildADCCard('ADC 1', reading.adc1Voltage, Colors.blue),
              _buildADCCard('ADC 2', reading.adc2Voltage, Colors.green),
              _buildADCCard('ADC 3', reading.adc3Voltage, Colors.orange),
              _buildADCCard('ADC 4', reading.adc4Voltage, Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildADCCard(String label, double voltage, Color color) {
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              voltage.toStringAsFixed(3),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Volts',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
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
