import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  // Bumped on every connect()/disconnect() so a stale polling loop from a
  // previous connection exits instead of running in parallel with the new one.
  int _pollGeneration = 0;
  String? _lastError;

  // C++ Hardware Telemetry Fields
  bool _relayState = false;
  int _uptimeSecs = 0;
  int _sdCap = 0;
  int _sdUsed = 0;
  // Warning thresholds: any online probe outside [min, max] is flagged. In
  // Wi-Fi mode these are overwritten by the device's own configured values.
  double _alarmMax = 25.0;
  double _alarmMin = 10.0;
  List<double> _offsets = List.filled(maxSensors, 0.0);

  bool get relayState => _relayState;
  int get uptimeSecs => _uptimeSecs;
  int get sdCap => _sdCap;
  int get sdUsed => _sdUsed;
  double get alarmMax => _alarmMax;
  double get alarmMin => _alarmMin;
  List<double> get offsets => _offsets;

  GatewayProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final savedType = prefs.getString('connection_type');
      if (savedType != null) {
        _type = ConnectionType.values.firstWhere(
          (e) => e.name == savedType,
          orElse: () => ConnectionType.simulated,
        );
      }
      _ipAddress = prefs.getString('ip_address') ?? '192.168.4.1';
      _wifiUser = prefs.getString('wifi_user') ?? 'admin';
      _wifiPass = prefs.getString('wifi_pass') ?? 'admin';
      _cloudUrl = prefs.getString('cloud_url') ?? '';
      _cloudDeviceId = prefs.getString('cloud_device_id') ?? 'roomalert-6w-01';
      _simulatedSensorCount = prefs.getInt('simulated_sensor_count') ?? 6;
      _alarmMax = prefs.getDouble('alarm_max') ?? 25.0;
      _alarmMin = prefs.getDouble('alarm_min') ?? 10.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    } catch (e) {
      debugPrint('Error saving setting $key: $e');
    }
  }

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

  // Threshold classification used across the UI (gauge, port grid, alerts).
  bool isHot(double? temp) => temp != null && temp > _alarmMax;
  bool isCold(double? temp) => temp != null && temp < _alarmMin;
  bool isOutOfRange(double? temp) => isHot(temp) || isCold(temp);

  void setConnectionType(ConnectionType newType) {
    if (_type == newType) return;
    disconnect();
    _type = newType;
    _saveSetting('connection_type', newType.name);
    notifyListeners();
  }

  void setIpAddress(String ip) {
    _ipAddress = ip;
    _saveSetting('ip_address', ip);
    notifyListeners();
  }

  void setWifiCredentials(String user, String pass) {
    _wifiUser = user;
    _wifiPass = pass;
    _saveSetting('wifi_user', user);
    _saveSetting('wifi_pass', pass);
    notifyListeners();
  }

  void setCloudUrl(String url) {
    _cloudUrl = url.trim();
    _saveSetting('cloud_url', _cloudUrl);
    notifyListeners();
  }

  void setCloudDeviceId(String id) {
    _cloudDeviceId = id.trim();
    _saveSetting('cloud_device_id', _cloudDeviceId);
    notifyListeners();
  }

  void setSimulatedSensorCount(int count) {
    _simulatedSensorCount = count.clamp(1, maxSensors);
    _saveSetting('simulated_sensor_count', _simulatedSensorCount);
    notifyListeners();
  }

  void setSelectedPort(int port) {
    _selectedPort = port;
    notifyListeners();
  }

  Future<void> connect() async {
    _state = GatewayState.connecting;
    _lastError = null;

    // Invalidate any in-flight polling loop before starting a fresh one, so
    // repeated connect() calls don't stack up multiple concurrent pollers.
    final gen = ++_pollGeneration;
    _isPolling = true;
    notifyListeners();

    switch (_type) {
      case ConnectionType.simulated:
        _state = GatewayState.connected;
        _startSimulation(gen);
        break;
      case ConnectionType.wifi:
        _startWifiPolling(gen);
        break;
      case ConnectionType.cloud:
        _startCloudPolling(gen);
        break;
    }
    notifyListeners();
  }

  void disconnect() {
    _isPolling = false;
    _pollGeneration++;
    _state = GatewayState.disconnected;
    notifyListeners();
  }

  bool _isCurrent(int gen) => _isPolling && gen == _pollGeneration;

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

  void _startSimulation(int gen) async {
    final rng = math.Random();
    final temps =
        List<double>.generate(_simulatedSensorCount, (i) => 22.0 + i * 1.5);
    while (_isCurrent(gen) && _type == ConnectionType.simulated) {
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
      _uptimeSecs += 2;
      _sdCap = 32;
      _sdUsed = (15 + math.sin(_uptimeSecs / 100) * 3).toInt();
      _pushSnapshot(TelemetrySnapshot(timestamp: DateTime.now(), ports: ports));
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  // --- Direct Wi-Fi (device /api/status) -----------------------------------

  void _startWifiPolling(int gen) async {
    final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
    while (_isCurrent(gen) && _type == ConnectionType.wifi) {
      try {
        final res = await http.get(
          Uri.parse('http://$_ipAddress/api/status'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;

          // Parse hardware variables
          _relayState = data['relay'] == true;
          _uptimeSecs = data['uptime'] as int? ?? 0;
          if (data['sd'] != null) {
            final sdData = data['sd'] as Map<String, dynamic>;
            _sdCap = (sdData['cap'] as num?)?.toInt() ?? 0;
            _sdUsed = (sdData['used'] as num?)?.toInt() ?? 0;
          }
          if (data['thresholds'] != null) {
            final th = data['thresholds'] as Map<String, dynamic>;
            _alarmMax = (th['max'] as num?)?.toDouble() ?? 125.0;
            _alarmMin = (th['min'] as num?)?.toDouble() ?? -55.0;
          }
          if (data['offsets'] != null) {
            final rawOffsets = data['offsets'] as List;
            _offsets = rawOffsets.map((o) => (o as num).toDouble()).toList();
          }

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

  void _startCloudPolling(int gen) async {
    while (_isCurrent(gen) && _type == ConnectionType.cloud) {
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

  // --- ESP32 Hardware Remote Actions --------------------------------------

  Future<void> toggleRelay() async {
    _relayState = !_relayState;
    notifyListeners();
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        final stateVal = _relayState ? '1' : '0';
        final res = await http.post(
          Uri.parse('http://$_ipAddress/api/relay?state=$stateVal'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final data = json.decode(res.body) as Map<String, dynamic>;
          _relayState = data['relay'] == true;
        }
      } catch (e) {
        debugPrint('Error toggling relay: $e');
      }
    }
    notifyListeners();
  }

  Future<void> testBuzzer() async {
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/buzzer'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error testing buzzer: $e');
      }
    }
  }

  Future<void> saveAlarmRules(double maxT, double minT) async {
    _alarmMax = maxT;
    _alarmMin = minT;
    _saveSetting('alarm_max', maxT);
    _saveSetting('alarm_min', minT);
    notifyListeners();
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/thresholds?max=$maxT&min=$minT'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error saving thresholds: $e');
      }
    }
  }

  Future<void> saveOffset(int portId, double offsetVal) async {
    if (portId >= 1 && portId <= _offsets.length) {
      _offsets[portId - 1] = offsetVal;
      notifyListeners();
    }
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/offset?id=$portId&val=$offsetVal'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error saving offset: $e');
      }
    }
  }

  Future<void> renamePort(int portId, String newName) async {
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/rename?id=$portId&name=${Uri.encodeComponent(newName)}'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error renaming port: $e');
      }
    }
  }

  Future<void> clearSDLog() async {
    _sdUsed = 0;
    notifyListeners();
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/sd/clear'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error clearing SD log: $e');
      }
    }
  }

  Future<void> syncTime() async {
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        final epoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await http.post(
          Uri.parse('http://$_ipAddress/api/sync_time'),
          headers: {'Authorization': auth, 'Content-Type': 'application/json'},
          body: json.encode({'unixtime': epoch}),
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error syncing clock: $e');
      }
    }
  }

  Future<void> rebootHub() async {
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/reboot'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error rebooting hub: $e');
      }
    }
  }

  Future<void> saveWifiConfig(String ssid, String pass) async {
    if (_type == ConnectionType.wifi) {
      try {
        final auth = 'Basic ${base64Encode(utf8.encode('$_wifiUser:$_wifiPass'))}';
        await http.post(
          Uri.parse('http://$_ipAddress/api/wifi?ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(pass)}'),
          headers: {'Authorization': auth},
        ).timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Error saving Wi-Fi: $e');
      }
    }
  }
}
