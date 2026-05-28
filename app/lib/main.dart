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

// Elegant Light Theme Palette (Matches User Screenshot)
const bgColor = Color(0xFFF4F7F6);
const sidebarColor = Colors.white;
const cardColor = Colors.white;
const glassBorder = Color(0xFFE2E8F0);
const accentColor = Color(0xFF10B981); // Emerald/Green from screenshot
const successColor = Color(0xFF10B981);
const warningColor = Color(0xFFFB923C);
const dangerColor = Color(0xFFEF4444);

class TSenseApp extends StatelessWidget {
  const TSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'T-Sense',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: bgColor,
        primaryColor: accentColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.light(
          primary: accentColor,
          surface: cardColor,
          background: bgColor,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'Inter',
              bodyColor: const Color(0xFF1E293B),
              displayColor: const Color(0xFF1E293B),
            ),
      ),
      home: const DashboardScreen(),
    );
  }
}

enum UserRole { none, admin, customer }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeNavIndex = 0; // 0: Dashboard, 1: Devices, 2: Alerts, 3: Settings
  UserRole _role = UserRole.none;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GatewayProvider>(
        builder: (context, gateway, _) {
          if (_role == UserRole.none) {
            return _LoginScreen(onLogin: (role) {
              setState(() {
                _role = role;
              });
              if (gateway.state == GatewayState.disconnected) {
                gateway.connect();
              }
            });
          }

          if (_role == UserRole.customer) {
            return _CustomerDashboard(
              onLogout: () {
                setState(() {
                  _role = UserRole.none;
                  _activeNavIndex = 0;
                });
                gateway.disconnect();
              },
            );
          }

          if (gateway.state == GatewayState.disconnected) {
            return _DisconnectedView(
              onConnect: () => _showSettingsModal(context),
              onLogout: () {
                setState(() {
                  _role = UserRole.none;
                  _activeNavIndex = 0;
                });
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 950;
              final isTablet = constraints.maxWidth > 650 && constraints.maxWidth <= 950;

              // Build App Layout
              return Row(
                children: [
                  // Desktop Sidebar
                  if (isDesktop) _buildSidebar(context, gateway),
                  
                  // Main Body
                  Expanded(
                    child: Column(
                      children: [
                        // Glassmorphic Top Header
                        _buildHeader(context, gateway, isDesktop),
                        
                        // Main Scrollable View Dashboard
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: _activeNavIndex == 0
                                ? _buildDashboardView(gateway, isDesktop, isTablet)
                                : _activeNavIndex == 1
                                    ? _buildDevicesView(gateway)
                                    : _activeNavIndex == 2
                                        ? _buildAlertsView(gateway)
                                        : _buildSettingsView(gateway),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 950) {
            return _buildMobileNavBar();
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // --- Layout Helper Builders ---

  Widget _buildSidebar(BuildContext context, GatewayProvider gateway) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: sidebarColor,
        border: Border(right: BorderSide(color: glassBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Brand Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0ABFBC), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.thermostat, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'T-Sense',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'GATEWAY NODE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: Color(0xFF8A99AD),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Sidebar Navigation Items
          _buildSidebarNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
          _buildSidebarNavItem(1, Icons.lan_outlined, Icons.lan, 'Devices & Nodes'),
          _buildSidebarNavItem(2, Icons.notifications_none, Icons.notifications, 'Active Alerts'),
          _buildSidebarNavItem(3, Icons.settings_outlined, Icons.settings, 'Connection Settings'),

          const Spacer(),

          // Bottom Gateway Status Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildPulseIndicator(gateway),
                    const SizedBox(width: 8),
                    Text(
                      gateway.state == GatewayState.connected ? 'LIVE TELEMETRY' : 'CONNECTING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: gateway.state == GatewayState.connected ? successColor : warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Direct LAN/AP Mode',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('IP: ${gateway.ipAddress}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isActive = _activeNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeNavIndex = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? accentColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? accentColor.withOpacity(0.15) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? filledIcon : outlineIcon,
              color: isActive ? accentColor : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isActive ? accentColor : const Color(0xFF475569),
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: sidebarColor,
        border: const Border(top: BorderSide(color: glassBorder)),
      ),
      child: BottomNavigationBar(
        currentIndex: _activeNavIndex,
        onTap: (index) => setState(() => _activeNavIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: accentColor,
        unselectedItemColor: const Color(0xFF94A3B8),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.lan), label: 'Devices'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GatewayProvider gateway, bool isDesktop) {
    final hasError = gateway.state == GatewayState.error;
    final connectedPorts = gateway.connectedCount;
    final totalPorts = gateway.ports.length;
    
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: sidebarColor,
        border: Border(bottom: BorderSide(color: glassBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isDesktop) ...[
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0ABFBC), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.thermostat, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text(
                  'T-SENSE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
          ] else ...[
            // Desktop Section Header Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _activeNavIndex == 0
                      ? 'SYSTEM MONITORING'
                      : _activeNavIndex == 1
                          ? 'GATEWAY CONTROLLER'
                          : _activeNavIndex == 2
                              ? 'SYSTEM ALERTS'
                              : 'GATEWAY SETTINGS',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _activeNavIndex == 0
                      ? 'Live Telemetry Dashboard'
                      : _activeNavIndex == 1
                          ? 'Manage Nodes & Sensors'
                          : _activeNavIndex == 2
                              ? 'Active Warnings & Events'
                              : 'Configure System Uplinks',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ],

          // Right Header Widgets
          Row(
            children: [
              // System Health Indicator Widget
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (hasError
                          ? dangerColor
                          : (connectedPorts == totalPorts && totalPorts > 0)
                              ? successColor
                              : warningColor)
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (hasError
                            ? dangerColor
                            : (connectedPorts == totalPorts && totalPorts > 0)
                                ? successColor
                                : warningColor)
                        .withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasError
                            ? dangerColor
                            : (connectedPorts == totalPorts && totalPorts > 0)
                                ? successColor
                                : warningColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasError
                          ? 'SYSTEM FAULT'
                          : (connectedPorts == totalPorts && totalPorts > 0)
                              ? 'HEALTHY'
                              : 'ATTENTION REQ.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasError
                            ? dangerColor
                            : (connectedPorts == totalPorts && totalPorts > 0)
                                ? successColor
                                : warningColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),
              
              // Settings Trigger for Mobile/Tablet
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
                  onPressed: () => _showSettingsModal(context),
                ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                tooltip: 'Log Out',
                onPressed: () {
                  setState(() {
                    _role = UserRole.none;
                    _activeNavIndex = 0;
                  });
                  gateway.disconnect();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Subviews ---

  Widget _buildDashboardView(GatewayProvider gateway, bool isDesktop, bool isTablet) {
    final selectedPortData = gateway.ports.firstWhere(
      (p) => p.port == gateway.selectedPort,
      orElse: () => SensorPort(port: gateway.selectedPort, name: 'Zone ${gateway.selectedPort}', temp: null, conn: false),
    );

    if (isDesktop) {
      // Desktop Grid Layout
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  Icons.thermostat,
                  'Active Temp',
                  selectedPortData.conn && selectedPortData.temp != null
                      ? '${selectedPortData.temp!.toStringAsFixed(1)}°C'
                      : '--.-',
                  'Zone ${gateway.selectedPort} selected',
                  accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStatCard(
                  Icons.online_prediction,
                  'Sensors Status',
                  '${gateway.connectedCount} / ${gateway.ports.length}',
                  'Hardware ports report online',
                  successColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickStatCard(
                  Icons.dns_outlined,
                  'Gateway Node',
                  'T-SENSE GW',
                  'Uplink operational',
                  warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main split dashboard layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Panel (Sensor Grid + Relay Controller)
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildPortsCard(gateway),
                    const SizedBox(height: 16),
                    _buildRelayCard(gateway),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Right Panel (Trend + Alert Stream)
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildTrendCard(gateway),
                    const SizedBox(height: 16),
                    _buildMiniAlertStream(gateway),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Mobile / Tablet Stacked Layout
      return Column(
        children: [

          _buildPortsCard(gateway),
          const SizedBox(height: 16),
          _buildRelayCard(gateway),
          const SizedBox(height: 16),
          _buildTrendCard(gateway),
          const SizedBox(height: 16),
          _buildMiniAlertStream(gateway),
        ],
      );
    }
  }

  Widget _buildDevicesView(GatewayProvider gateway) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Physical Node Config',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text(
          'T-Sense reads between 1 and 6 high-precision digital DS18B20 temperature probes. Below is the mapping of online channels and their zone renaming rules.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.35,
          ),
          itemCount: gateway.ports.length,
          itemBuilder: (context, idx) => _PortRenameCard(
            key: ValueKey('rename_${gateway.ports[idx].port}'),
            port: gateway.ports[idx],
            gateway: gateway,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsView(GatewayProvider gateway) {
    final alertItems = _generateAlertItems(gateway);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Event Logger',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: dangerColor.withOpacity(0.2)),
              ),
              child: Text(
                '${alertItems.where((a) => a.type == 'error').length} ACTIVE WARNINGS',
                style: const TextStyle(color: dangerColor, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Safe range is ${gateway.alarmMin.toStringAsFixed(1)}°C – ${gateway.alarmMax.toStringAsFixed(1)}°C. Probes outside this band are recorded below in real-time.',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 24),
        if (alertItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline, color: successColor, size: 48),
                  SizedBox(height: 16),
                  Text('No anomalies detected in the system.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: alertItems.length,
            itemBuilder: (context, idx) {
              final a = alertItems[idx];
              final isErr = a.type == 'error';
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: glassBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isErr ? dangerColor : successColor).withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: (isErr ? dangerColor : successColor).withOpacity(0.15)),
                      ),
                      child: Icon(
                        isErr ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isErr ? dangerColor : successColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(a.time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(a.desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSettingsView(GatewayProvider gateway) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'System Configurations',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Manage device uplinks, storage bounds, alarm rules thresholds, and hardware diagnostics.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        const SizedBox(height: 24),
        _buildSettingsForm(gateway),
        const SizedBox(height: 20),
        _buildAlarmRulesCard(gateway),
        const SizedBox(height: 20),
        _buildSDStorageCard(gateway),
        const SizedBox(height: 20),
        _buildCalibrationCard(gateway),
        const SizedBox(height: 20),
        _buildSystemUtilitiesCard(gateway),
      ],
    );
  }

  Widget _buildRelayCard(GatewayProvider gateway) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AUXILIARY CONTROL RELAY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (gateway.relayState ? successColor : warningColor).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  gateway.relayState ? 'CLOSED / ON' : 'OPEN / OFF',
                  style: TextStyle(
                    fontSize: 10,
                    color: gateway.relayState ? successColor : warningColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aux Relay Switch',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gateway.relayState
                          ? 'Relay switch contacts are closed (powering load).'
                          : 'Relay switch contacts are open (load disconnected).',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: gateway.relayState,
                activeColor: successColor,
                onChanged: (val) {
                  gateway.toggleRelay();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmRulesCard(GatewayProvider gateway) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Alarm & Buzzer Rules', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Configure temperature thresholds and trigger audio indicators.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.08),
                  foregroundColor: accentColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  gateway.testBuzzer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sent Test Buzzer command to ESP32!'), behavior: SnackBarBehavior.floating),
                  );
                },
                icon: const Icon(Icons.volume_up, size: 16),
                label: const Text('Test Buzzer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Min Alarm Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${gateway.alarmMin.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 12, color: dangerColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: gateway.alarmMin.clamp(-55.0, gateway.alarmMax - 1.0),
                      min: -55.0,
                      max: 125.0,
                      activeColor: dangerColor,
                      inactiveColor: const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        gateway.saveAlarmRules(gateway.alarmMax, val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Max Alarm Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${gateway.alarmMax.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 12, color: dangerColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: gateway.alarmMax.clamp(gateway.alarmMin + 1.0, 125.0),
                      min: -55.0,
                      max: 125.0,
                      activeColor: dangerColor,
                      inactiveColor: const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        gateway.saveAlarmRules(val, gateway.alarmMin);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Buzzer sounds automatically if any online probe breaches these boundaries (Min: ${gateway.alarmMin}°C, Max: ${gateway.alarmMax}°C).',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSDStorageCard(GatewayProvider gateway) {
    final uptimeHrs = gateway.uptimeSecs ~/ 3600;
    final uptimeMins = (gateway.uptimeSecs % 3600) ~/ 60;
    final uptimeS = gateway.uptimeSecs % 60;
    final capMB = gateway.sdCap;
    final usedMB = gateway.sdUsed;
    final double pct = capMB > 0 ? (usedMB / capMB).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SD Card Telemetry Storage', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('View local SD log files capacity, system uptime status, and log exports.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Uptime', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$uptimeHrs hrs $uptimeMins mins $uptimeS secs', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('SD Card Size', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(capMB > 0 ? '$capMB MB total' : 'No SD Card detected', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (capMB > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SD Storage Fullness', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('$usedMB MB / $capMB MB (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(pct > 0.9 ? dangerColor : accentColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Telemetry CSV log is hosted at http://${gateway.ipAddress}/api/sd/download'),
                        action: SnackBarAction(
                          label: 'Copy IP',
                          textColor: Colors.white,
                          onPressed: () {},
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download CSV Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dangerColor,
                    side: const BorderSide(color: dangerColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Format SD Log Storage?'),
                        content: const Text('Are you sure you want to format and clear all stored data records? This will delete all logged temperatures permanently.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () {
                              gateway.clearSDLog();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('SD Card storage formatted!'), behavior: SnackBarBehavior.floating),
                              );
                            },
                            child: const Text('Format SD Log', style: TextStyle(color: dangerColor)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('Format SD Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationCard(GatewayProvider gateway) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sensor Calibration Offsets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Fine-tune individual port temperature values to calibrate external probe sensors.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gateway.ports.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFFE2E8F0), height: 24),
            itemBuilder: (context, idx) {
              final p = gateway.ports[idx];
              final currentOffset = gateway.offsets.length > idx ? gateway.offsets[idx] : 0.0;
              return _CalibrationRow(
                key: ValueKey('cal_${p.port}'),
                port: p,
                offset: currentOffset,
                gateway: gateway,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemUtilitiesCard(GatewayProvider gateway) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Utilities & Maintenance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Manage device clocks, network credentials routers config, and reboot controls.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RTC Hardware Clock Sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Synchronize device internal RTC time with this machine local clock.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.08),
                  foregroundColor: accentColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  gateway.syncTime();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RTC synchronized with client local time!'), behavior: SnackBarBehavior.floating),
                  );
                },
                icon: const Icon(Icons.sync, size: 16),
                label: const Text('Sync RTC Clock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 32),
          const Text('Update Wi-Fi Station Mode Router Credentials', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Provide SSID and Password to connect the node to local network routers.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          _WifiCredsForm(gateway: gateway),
          const Divider(color: Color(0xFFE2E8F0), height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reboot Gateway Hub', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: dangerColor)),
                    SizedBox(height: 2),
                    Text('Warning: This reboots the micro-controller, causing brief telemetries loss.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: dangerColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reboot Hub Device?'),
                      content: const Text('Are you sure you want to reboot the gateway controller hardware? Direct WiFi polling will disconnect briefly.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            gateway.rebootHub();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Hub reboot command transmitted!'), behavior: SnackBarBehavior.floating),
                            );
                          },
                          child: const Text('Reboot Hub', style: TextStyle(color: dangerColor)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reboot Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Widget Elements ---

  Widget _buildQuickStatCard(IconData icon, String label, String value, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 1.5),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildPortsCard(GatewayProvider gateway) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('SENSOR PORT GRID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              Text(
                '${gateway.connectedCount}/${gateway.ports.length} ONLINE',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemCount: gateway.ports.length,
            itemBuilder: (context, idx) {
              final p = gateway.ports[idx];
              final isSel = p.port == gateway.selectedPort;
              final isHot = gateway.isOutOfRange(p.temp);

              return GestureDetector(
                onTap: () => gateway.setSelectedPort(p.port),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? accentColor.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel
                          ? accentColor
                          : p.conn
                              ? const Color(0xFFE2E8F0)
                              : dangerColor.withOpacity(0.2),
                      width: isSel ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: p.conn ? (isHot ? warningColor : successColor) : dangerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text('#${p.port}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(
                        p.conn && p.temp != null ? '${p.temp!.toStringAsFixed(1)}°C' : '--.-',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: p.conn ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(GatewayProvider gateway) {
    final spots = <FlSpot>[];
    for (int i = 0; i < gateway.history.length; i++) {
      final t = gateway.history[i].portById(gateway.selectedPort)?.temp;
      if (t != null) spots.add(FlSpot(i.toDouble(), t));
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ZONE ${gateway.selectedPort} THERMAL TREND',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 2),
                  const Text('Real-time DS18B20 micro-fluctuations', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Live Stream', style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: spots.length < 2
                ? const Center(child: Text('Collecting enough samples…', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (v, meta) => Text(
                              '${v.toInt()}°',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
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
                                accentColor.withOpacity(0.2),
                                accentColor.withOpacity(0.0),
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

  Widget _buildMiniAlertStream(GatewayProvider gateway) {
    final alertItems = _generateAlertItems(gateway);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ACTIVE SYSTEM EVENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
              TextButton(
                onPressed: () => setState(() => _activeNavIndex = 2),
                child: const Text('View Logs', style: TextStyle(color: accentColor, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (alertItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Normal parameters. No alerts active.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ),
            )
          else
            Column(
              children: alertItems.take(2).map((a) {
                final isErr = a.type == 'error';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isErr ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isErr ? dangerColor : successColor,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text(a.desc, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(a.time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // --- Alert Generation Logic ---
  
  List<AlertLogItem> _generateAlertItems(GatewayProvider gateway) {
    final list = <AlertLogItem>[];
    for (final p in gateway.ports) {
      if (!p.conn) {
        list.add(AlertLogItem(
          title: 'Sensor Offline',
          time: 'Active',
          desc: '${p.name} (Port #${p.port}) connection lost.',
          type: 'error',
        ));
      } else if (gateway.isHot(p.temp)) {
        list.add(AlertLogItem(
          title: 'High Temp Warning',
          time: 'Active',
          desc: '${p.name} temperature reached ${p.temp!.toStringAsFixed(1)}°C (Max: ${gateway.alarmMax.toStringAsFixed(1)}°C)',
          type: 'error',
        ));
      } else if (gateway.isCold(p.temp)) {
        list.add(AlertLogItem(
          title: 'Low Temp Warning',
          time: 'Active',
          desc: '${p.name} temperature dropped to ${p.temp!.toStringAsFixed(1)}°C (Min: ${gateway.alarmMin.toStringAsFixed(1)}°C)',
          type: 'error',
        ));
      }
    }
    // Static standard events for simulation flavor if none
    if (list.isEmpty) {
      list.add(AlertLogItem(
        title: 'Signal Recovered',
        time: '15m ago',
        desc: 'Gateway Node uplink successfully fully established.',
        type: 'success',
      ));
    }
    return list;
  }

  // --- Settings Form ---

  Widget _buildSettingsForm(GatewayProvider gateway) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Connection Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(height: 24),

          _field('Device IP Address', gateway.ipAddress, gateway.setIpAddress),
          const SizedBox(height: 12),
          _field('Basic Auth Username', gateway.wifiUser, (v) => gateway.setWifiCredentials(v, gateway.wifiPass)),
          const SizedBox(height: 12),
          _field('Basic Auth Password', gateway.wifiPass, (v) => gateway.setWifiCredentials(gateway.wifiUser, v), obscure: true),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                gateway.connect();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connected to Gateway Source Protocol'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('SAVE & APPLY CONNECT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Pulse Widget ---

  Widget _buildPulseIndicator(GatewayProvider gateway) {
    if (gateway.state != GatewayState.connected) {
      return Container(width: 8, height: 8, decoration: const BoxDecoration(color: warningColor, shape: BoxShape.circle));
    }
    return const _PulseDot();
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: successColor.withOpacity(0.3 + 0.7 * _anim.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: successColor.withOpacity(0.5 * _anim.value),
                blurRadius: 4 * _anim.value,
                spreadRadius: 1 * _anim.value,
              ),
            ],
          ),
        );
      },
    );
  }
}



// --- Field Helpers ---

Widget _field(String label, String value, ValueChanged<String> onChanged, {bool obscure = false, String? hint}) {
  return _LiveSettingField(label: label, value: value, onChanged: onChanged, obscure: obscure, hint: hint);
}

// A text field that owns a stable controller so live telemetry rebuilds (which
// fire every couple of seconds) don't recreate the controller and wipe what the
// user is typing or jump the cursor to the end.
class _LiveSettingField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final String? hint;
  const _LiveSettingField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.obscure = false,
    this.hint,
  });

  @override
  State<_LiveSettingField> createState() => _LiveSettingFieldState();
}

class _LiveSettingFieldState extends State<_LiveSettingField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _LiveSettingField old) {
    super.didUpdateWidget(old);
    // Pick up external changes only when the user isn't actively editing.
    if (!_focus.hasFocus && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      obscureText: widget.obscure,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: glassBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentColor)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class AlertLogItem {
  final String title;
  final String time;
  final String desc;
  final String type;

  AlertLogItem({required this.title, required this.time, required this.desc, required this.type});
}

// Devices view: one card per port with a stable rename field.
class _PortRenameCard extends StatefulWidget {
  final SensorPort port;
  final GatewayProvider gateway;
  const _PortRenameCard({super.key, required this.port, required this.gateway});

  @override
  State<_PortRenameCard> createState() => _PortRenameCardState();
}

class _PortRenameCardState extends State<_PortRenameCard> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.port.name);
  }

  @override
  void didUpdateWidget(covariant _PortRenameCard old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.port.name != _controller.text) {
      _controller.text = widget.port.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.port;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: p.conn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PORT #${p.port}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8A99AD),
                    ),
                  ),
                ],
              ),
              Text(
                p.conn && p.temp != null ? '${p.temp!.toStringAsFixed(1)}°C' : '--.-',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: p.conn ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            focusNode: _focus,
            decoration: InputDecoration(
              labelText: 'Zone Name',
              labelStyle: const TextStyle(color: Color(0xFF8A99AD), fontSize: 11),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () {
                final newName = _controller.text.trim();
                if (newName.isNotEmpty) {
                  widget.gateway.renamePort(p.port, newName);
                  FocusScope.of(context).unfocus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Zone name updated to "$newName"')),
                  );
                }
              },
              child: const Text('Save Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// Settings view: one calibration row per port with a stable offset field.
class _CalibrationRow extends StatefulWidget {
  final SensorPort port;
  final double offset;
  final GatewayProvider gateway;
  const _CalibrationRow({super.key, required this.port, required this.offset, required this.gateway});

  @override
  State<_CalibrationRow> createState() => _CalibrationRowState();
}

class _CalibrationRowState extends State<_CalibrationRow> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.offset.toStringAsFixed(2));
  }

  @override
  void didUpdateWidget(covariant _CalibrationRow old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.offset != old.offset) {
      _controller.text = widget.offset.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.port;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Port #${p.port} (${p.name})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                p.conn && p.temp != null
                    ? 'Active Raw Temp: ${(p.temp! - widget.offset).toStringAsFixed(1)}°C'
                    : 'Sensor disconnected',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          height: 38,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              suffixText: '°C',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: accentColor),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          onPressed: () {
            final val = double.tryParse(_controller.text);
            if (val != null) {
              widget.gateway.saveOffset(p.port, val);
              FocusScope.of(context).unfocus();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Port #${p.port} calibration offset saved to ${val > 0 ? "+" : ""}${val.toStringAsFixed(2)}°C!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter a valid number for the offset.'), behavior: SnackBarBehavior.floating),
              );
            }
          },
          child: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// Settings view: Wi-Fi station credentials with stable input fields.
class _WifiCredsForm extends StatefulWidget {
  final GatewayProvider gateway;
  const _WifiCredsForm({required this.gateway});

  @override
  State<_WifiCredsForm> createState() => _WifiCredsFormState();
}

class _WifiCredsFormState extends State<_WifiCredsForm> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ssidController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Wi-Fi SSID',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: accentColor)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _passController,
            obscureText: true,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Wi-Fi Password',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: accentColor)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onPressed: () {
            final ssid = _ssidController.text.trim();
            final pass = _passController.text.trim();
            if (ssid.isNotEmpty) {
              widget.gateway.saveWifiConfig(ssid, pass);
              FocusScope.of(context).unfocus();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved network router configuration for SSID: $ssid!'), behavior: SnackBarBehavior.floating),
              );
              _ssidController.clear();
              _passController.clear();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SSID field cannot be empty!'), behavior: SnackBarBehavior.floating),
              );
            }
          },
          child: const Text('Save Wi-Fi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// --- Disconnected / Connection Selection Modal ---

class _DisconnectedView extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onLogout;
  const _DisconnectedView({required this.onConnect, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: glassBorder),
            ),
            child: const Icon(Icons.sensors_off_outlined, color: Color(0xFFCBD5E1), size: 64),
          ),
          const SizedBox(height: 24),
          const Text(
            'Gateway Offline',
            style: TextStyle(color: Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a connection protocol to start monitoring.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: onConnect,
            icon: const Icon(Icons.link_outlined, color: Colors.black),
            label: const Text('Choose Connection Protocol', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
            label: const Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
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
    backgroundColor: sidebarColor,
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Connection Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Color(0xFF94A3B8)), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _field('Device IP Address', gateway.ipAddress, gateway.setIpAddress),
                  const SizedBox(height: 12),
                  _field('Username', gateway.wifiUser, (v) => gateway.setWifiCredentials(v, gateway.wifiPass)),
                  const SizedBox(height: 12),
                  _field('Password', gateway.wifiPass, (v) => gateway.setWifiCredentials(gateway.wifiUser, v), obscure: true),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        gateway.connect();
                        Navigator.pop(context);
                      },
                      child: const Text('CONNECT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ===========================================================================
// Role-Based Views: Login Screen & Customer Dashboard
// ===========================================================================

class _LoginScreen extends StatefulWidget {
  final Function(UserRole) onLogin;
  const _LoginScreen({required this.onLogin});

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _userController = TextEditingController(text: 'boss@rich.com');
  final _passController = TextEditingController();
  String? _error;

  void _submit() {
    final user = _userController.text.trim();
    final pass = _passController.text.trim();

    if ((user == 'admin' || user == 'boss@rich.com') && pass == 'admin') {
      setState(() => _error = null);
      widget.onLogin(UserRole.admin);
    } else if (user == 'customer' && pass == 'customer') {
      setState(() => _error = null);
      widget.onLogin(UserRole.customer);
    } else {
      setState(() => _error = 'Invalid credentials. Try boss@rich.com/admin or customer/customer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        primaryColor: const Color(0xFF2563EB),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          surface: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F6),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // T-Sense logo matching brand image
                  const TSenseLogo(width: 220, height: 70),
                  const SizedBox(height: 36),
                  
                  // Main Header Title
                  const Text(
                    'Hub Admin Access',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF203562),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Subtitle
                  const Text(
                    'Sign in to your T-Sense gateway',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF7E8B9B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Email Address Input
                  TextField(
                    controller: _userController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Color(0xFF475569),
                        size: 20,
                      ),
                      labelText: 'Email address',
                      labelStyle: const TextStyle(
                        color: Color(0xFF7F8C8D),
                        fontSize: 13.5,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.25),
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F6F5),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFF475569),
                        size: 20,
                      ),
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        color: Color(0xFF7F8C8D),
                        fontSize: 13.5,
                      ),
                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.withOpacity(0.25),
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F6F5),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14.5,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Login to System Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _submit,
                      child: const Text(
                        'Login to System',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Register link
                  GestureDetector(
                    onTap: () {},
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        children: [
                          TextSpan(text: "Don't have an account? "),
                          TextSpan(
                            text: "Register",
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Demo helpers
                  Text(
                    'Demo Access:\nAdmin: boss@rich.com / admin\nCustomer: customer / customer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.withOpacity(0.6),
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TSenseLogo extends StatelessWidget {
  final double width;
  final double height;
  const TSenseLogo({super.key, this.width = 220, this.height = 70});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rounded-square icon with teal-to-blue gradient
          Container(
            width: height * 0.78,
            height: height * 0.78,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0ABFBC), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(height * 0.22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0ABFBC).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.thermostat,
              color: Colors.white,
              size: height * 0.42,
            ),
          ),
          SizedBox(width: height * 0.22),
          // Text block
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'T-Sense',
                style: TextStyle(
                  fontSize: height * 0.38,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'GATEWAY NODE',
                style: TextStyle(
                  fontSize: height * 0.14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                  color: const Color(0xFF8A99AD),
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerDashboard extends StatelessWidget {
  final VoidCallback onLogout;
  const _CustomerDashboard({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Consumer<GatewayProvider>(
      builder: (context, gateway, _) {
        final isOffline = gateway.state == GatewayState.disconnected || gateway.ports.isEmpty;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF475569)),
              onPressed: onLogout,
            ),
            title: const Text(
              'Server Room',
              style: TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              // Pill badge for Offline/Online status matching screenshot
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isOffline ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOffline ? 'Offline' : 'Online',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Download Icon next to status indicator
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Color(0xFF475569), size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting logs...')),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Device Info Card (Full Width)
                    _buildDeviceInfoCard(gateway),
                    const SizedBox(height: 24),

                    // 2. Sensors Section Title
                    const Text(
                      'Sensors',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 3. Sensor Cards Row/Grid
                    _buildSensorsGrid(gateway),
                    const SizedBox(height: 24),

                    // 4. Temperature History Card
                    _buildTemperatureHistoryCard(gateway),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceInfoCard(GatewayProvider gateway) {
    final ip = gateway.ipAddress.isEmpty ? '127.0.0.1' : gateway.ipAddress;
    final model = gateway.modelName.isEmpty ? 'T-Sense GW' : gateway.modelName;
    final fw = gateway.fwVersion.isEmpty ? '--' : gateway.fwVersion;
    final deviceId = gateway.deviceId.isEmpty ? 'A1B2C3D4E5F6' : gateway.deviceId;
    final mac = gateway.macAddress.isEmpty ? '--' : gateway.macAddress;

    String lastSeenStr = 'Never';
    if (gateway.lastSeen != null) {
      final diff = DateTime.now().difference(gateway.lastSeen!);
      if (diff.inSeconds < 5) {
        lastSeenStr = 'Just now';
      } else if (diff.inSeconds < 60) {
        lastSeenStr = '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        lastSeenStr = '${diff.inMinutes}m ago';
      } else {
        lastSeenStr = '${diff.inHours}h ago';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Info',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Model', model),
          const SizedBox(height: 10),
          _buildInfoRow('Firmware', fw),
          const SizedBox(height: 10),
          _buildInfoRow('IP Address', ip),
          const SizedBox(height: 10),
          _buildInfoRow('MAC Address', mac),
          const SizedBox(height: 10),
          _buildInfoRow('Last Seen', lastSeenStr),
          const SizedBox(height: 10),
          _buildInfoRow('Device ID', deviceId),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A99AD),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF2D3748),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorsGrid(GatewayProvider gateway) {
    final ports = gateway.ports.isEmpty
        ? [
            SensorPort(port: 1, name: 'Port 1', temp: null, conn: false),
            SensorPort(port: 2, name: 'Port 2', temp: null, conn: false),
          ]
        : gateway.ports;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: ports.map((p) {
        final double? temp = p.temp;
        final bool isConn = p.conn;

        return Container(
          width: 170,
          height: 130,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PORT ${p.port}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A99AD),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isConn && temp != null ? '${temp.toStringAsFixed(1)}°C' : '--',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isConn ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isConn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemperatureHistoryCard(GatewayProvider gateway) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Temperature History',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Last 60 readings',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF8A99AD),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: gateway.history.isEmpty
                ? const Center(
                    child: Text(
                      'No temperature readings available.',
                      style: TextStyle(color: Color(0xFF8A99AD), fontSize: 13),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 5,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}°C',
                                style: const TextStyle(
                                  color: Color(0xFF8A99AD),
                                  fontSize: 10,
                                ),
                              );
                            },
                            reservedSize: 32,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final int idx = value.toInt();
                              if (idx % 10 == 0 && idx < gateway.history.length) {
                                return Text(
                                  '${idx}s',
                                  style: const TextStyle(
                                    color: Color(0xFF8A99AD),
                                    fontSize: 9,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: (gateway.history.length - 1).toDouble(),
                      minY: 15,
                      maxY: 40,
                      lineBarsData: _buildHistoryLineBars(gateway),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> _buildHistoryLineBars(GatewayProvider gateway) {
    final Map<int, List<FlSpot>> portSpots = {};
    for (int i = 0; i < gateway.history.length; i++) {
      final snapshot = gateway.history[i];
      for (final p in snapshot.ports) {
        if (p.conn && p.temp != null) {
          portSpots.putIfAbsent(p.port, () => []).add(FlSpot(i.toDouble(), p.temp!));
        }
      }
    }

    final List<Color> colors = [
      const Color(0xFF1E3E72), // Navy blue (Port 1)
      const Color(0xFF10B981), // Emerald green (Port 2)
      const Color(0xFF3B82F6), // Sky blue (Port 3)
      const Color(0xFFF59E0B), // Amber (Port 4)
      const Color(0xFF8B5CF6), // Purple (Port 5)
      const Color(0xFFEC4899), // Pink (Port 6)
    ];

    return portSpots.entries.map((entry) {
      final portIdx = entry.key - 1;
      final Color lineBarColor = colors[portIdx % colors.length];

      return LineChartBarData(
        spots: entry.value,
        isCurved: true,
        color: lineBarColor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: lineBarColor.withOpacity(0.04),
        ),
      );
    }).toList();
  }
}
