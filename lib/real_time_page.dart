import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:motor_app/analysisPage.dart';
import 'package:motor_app/graphPage.dart';

class RealTimeDataPage extends StatefulWidget {
  @override
  _RealTimeDataPageState createState() => _RealTimeDataPageState();
}

class _RealTimeDataPageState extends State<RealTimeDataPage> {
  // Firebase Configuration
  // final DatabaseReference _databaseRef =
  //     FirebaseDatabase.instanceFor(
  //       app: Firebase.app(),
  //       databaseURL:
  //           "https://esptrial1-e2df8-default-rtdb.asia-southeast1.firebasedatabase.app/",
  //     ).ref();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // Notification Setup
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  int _notificationId = 0;

  // Motor Data State
  String current = "N/A";
  String voltage = "N/A";
  String timestamp = "N/A";
  String efficiency = "N/A";
  int vibrationStatus = 0; // 0 = normal, 1 = excessive
  String temperature = "N/A";

  // Constants
  static const double n = 3000;
  static const double PI = 3.14;
  static const double torque = 350;
  static const double vibrationThreshold = 0.7;

  // Warning State
  bool _showWarning = false;
  String _warningMessage = "";
  Set<String> _activeWarnings = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupFirebaseListener();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showSystemNotification(String title, String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'motor_warnings_channel',
          'Motor Warnings',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'motor_warning',
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await notificationsPlugin.show(
      _notificationId++,
      title,
      message,
      platformDetails,
    );
  }

  void _setupFirebaseListener() {
    const String userId = "j1ExGKeg1mSqdre4gIhRWXPZhaR2";
    DatabaseReference readingsRef = _databaseRef.child(
      "UsersData/$userId/readings",
    );

    // Listen to the last child only
    readingsRef
        .limitToLast(1)
        .onChildAdded
        .listen(
          (DatabaseEvent event) {
            if (!event.snapshot.exists) {
              _handleNoData();
              return;
            }

            try {
              final data = Map<String, dynamic>.from(
                event.snapshot.value as Map,
              );
              _processNewData(data);
            } catch (e) {
              print("❌ Data processing error: $e");
              _handleNoData();
            }
          },
          onError: (error) {
            print("❌ Firebase error: $error");
          },
        );
  }

  void _processNewData(Map<String, dynamic> data) {
    print("📡 New Data: $data");

    // Parse input values
    final currentVal = double.tryParse(data["current"].toString()) ?? 0;
    final voltageVal = double.tryParse(data["voltage"].toString()) ?? 0;
    final rawVibration =
        double.tryParse(data["vibration"]?.toString() ?? '0') ?? 0;

    // Calculate vibration status
    vibrationStatus = rawVibration > vibrationThreshold ? 1 : 0;

    // Constants for efficiency calculation
    const double torque = 350; // Nm
    const double n = 3000; // RPM

    // Power calculations
    final double pIn = voltageVal * currentVal; // Input power in Watts
    final double pOut = torque * (2 * pi * n / 60); // Output power in Watts

    // Efficiency calculation with safety checks
    double efficiencyVal = pIn != 0 ? (pOut / pIn) * 100 : 0;
    efficiencyVal = efficiencyVal.clamp(0, 100); // Ensure within 0-100% range

    // Process the data
    _checkForWarnings(currentVal, voltageVal);
    _updateUI(currentVal, voltageVal, efficiencyVal, data);
  }

  void _checkForWarnings(double currentVal, double voltageVal) {
    final newWarnings = <String>[];

    if (currentVal > 3) {
      newWarnings.add("High current ($currentVal A)");
    }
    if (voltageVal < 0 || voltageVal > 4) {
      newWarnings.add("Voltage out of range ($voltageVal V)");
    }
    if (vibrationStatus == 1) {
      newWarnings.add("Excessive vibration");
    }

    _handleWarnings(newWarnings);
  }

  void _handleWarnings(List<String> newWarnings) {
    final newWarningSet = newWarnings.toSet();
    final justTriggered = newWarningSet.difference(_activeWarnings);

    if (justTriggered.isNotEmpty) {
      final warningMessage = "Warning: ${justTriggered.join(', ')}";
      _showSystemNotification("Motor Alert", warningMessage);
      _showWarningDialog(context, warningMessage);
    }

    setState(() {
      _activeWarnings = newWarningSet;
      _showWarning = newWarningSet.isNotEmpty;
      _warningMessage = _activeWarnings.join(', ');
    });
  }

  void _showWarningDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("⚠️ MOTOR WARNING"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("ACKNOWLEDGE"),
              ),
            ],
          ),
    );
  }

  void _updateUI(
    double currentVal,
    double voltageVal,
    double efficiencyVal,
    Map<String, dynamic> data,
  ) {
    setState(() {
      current = currentVal.toStringAsFixed(2);
      voltage = voltageVal.toStringAsFixed(2);
      efficiency = efficiencyVal.toStringAsFixed(2);
      timestamp = data["timestamp"].toString();
      temperature = data["temperature"]?.toString() ?? "N/A";
    });
  }

  void _handleNoData() {
    setState(() {
      current = voltage = timestamp = temperature = efficiency = "No data";
      vibrationStatus = 0;
      _showWarning = false;
      _activeWarnings.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Motor Monitoring"), centerTitle: true),
      body: Column(
        children: [
          if (_showWarning) _buildWarningBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDataCard(
                    "Current",
                    "$current A",
                    _activeWarnings.contains("High current"),
                  ),
                  _buildDataCard(
                    "Voltage",
                    "$voltage V",
                    _activeWarnings.contains("Voltage out of range"),
                  ),
                  _buildDataCard(
                    "Vibration",
                    vibrationStatus == 1 ? "EXCESSIVE" : "Normal",
                    vibrationStatus == 1,
                  ),
                  _buildDataCard("Temperature", "$temperature °C", false),
                  _buildDataCard("Efficiency", "$efficiency%", false),
                  _buildDataCard("Last Update", timestamp, false),
                ],
              ),
            ),
          ),
          // Add the button row at the bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, // background color
                        foregroundColor: Colors.white, // text color
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DataGraphPage(),
                          ),
                        );
                      },
                      child: const Text('View Graph'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // background color
                        foregroundColor: Colors.white, // text color
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnalysisScreen(),
                          ),
                        );
                      },
                      child: const Text('AI Analysis'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _warningMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(String title, String value, bool isWarning) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      color: isWarning ? Colors.red[100] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isWarning ? Colors.red : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
