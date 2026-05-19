import 'dart:async';
import 'dart:convert';
import 'dart:io';

// Alias to avoid collision with our own BluetoothService class
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as blue;

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  blue.BluetoothDevice? _connectedDevice;
  blue.BluetoothCharacteristic? _txCharacteristic;

  // Stream checks
  Stream<List<blue.ScanResult>> get scanResults =>
      blue.FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => blue.FlutterBluePlus.isScanning;

  // Connection state (internal)
  final _connectionStateController =
      StreamController<blue.BluetoothConnectionState>.broadcast();
  Stream<blue.BluetoothConnectionState> get connectionState =>
      _connectionStateController.stream;

  // Backward compatibility: Stream<bool>
  Stream<bool> get connectionStream => _connectionStateController.stream
      .map((s) => s == blue.BluetoothConnectionState.connected);

  // Backward compatibility: bool isConnected
  bool get isConnected => _connectedDevice != null && _txCharacteristic != null;

  // Incoming data
  final _dataController = StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataController.stream;

  blue.BluetoothDevice? get connectedDevice => _connectedDevice;

  // HM-10 Defaults
  static const String SERVICE_UUID = "FFE0";
  static const String CHARACTERISTIC_UUID = "FFE1";

  Future<void> ensureBluetoothReady() async {
    // Check if adapter is on
    if (await blue.FlutterBluePlus.adapterState.first ==
        blue.BluetoothAdapterState.off) {
      if (Platform.isAndroid) {
        await blue.FlutterBluePlus.turnOn();
      }
    }
  }

  Future<void> startScan() async {
    await ensureBluetoothReady();
    // Start scanning
    await blue.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
  }

  Future<void> stopScan() async {
    await blue.FlutterBluePlus.stopScan();
  }

  Future<void> connect(blue.BluetoothDevice device) async {
    await stopScan();

    // Connect
    await device.connect(autoConnect: false);

    _connectedDevice = device;

    // Listen to connection state
    device.connectionState.listen((state) {
      _connectionStateController.add(state);
      if (state == blue.BluetoothConnectionState.disconnected) {
        _cleanup();
      }
    });

    // Discover services (returns List<blue.BluetoothService>)
    List<blue.BluetoothService> services = await device.discoverServices();

    // Find HM-10 Service (FFE0) and Characteristic (FFE1)
    for (var s in services) {
      if (s.uuid.toString().toUpperCase().contains(SERVICE_UUID)) {
        for (var c in s.characteristics) {
          if (c.uuid.toString().toUpperCase().contains(CHARACTERISTIC_UUID)) {
            _txCharacteristic = c;

            // Setup notifications
            if (c.properties.notify) {
              await c.setNotifyValue(true);
              c.onValueReceived.listen((value) {
                String data = utf8.decode(value);
                _dataController.add(data);
              });
            }
          }
        }
      }
    }

    if (_txCharacteristic == null) {
      print("CRITICAL: HM-10 Service/Characteristic NOT FOUND");
    }
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _cleanup();
  }

  void _cleanup() {
    _connectedDevice = null;
    _txCharacteristic = null;
  }

  Future<bool> sendCommand(String command) async {
    if (_txCharacteristic == null) {
      print("Cannot send: No characteristic found");
      return false;
    }

    String payload = command.trim() + "\n";
    try {
      await _txCharacteristic!
          .write(utf8.encode(payload), withoutResponse: false);
      return true;
    } catch (e) {
      print("Send command failed: $e");
      return false;
    }
  }
}
