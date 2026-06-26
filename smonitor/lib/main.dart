import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // UBAH IP INI: Ganti dengan IP Address lokal PC Anda (cek dengan 'ipconfig' di CMD)
  final String ipAddress = '192.xx.xx'; // Contoh: 192.168.1.100
  final String port = '8000';
  WebSocketChannel? channel;

  Map<String, dynamic> systemData = {
    "ping": "0",
    "cpu_usage": "0",
    "cpu_temp": "0",
    "cpu_power": "0",
    "ram_usage": "0",
    "gpu_usage": "0",
    "gpu_temp": "0",
    "disk_c": "0",
    "ohm_status": true,
  };

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      channel = WebSocketChannel.connect(Uri.parse('ws://$ipAddress:$port/ws'));
      channel!.stream.listen(
        (message) {
          if (mounted) {
            setState(() {
              systemData = jsonDecode(message);
            });
          }
        },
        onError: (error) {
          print('WebSocket Error: $error');
        },
        onDone: () {
          // Auto reconnect setelah 3 detik jika terputus
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectWebSocket();
          });
        },
      );
    } catch (e) {
      print('Connection failed: $e');
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  void launchApp(String appId) async {
    try {
      await http.post(Uri.parse('http://$ipAddress:$port/api/launch/$appId'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching $appId...'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal terhubung ke PC: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'System Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (systemData['ohm_status'] == false)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                color: Colors.red.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Open Hardware Monitor belum berjalan di PC!',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _connectWebSocket();
                },
                child: GridView.count(
                  padding: const EdgeInsets.all(20),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _buildMetricCard(
                      'Ping',
                      '${systemData["ping"]}',
                      'ms',
                      Icons.wifi,
                      Colors.blue.shade600,
                    ),
                    _buildMetricCard(
                      'Storage C:',
                      '${systemData["disk_c"]}',
                      'GB',
                      Icons.save,
                      Colors.blue.shade600,
                    ),
                    _buildMetricCard(
                      'CPU Usage',
                      '${systemData["cpu_usage"]}',
                      '%',
                      Icons.memory,
                      Colors.blue.shade600,
                    ),
                    _buildMetricCard(
                      'RAM Usage',
                      '${systemData["ram_usage"]}',
                      '%',
                      Icons.sd_storage,
                      Colors.blue.shade600,
                    ),
                    _buildMetricCard(
                      'CPU Temp',
                      '${systemData["cpu_temp"]}',
                      '°C',
                      Icons.thermostat,
                      Colors.orange.shade600,
                    ),
                    _buildMetricCard(
                      'CPU Power',
                      '${systemData["cpu_power"]}',
                      'W',
                      Icons.bolt,
                      Colors.orange.shade600,
                    ),
                    _buildMetricCard(
                      'GPU Usage',
                      '${systemData["gpu_usage"]}',
                      '%',
                      Icons.developer_board,
                      Colors.blue.shade600,
                    ),
                    _buildMetricCard(
                      'GPU Temp',
                      '${systemData["gpu_temp"]}',
                      '°C',
                      Icons.thermostat,
                      Colors.orange.shade600,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchApp('steam'),
                      icon: const Icon(Icons.games),
                      label: const Text(
                        'STEAM',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1b2838),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchApp('discord'),
                      icon: const Icon(Icons.chat_bubble),
                      label: const Text(
                        'DISCORD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5865F2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
