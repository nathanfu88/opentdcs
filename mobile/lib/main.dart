import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'screens/connect_screen.dart';
import 'screens/control_screen.dart';
import 'screens/monitor_screen.dart';
import 'models/models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BLEService(),
      child: MaterialApp(
        title: 'opentDCS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.black,
          primarySwatch: Colors.cyan,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.cyan,
            brightness: Brightness.dark,
            surface: const Color(0xFF121212),
            onSurface: Colors.white,
            primary: Colors.cyan,
            secondary: Colors.amber,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1A1A1A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.cyan,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
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
  void initState() {
    super.initState();
    // Attempt to auto-reconnect to last device on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BLEService>().autoConnect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('opentDCS'),
            backgroundColor: Colors.black,
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
          body: Column(
            children: [
              _buildSystemStatusBar(bleService),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
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

  Widget _buildSystemStatusBar(BLEService bleService) {
    String status = 'DISCONNECTED';
    Color color = Colors.grey;
    IconData icon = Icons.bluetooth_disabled;

    if (bleService.isConnected) {
      if (bleService.isSessionRunning) {
        final quality = bleService.lastReading?.getQuality(bleService.currentIntensityMA);
        if (quality == ConnectionQuality.poor) {
          status = 'LEAD FAULT DETECTED';
          color = Colors.red;
          icon = Icons.warning_amber;
        } else {
          status = 'STIMULATING';
          color = Colors.cyan;
          icon = Icons.bolt;
        }
      } else {
        status = 'SYSTEM READY';
        color = Colors.green;
        icon = Icons.check_circle_outline;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      color: color.withValues(alpha: 0.15),
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

  Widget _buildConnectionChip(BLEService bleService) {
    final isConnected = bleService.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.cyan.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.cyan : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            size: 14,
            color: isConnected ? Colors.cyan : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'CONNECTED' : 'OFFLINE',
            style: TextStyle(
              color: isConnected ? Colors.cyan : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
