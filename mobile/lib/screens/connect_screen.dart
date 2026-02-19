import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ble_service.dart';
import '../models/models.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Device'),
        backgroundColor: Colors.cyan,
      ),
      body: Consumer<BLEService>(
        builder: (context, bleService, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status indicator
                _buildStatusCard(bleService),
                const SizedBox(height: 16),

                // Scan button
                if (bleService.connectionState == BLEConnectionState.disconnected)
                  ElevatedButton.icon(
                    onPressed: () => bleService.scanForDevices(),
                    icon: const Icon(Icons.bluetooth_searching),
                    label: const Text('SCAN FOR DEVICES'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.white,
                    ),
                  ),

                const SizedBox(height: 24),

                // Device list
                if (bleService.connectionState == BLEConnectionState.scanning)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Scanning for devices...'),
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
                                  leading: const Icon(
                                    Icons.bluetooth,
                                    color: Colors.cyan,
                                  ),
                                  title: Text(
                                    device.platformName.isNotEmpty
                                        ? device.platformName
                                        : 'Unknown Device',
                                  ),
                                  subtitle: Text(device.remoteId.toString()),
                                  trailing: bleService.connectionState ==
                                          BLEConnectionState.connecting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
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

  Widget _buildStatusCard(BLEService bleService) {
    String status;
    Color color;
    IconData icon;

    switch (bleService.connectionState) {
      case BLEConnectionState.disconnected:
        status = 'Disconnected';
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        break;
      case BLEConnectionState.scanning:
        status = 'Scanning...';
        color = Colors.blue;
        icon = Icons.bluetooth_searching;
        break;
      case BLEConnectionState.connecting:
        status = 'Connecting...';
        color = Colors.orange;
        icon = Icons.bluetooth_connected;
        break;
      case BLEConnectionState.connected:
        status = 'Connected to ${bleService.connectedDevice?.platformName}';
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case BLEConnectionState.error:
        status = 'Error';
        color = Colors.red;
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
