import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../models/models.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Device'),
        backgroundColor: Colors.transparent, // Let theme handle it or use transparent
      ),
      body: Consumer<BLEService>(
        builder: (context, bleService, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status indicator
                _buildStatusCard(context, bleService),
                const SizedBox(height: 16),

                // Scan button
                if (bleService.connectionState == BLEConnectionState.disconnected)
                  ElevatedButton.icon(
                    onPressed: () => bleService.scanForDevices(),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('SCAN FOR DEVICES'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),

                const SizedBox(height: 24),

                // Device list
                if (bleService.connectionState == BLEConnectionState.scanning)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: colorScheme.primary),
                        const SizedBox(height: 16),
                        const Text('Scanning for devices...'),
                      ],
                    ),
                  ),

                if (bleService.discoveredDevices.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Found ${bleService.discoveredDevices.length} device(s):',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: bleService.discoveredDevices.length,
                            itemBuilder: (context, index) {
                              final device =
                                  bleService.discoveredDevices[index];
                              return Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.bluetooth,
                                    color: colorScheme.primary,
                                  ),
                                  title: Text(
                                    device.platformName.isNotEmpty
                                        ? device.platformName
                                        : 'Unknown Device',
                                  ),
                                  subtitle: Text(device.remoteId.toString()),
                                  trailing: bleService.connectionState ==
                                          BLEConnectionState.connecting
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.primary,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_ios),
                                  onTap: () async {
                                    final success =
                                        await bleService.connect(device);
                                    if (success && context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Error message
                if (bleService.errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            bleService.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => bleService.clearError(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    String status;
    Color color;
    IconData icon;

    switch (bleService.connectionState) {
      case BLEConnectionState.disconnected:
        status = 'Disconnected';
        color = colorScheme.onSurface.withValues(alpha: 0.5);
        icon = Icons.bluetooth_disabled;
        break;
      case BLEConnectionState.scanning:
        status = 'Scanning...';
        color = colorScheme.primary;
        icon = Icons.bluetooth_searching;
        break;
      case BLEConnectionState.connecting:
        status = 'Connecting...';
        color = Colors.orangeAccent;
        icon = Icons.bluetooth_connected;
        break;
      case BLEConnectionState.connected:
        status = 'Connected to ${bleService.connectedDevice?.platformName}';
        color = colorScheme.secondary;
        icon = Icons.bluetooth_connected;
        break;
      case BLEConnectionState.error:
        status = 'Error';
        color = colorScheme.error;
        icon = Icons.error;
        break;
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
