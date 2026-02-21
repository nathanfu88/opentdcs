import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../models/models.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-scan on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BLEService>().scanForDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        final isScanning = bleService.connectionState == BLEConnectionState.scanning;
        final hasDevices = bleService.discoveredDevices.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Device Connection'),
            actions: [
              IconButton(
                onPressed: isScanning ? null : () => bleService.scanForDevices(),
                icon: const Icon(Icons.refresh),
                tooltip: 'Scan for devices',
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => bleService.scanForDevices(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Status indicator
                  _buildStatusBanner(context, bleService),

                  const SizedBox(height: 24),

                  // Device list header
                  if (hasDevices || isScanning)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'AVAILABLE DEVICES',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isScanning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Device list
                  if (!hasDevices && !isScanning)
                    Expanded(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bluetooth_searching,
                                    size: 80,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    'No Devices Found',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Make sure your opentDCS device is powered on and within range.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: bleService.discoveredDevices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final device = bleService.discoveredDevices[index];
                          final isConnecting = bleService.connectionState == BLEConnectionState.connecting &&
                              bleService.connectedDevice?.remoteId == device.remoteId;

                          return _DeviceTile(
                            device: device,
                            isConnecting: isConnecting,
                            onTap: () async {
                              final success = await bleService.connect(device);
                              if (success && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                          );
                        },
                      ),
                    ),

                  // Error message
                  if (bleService.errorMessage != null)
                    _ErrorBanner(
                      message: bleService.errorMessage!,
                      onClear: () => bleService.clearError(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(BuildContext context, BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    String status;
    Color color;
    IconData icon;

    switch (bleService.connectionState) {
      case BLEConnectionState.disconnected:
        status = 'READY TO SCAN';
        color = colorScheme.primary;
        icon = Icons.bluetooth;
        break;
      case BLEConnectionState.scanning:
        status = 'SCANNING FOR DEVICES';
        color = colorScheme.primary;
        icon = Icons.search;
        break;
      case BLEConnectionState.connecting:
        status = 'CONNECTING...';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case BLEConnectionState.connected:
        status = 'CONNECTED';
        color = colorScheme.secondary;
        icon = Icons.bluetooth_connected;
        break;
      case BLEConnectionState.error:
        status = 'CONNECTION ERROR';
        color = colorScheme.error;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final bool isConnecting;
  final VoidCallback onTap;

  const _DeviceTile({
    required this.device,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.bluetooth, color: colorScheme.primary),
        ),
        title: Text(
          device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          device.remoteId.toString(),
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: isConnecting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        onTap: isConnecting ? null : onTap,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onClear;

  const _ErrorBanner({required this.message, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(top: 16, bottom: 20),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: colorScheme.onErrorContainer),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
