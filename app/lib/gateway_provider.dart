import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Hardware ceiling shared with the firmware (RoomAlert 6W) and the cloud
// receiver: a unit reports between 1 and this many DS18B20 ports.
const int maxSensors = 6;

enum GatewayState { disconnected, connecting, connected, error }

// How the app gets data:
//  - simulated: fake wandering values, no hardware needed.
//  - wifi:      direct LAN poll of the device's /api/status (Basic Auth).
//  - cloud:     poll the Cloudflare Worker's /api/telemetry read endpoint.
enum ConnectionType { simulated, wifi, cloud }

class SensorPort {
  final int port;
  final String name;
  final double? temp; // null when the port is disconnected
  final bool conn;

  SensorPort({
    required this.port,
    required this.name,
    required this.temp,
    required this.conn,
  });
}

class TelemetrySnapshot {
  final DateTime timestamp;
  final List<SensorPort> ports;

  TelemetrySnapshot({required this.timestamp, required this.ports});

  SensorPort? portById(int id) {
    for (final p in ports) {
      if (p.port == id) return p;
    }
    return null;
  }
}

class GatewayProvider extends ChangeNotifier {
  GatewayState _state = GatewayState.disconnected;
  ConnectionType _type = ConnectionType.simulated;

  // Direct Wi-Fi (LAN) settings — defaults match the firmware's SoftAP + auth.
  String _ipAddress = '192.168.4.1';
  String _wifiUser = 'admin';
  String _wifiPass = 'admin';

  // Cloud settings — point at the deployed Worker and the device's id.
  String _cloudUrl = '';
  String _cloudDeviceId = 'roomalert-6w-01';

  // Simulated-mode only: how many ports to fake (real modes derive this).
  int _simulatedSensorCount = 6;

  final List<TelemetrySnapshot> _history = [];
  TelemetrySnapshot? _current;
  int _selectedPort = 1;
  bool _isPolling = false;
  String? _lastError;

  GatewayState get state => _state;
  ConnectionType get type => _type;
  String get ipAddress => _ipAddress;
  String get wifiUser => _wifiUser;
  String get wifiPass => _wifiPass;
  String get cloudUrl => _cloudUrl;
  String get cloudDeviceId => _cloudDeviceId;
  int get simulatedSensorCount => _simulatedSensorCount;
  TelemetrySnapshot? get current => _current;
  List<TelemetrySnapshot> get history => _history;
  int get selectedPort => _selectedPort;
  String? get lastError => _lastError;

  List<SensorPort> get ports => _current?.ports ?? const [];
  int get connectedCount => ports.where((p) => p.conn).length;

  void setConnectionType(ConnectionType newType) {
    if (_type == newType) return;
    disconnect();
    _type = newType;
    notifyListeners();
  }

  void setIpAddress(String ip) {
    _ipAddress = ip;
    notifyListeners();
  }

  void setWifiCredentials(String user, String pass) {
    _wifiUser = user;
    _wifiPass = pass;
    notifyListeners();
  }

  void setCloudUrl(String url) {
    _cloudUrl = url.trim();
    notifyListeners();
  }

  void setCloudDeviceId(String id) {
    _cloudDeviceId = id.trim();
    notifyListeners();
  }

  void setSimulatedSensorCount(int count) {
    _simulatedSensorCount = count.clamp(1, maxSensors);
    notifyListeners();
  }

  void setSelectedPort(int port) {
    _selectedPort = port;
    notifyListeners();
  }

  Future<void> connect() async {
    _state = GatewayState.connecting;
    _lastError = null;
    notifyListeners();

    _isPolling = true;
    switch (_type) {
      case ConnectionType.simulated:
        _state = GatewayState.connected;
        _startSimulation();
        break;
      case ConnectionType.wifi:
        _startWifiPolling();
        break;
      case ConnectionType.cloud:
        _startCloudPolling();
        break;
    }
    notifyListeners();
  }

  void disconnect() {
    _isPolling = false;
    _state = GatewayState.disconnected;
    notifyListeners();
  }

  void _pushSnapshot(TelemetrySnapshot snapshot) {
    _current = snapshot;
    _history.add(snapshot);
    if (_history.length > 50) _history.removeAt(0);
    if (_selectedPort > snapshot.ports.length && snapshot.ports.isNotEmpty) {
      _selectedPort = snapshot.ports.first.port;
    }
    notifyListeners();
  }

  // --- Simulated -----------------------------------------------------------

  void _startSimulation() async {
    final rng = math.Random();
    final temps =
        List<double>.generate(_simulatedSensorCount, (i) => 22.0 + i * 1.5);
    while (_isPolling && _type == ConnectionType.simulated) {
      for (int i = 0; i < temps.length; i++) {
        temps[i] += (rng.nextDouble() - 0.5);
      }
      final ports = List<SensorPort>.generate(
        _simulatedSensorCount,
        (i) => SensorPort(
          port: i + 1,
          name: 'Zone ${i + 1}',
          temp: double.parse(temps[i].toStringAsFixed(1)),
          conn: true,
        ),
      );
      _pushSnapshot(TelemetrySnapshot(timestamp: DateTime.now(), ports: ports));
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // --- Direct Wi-Fi (device /api/status) -----------------------------------

  void _startWifiPolling() async {
    final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
    while (_isPolling && _type == ConnectionType.wifi) {
      try {
        final res = await http.get(
          Uri.parse('http://$_ipAddress/api/status'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final rawPorts = (data['ports'] as List?) ?? const [];
          final ports = rawPorts.map((p) {
            final m = p as Map<String, dynamic>;
            final conn = m['conn'] == true;
            return SensorPort(
              port: (m['id'] as num).toInt(),
              name: (m['name'] ?? 'Zone ${m['id']}').toString(),
              temp: conn ? (m['temp'] as num?)?.toDouble() : null,
              conn: conn,
            );
          }).toList();
          _markConnected();
          _pushSnapshot(
              TelemetrySnapshot(timestamp: DateTime.now(), ports: ports));
        } else {
          _markError('HTTP ${res.statusCode}');
        }
      } catch (e) {
        _markError(e.toString());
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // --- Cloud (Worker /api/telemetry) ---------------------------------------

  void _startCloudPolling() async {
    while (_isPolling && _type == ConnectionType.cloud) {
      if (_cloudUrl.isEmpty) {
        _markError('Cloud URL not set');
        await Future.delayed(const Duration(seconds: 3));
        continue;
      }
      try {
        final uri = Uri.parse(
            '$_cloudUrl/api/telemetry?deviceId=$_cloudDeviceId&limit=50');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          final readings = (data['readings'] as List?) ?? const [];
          // Worker returns newest-first; reverse to oldest-first for the trend.
          final snapshots = readings.reversed
              .map((r) => _snapshotFromReading(r as Map<String, dynamic>))
              .toList();
          _markConnected();
          _replaceHistory(snapshots);
        } else {
          _markError('HTTP ${res.statusCode}');
        }
      } catch (e) {
        _markError(e.toString());
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  TelemetrySnapshot _snapshotFromReading(Map<String, dynamic> reading) {
    final rawSensors = (reading['sensors'] as List?) ?? const [];
    final ports = rawSensors.map((s) {
      final m = s as Map<String, dynamic>;
      final conn = m['conn'] == true;
      return SensorPort(
        port: (m['port'] as num).toInt(),
        name: 'Zone ${m['port']}',
        temp: conn ? (m['temp'] as num?)?.toDouble() : null,
        conn: conn,
      );
    }).toList();
    final ts = DateTime.tryParse(reading['timestamp']?.toString() ?? '') ??
        DateTime.now();
    return TelemetrySnapshot(timestamp: ts, ports: ports);
  }

  void _replaceHistory(List<TelemetrySnapshot> snapshots) {
    _history
      ..clear()
      ..addAll(snapshots.length > 50
          ? snapshots.sublist(snapshots.length - 50)
          : snapshots);
    _current = _history.isNotEmpty ? _history.last : null;
    if (_current != null &&
        _selectedPort > _current!.ports.length &&
        _current!.ports.isNotEmpty) {
      _selectedPort = _current!.ports.first.port;
    }
    notifyListeners();
  }

  void _markConnected() {
    if (_state != GatewayState.connected) {
      _state = GatewayState.connected;
      _lastError = null;
    }
  }

  void _markError(String message) {
    _lastError = message;
    if (_state == GatewayState.connected || _state == GatewayState.connecting) {
      _state = GatewayState.error;
      notifyListeners();
    }
  }
}
