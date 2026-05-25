import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'gateway_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GatewayProvider()),
      ],
      child: const TSenseApp(),
    ),
  );
}

const bgColor = Color(0xFF1B2431);
const sidebarColor = Color(0xFF151D27);
const cardColor = Color(0xFF232C3A);
const accentColor = Color(0xFF38BFA7);
const dangerColor = Color(0xFFEF6F6F);

class TSenseApp extends StatelessWidget {
  const TSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T-Sense',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: bgColor,
        primaryColor: accentColor,
        colorScheme: const ColorScheme.dark(primary: accentColor),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: sidebarColor,
        elevation: 0,
        title: const Text('T-SENSE',
            style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
        actions: [
          const _ConnectionChip(),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsModal(context),
          ),
        ],
      ),
      body: Consumer<GatewayProvider>(
        builder: (context, gateway, _) {
          if (gateway.state == GatewayState.disconnected) {
            return _DisconnectedView(onConnect: () => _showSettingsModal(context));
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 900
                  ? 3
                  : constraints.maxWidth > 560
                      ? 2
                      : 1;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OverviewBar(gateway: gateway),
                    const SizedBox(height: 16),
                    _SensorGrid(
                        gateway: gateway, crossAxisCount: crossAxisCount),
                    const SizedBox(height: 16),
                    SizedBox(height: 320, child: TrendCard(gateway: gateway)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip();

  @override
  Widget build(BuildContext context) {
    return Consumer<GatewayProvider>(
      builder: (context, gateway, _) {
        final connected = gateway.state == GatewayState.connected;
        final error = gateway.state == GatewayState.error;
        final color = error
            ? dangerColor
            : connected
                ? accentColor
                : Colors.grey;
        final label = error
            ? 'ERROR'
            : connected
                ? 'LIVE'
                : gateway.state == GatewayState.connecting
                    ? '...'
                    : 'OFF';
        return Center(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DisconnectedView extends StatelessWidget {
  final VoidCallback onConnect;
  const _DisconnectedView({required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sensors_off, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          const Text('Not connected',
              style: TextStyle(color: Colors.grey, fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor),
            onPressed: onConnect,
            icon: const Icon(Icons.settings, color: Colors.white),
            label: const Text('Choose a source',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _OverviewBar extends StatelessWidget {
  final GatewayProvider gateway;
  const _OverviewBar({required this.gateway});

  @override
  Widget build(BuildContext context) {
    final total = gateway.ports.length;
    final connected = gateway.connectedCount;
    final modeLabel = switch (gateway.type) {
      ConnectionType.simulated => 'Simulated',
      ConnectionType.wifi => 'Direct Wi-Fi',
      ConnectionType.cloud => 'Cloud',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          _stat('$connected/$total', 'SENSORS ONLINE'),
          const SizedBox(width: 24),
          _stat(modeLabel, 'SOURCE'),
          const Spacer(),
          if (gateway.state == GatewayState.error && gateway.lastError != null)
            Flexible(
              child: Text(
                gateway.lastError!,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: dangerColor, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _SensorGrid extends StatelessWidget {
  final GatewayProvider gateway;
  final int crossAxisCount;
  const _SensorGrid({required this.gateway, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final ports = gateway.ports;
    if (ports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
            child: Text('Waiting for data…',
                style: TextStyle(color: Colors.grey))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: ports.length,
      itemBuilder: (context, i) {
        final p = ports[i];
        final selected = p.port == gateway.selectedPort;
        return GestureDetector(
          onTap: () => gateway.setSelectedPort(p.port),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accentColor : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: p.conn ? accentColor : dangerColor,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ),
                  ],
                ),
                Text(
                  p.conn && p.temp != null
                      ? '${p.temp!.toStringAsFixed(1)}°C'
                      : '--.-',
                  style: TextStyle(
                    color: p.conn ? Colors.white : Colors.grey,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TrendCard extends StatelessWidget {
  final GatewayProvider gateway;
  const TrendCard({super.key, required this.gateway});

  @override
  Widget build(BuildContext context) {
    final port = gateway.selectedPort;
    final spots = <FlSpot>[];
    for (int i = 0; i < gateway.history.length; i++) {
      final t = gateway.history[i].portById(port)?.temp;
      if (t != null) spots.add(FlSpot(i.toDouble(), t));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: cardColor, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ZONE $port TREND',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: spots.length < 2
                ? const Center(
                    child: Text('Collecting data…',
                        style: TextStyle(color: Colors.grey)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                            color: Colors.white.withValues(alpha: 0.05),
                            strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, meta) => Text(
                                '${v.toInt()}°',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: accentColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                accentColor.withValues(alpha: 0.3),
                                accentColor.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

void _showSettingsModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1F2733),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      return Consumer<GatewayProvider>(
        builder: (context, gateway, child) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Connection Settings',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _modeButton(gateway, ConnectionType.simulated, 'Simulated',
                        Icons.science),
                    const SizedBox(width: 8),
                    _modeButton(gateway, ConnectionType.wifi, 'ESP32 Wi-Fi',
                        Icons.wifi),
                    const SizedBox(width: 8),
                    _modeButton(gateway, ConnectionType.cloud, 'Cloud',
                        Icons.cloud),
                  ],
                ),
                const SizedBox(height: 20),
                if (gateway.type == ConnectionType.wifi) ...[
                  _field('Device IP Address', gateway.ipAddress,
                      gateway.setIpAddress),
                  const SizedBox(height: 12),
                  _field('Username', gateway.wifiUser,
                      (v) => gateway.setWifiCredentials(v, gateway.wifiPass)),
                  const SizedBox(height: 12),
                  _field('Password', gateway.wifiPass,
                      (v) => gateway.setWifiCredentials(gateway.wifiUser, v),
                      obscure: true),
                ],
                if (gateway.type == ConnectionType.cloud) ...[
                  _field('Worker URL', gateway.cloudUrl, gateway.setCloudUrl,
                      hint: 'https://…workers.dev'),
                  const SizedBox(height: 12),
                  _field('Device ID', gateway.cloudDeviceId,
                      gateway.setCloudDeviceId),
                ],
                if (gateway.type == ConnectionType.simulated)
                  Row(
                    children: [
                      const Text('Simulated sensors:',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: gateway.simulatedSensorCount,
                        dropdownColor: cardColor,
                        items: [
                          for (int n = 1; n <= maxSensors; n++)
                            DropdownMenuItem(value: n, child: Text('$n')),
                        ],
                        onChanged: (v) {
                          if (v != null) gateway.setSimulatedSensorCount(v);
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: accentColor,
                    ),
                    onPressed: () {
                      gateway.connect();
                      Navigator.pop(context);
                    },
                    child: const Text('CONNECT',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _modeButton(GatewayProvider gateway, ConnectionType type, String label,
    IconData icon) {
  final active = gateway.type == type;
  return Expanded(
    child: InkWell(
      onTap: () => gateway.setConnectionType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
              color: active ? accentColor : Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: active ? accentColor : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? Colors.white : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    ),
  );
}

Widget _field(String label, String value, ValueChanged<String> onChanged,
    {bool obscure = false, String? hint}) {
  return TextField(
    controller: TextEditingController(text: value)
      ..selection = TextSelection.collapsed(offset: value.length),
    obscureText: obscure,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
