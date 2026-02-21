import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ble_service.dart';
import 'screens/connect_screen.dart';
import 'screens/control_screen.dart';
import 'screens/monitor_screen.dart';

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
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0056B3),
            primary: const Color(0xFF0056B3),
            onPrimary: Colors.white,
            secondary: const Color(0xFF28A745),
            onSecondary: Colors.white,
            error: const Color(0xFFBA1A1A),
            surface: const Color(0xFFFDFBFF),
            surfaceContainerLow: Colors.white,
            surfaceContainer: const Color(0xFFF3F4F9),
            surfaceContainerHigh: const Color(0xFFE9ECEF),
            outlineVariant: const Color(0xFFC4C7CF),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
           q shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0x1F000000), width: 0.5),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFDFBFF),
            scrolledUnderElevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B1B1F),
            ),
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: const Color(0xFF0056B3).withValues(alpha: 0.1),
              selectedForegroundColor: const Color(0xFF0056B3),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        home: const HomeScreen(),
        routes: {'/connect': (context) => const ConnectScreen()},
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

  final List<Widget> _screens = const [ControlScreen(), MonitorScreen()];

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<BLEService>(
      builder: (context, bleService, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'opentDCS',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            foregroundColor: colorScheme.onSurface,
            actions: [
              // Connection status indicator
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: _buildConnectionStatus(bleService),
              ),
            ],
          ),
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.tune),
                selectedIcon: Icon(Icons.tune),
                label: 'Control',
              ),
              NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Monitor',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(BLEService bleService) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = bleService.isConnected;

    return IconButton(
      onPressed: () {
        if (isConnected) {
          _showDisconnectDialog(context, bleService);
        } else {
          Navigator.pushNamed(context, '/connect');
        }
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          key: ValueKey(isConnected),
          color: isConnected ? colorScheme.primary : colorScheme.error,
        ),
      ),
      tooltip: isConnected ? 'Connected' : 'Disconnected',
    );
  }

  Future<void> _showDisconnectDialog(BuildContext context, BLEService bleService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text(
          'Stop current session and disconnect from the device?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DISCONNECT'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await bleService.disconnect();
    }
  }
}

