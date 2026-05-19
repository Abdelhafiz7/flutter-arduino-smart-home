import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final BluetoothService _bluetooth = BluetoothService();

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  // Connection tracking
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  BluetoothDevice? _connectedDevice;

  late StreamSubscription<List<ScanResult>> _scanSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  late StreamSubscription<BluetoothConnectionState>
      _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();

    // Subscribe to scan results
    _scanSubscription = _bluetooth.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    // Subscribe to scanning state
    _isScanningSubscription = _bluetooth.isScanning.listen((state) {
      if (mounted) {
        setState(() => _isScanning = state);
      }
    });

    // Subscribe to connection state
    _connectionStateSubscription = _bluetooth.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
          _connectedDevice = _bluetooth.connectedDevice;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _isScanningSubscription.cancel();
    _connectionStateSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
      Permission.location,
    ].request();

    print("DEBUG: Scan Status: ${statuses[Permission.bluetoothScan]}");
    print("DEBUG: Connect Status: ${statuses[Permission.bluetoothConnect]}");
    print(
        "DEBUG: LocationWhenInUse Status: ${statuses[Permission.locationWhenInUse]}");
    print("DEBUG: Location (General) Status: ${statuses[Permission.location]}");

    var serviceStatus = await Permission.location.serviceStatus;
    print("DEBUG: Location Service (GPS) Status: $serviceStatus");
  }

  Future<void> _startScan() async {
    print("DEBUG: Attempting startScan...");
    var serviceEnabled = await Permission.location.serviceStatus.isEnabled;
    print("DEBUG: Location Service Enabled? $serviceEnabled");

    // 1. Check if Location Services (GPS) are actually ON
    if (!serviceEnabled) {
      print("DEBUG: BLOCKED - Location Service is OFF");
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Location Required"),
            content: const Text(
                "Bluetooth Low Energy scanning requires Location Services (GPS) to be turned on.\n\nPlease enable it in your phone's Quick Settings."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text("Open App Settings"),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 2. Try Scanning
    try {
      await _bluetooth.startScan();
    } catch (e) {
      if (mounted) {
        String msg = "Scan failed: $e";
        if (e is PlatformException) {
          msg =
              "Scan Error: ${e.message}. \nTry turning on GPS/Location Services.";

          // Retry prompt if we caught it here
          if (e.message?.contains("location") ?? false) {
            showDialog(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text("Location Service Off"),
                      content: const Text(
                          "System Location (GPS) seems to be disabled. Please pull down your notification bar and turn on 'Location'."),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"))
                      ],
                    ));
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  Future<void> _stopScan() async {
    try {
      await _bluetooth.stopScan();
    } catch (e) {
      print("Stop scan error: $e");
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Connect failed: $e")));
      }
    }
  }

  Future<void> _disconnect() async {
    await _bluetooth.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _connectionState == BluetoothConnectionState.connected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Host'),
        actions: [
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopScan,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _startScan,
            ),
        ],
      ),
      body: Column(
        children: [
          // status header
          Container(
            padding: const EdgeInsets.all(16),
            color: isConnected ? Colors.green.shade100 : Colors.grey.shade200,
            child: Row(
              children: [
                Icon(
                    isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: isConnected ? Colors.green : Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isConnected
                        ? "Connected to ${_connectedDevice?.platformName ?? 'Unknown'}"
                        : "Disconnected",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isConnected)
                  TextButton(
                      onPressed: _disconnect, child: const Text("Disconnect"))
              ],
            ),
          ),

          // scan list
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final device = result.device;
                final bool isThisDeviceConnected =
                    (device.remoteId == _connectedDevice?.remoteId) &&
                        isConnected;

                // Better name resolution for BLE
                String name = result.advertisementData.advName;
                if (name.isEmpty) {
                  name = device.platformName;
                }
                if (name.isEmpty) {
                  name = "Unknown Device";
                }

                return ListTile(
                  title: Text(name),
                  subtitle: Text(device.remoteId.toString()),
                  leading: Text("${result.rssi} dBm"),
                  trailing: isThisDeviceConnected
                      ? const Icon(Icons.check, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _connect(device),
                          child: const Text("Connect"),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
