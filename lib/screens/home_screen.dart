import 'package:flutter/material.dart';
import 'connection_screen.dart';
import 'relays_screen.dart';
import 'lighting_screen.dart';
import 'schedules_screen.dart';
import 'settings_screen.dart';
import 'command_log_screen.dart';
import 'voice_control_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const RelaysScreen(),
    const LightingScreen(),
    const VoiceControlScreen(),
    const SchedulesScreen(),
    const CommandLogScreen(),
    const ConnectionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.power),
            label: 'Switchs',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb),
            label: 'Lighting',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic),
            label: 'Voice',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule),
            label: 'Schedules',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            label: 'Connection',
          ),
        ],
      ),
    );
  }
}
