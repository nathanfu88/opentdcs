import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'screens/connect_screen.dart';
import 'screens/control_screen.dart';
import 'screens/monitor_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BLEService(),
      child: MaterialApp(
        title: 'tDCS Control',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.cyan,
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/connect': (context) => const ConnectScreen(),
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ControlScreen(),
    MonitorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('tDCS Control'),
            backgroundColor: Colors.cyan,
            foregroundColor: Colors.white,
            actions: [
              // Connection status indicator
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: _buildConnectionChip(bleService),
                ),
              ),
              // Disconnect/Connect button
              if (bleService.isConnected)
                IconButton(
                  icon: const Icon(Icons.bluetooth_disabled),
                  tooltip: 'Disconnect',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Disconnect?'),
                        content: const Text(
                          'Are you sure you want to disconnect from the device?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('DISCONNECT'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await bleService.disconnect();
                    }
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.bluetooth),
                  tooltip: 'Connect',
                  onPressed: () {
                    Navigator.pushNamed(context, '/connect');
                  },
                ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: Colors.cyan,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.control_camera),
                label: 'Control',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.monitor_heart),
                label: 'Monitor',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionChip(BLEService bleService) {
    final isConnected = bleService.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
