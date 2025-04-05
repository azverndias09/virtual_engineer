import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AnalysisScreen extends StatefulWidget {
  @override
  _AnalysisScreenState createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  // final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child(
  //   "UsersData",
  // );

  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-1.5-pro',
    apiKey: 'AIzaSyDkxfhZ0KdKDXLQvHg4cZp2REpmRKz3xF4',
  );
  List<MotorReading> _readings = [];
  String _analysis = "Analyzing data...";
  bool _isLoading = true;
  final double _vibrationThreshold = 0.7;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMotorData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMotorData() async {
    try {
      const String userId = "j1ExGKeg1mSqdre4gIhRWXPZhaR2";
      final snapshot =
          await _databaseRef
              .child("UsersData/$userId/readings")
              .limitToLast(100)
              .get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> values = snapshot.value as Map;
        _readings =
            values.entries.map((entry) {
              final data = entry.value as Map;
              final rawVibration = double.parse(
                data['vibration']?.toString() ?? '0',
              );

              return MotorReading(
                timestamp: DateTime.fromMillisecondsSinceEpoch(
                  int.parse(data['timestamp'].toString()),
                ),
                voltage: double.parse(data['voltage'].toString()),
                current: double.parse(data['current'].toString()),
                temperature: double.parse(
                  data['temperature']?.toString() ?? '0',
                ),
                vibrationStatus: rawVibration > _vibrationThreshold ? 1 : 0,
                rawVibration: rawVibration,
              );
            }).toList();

        await _generateVibrationAnalysis();
      }
    } catch (e) {
      setState(() => _analysis = "Error loading data: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateVibrationAnalysis() async {
    final excessiveVibrationCount =
        _readings.where((r) => r.vibrationStatus == 1).length;
    final highTempWithVibration =
        _readings
            .where((r) => r.vibrationStatus == 1 && r.temperature > 60)
            .length;
    final vibrationDuringHighLoad =
        _readings.where((r) => r.vibrationStatus == 1 && r.current > 5).length;

    final prompt = """
    Analyze these industrial motor performance readings with vibration alerts (1=excessive, 0=normal):
    
    ## Key Statistics:
    - Total excessive vibration events: $excessiveVibrationCount
    - High temperature (>60°C) with vibration: $highTempWithVibration cases
    - Vibration during high load (>5A): $vibrationDuringHighLoad cases
    - Average efficiency: ${_readings.map((r) => r.efficiency).average.toStringAsFixed(1)}%
    - Peak temperature: ${_readings.map((r) => r.temperature).max}°C
    
    ## Provide detailed analysis:
    **1. Vibration Pattern Analysis**
    Identify patterns in vibration occurrences (continuous, intermittent, random)
    
    **2. Correlation Analysis**
    Examine relationships between vibration and:
    - Temperature fluctuations
    - Current/load variations
    - Efficiency changes
    
    **3. Maintenance Recommendations**
    - Urgent actions needed (if vibration >30% of readings)
    - Suggested maintenance schedule
    - Parts likely needing inspection
    
    **4. Efficiency Impact**
    Quantify how vibration affects motor efficiency
    
    **5. Predictive Maintenance**
    - Estimate remaining useful life
    - Suggest monitoring frequency
    - Recommended sensor upgrades
    """;

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      if (mounted) {
        setState(() {
          _analysis = response.text ?? "No analysis generated";
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analysis = "Analysis failed: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double excessiveVibrationPercentage =
        _readings.isEmpty
            ? 0
            : (_readings.where((r) => r.vibrationStatus == 1).length /
                _readings.length *
                100);

    return Scaffold(
      appBar: AppBar(
        title: Text("Motor Health Analysis"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [theme.primaryColor, theme.primaryColorDark],
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? _buildLoadingState()
              : RefreshIndicator(
                onRefresh: _loadMotorData,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: _buildSummaryCard(excessiveVibrationPercentage),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildAnalysisCard(),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Analyzing Motor Performance...",
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double excessivePercent) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: Colors.blue[700]),
                SizedBox(width: 8),
                Text(
                  "Performance Summary",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildStatItem(
              "Total Readings",
              _readings.length.toString(),
              Icons.format_list_numbered,
              Colors.grey[700]!,
            ),
            _buildStatItem(
              "Excessive Vibration",
              "${excessivePercent.toStringAsFixed(1)}%",
              Icons.vibration,
              excessivePercent > 30 ? Colors.red[600]! : Colors.orange[600]!,
            ),
            _buildStatItem(
              "Average Efficiency",
              "${_readings.map((r) => r.efficiency).average.toStringAsFixed(1)}%",
              Icons.bolt,
              Colors.green[600]!,
            ),
            _buildStatItem(
              "Peak Temperature",
              "${_readings.map((r) => r.temperature).max}°C",
              Icons.thermostat,
              Colors.deepOrange[600]!,
            ),
            _buildStatItem(
              "High Load Events",
              "${_readings.where((r) => r.current > 5).length}",
              Icons.power,
              Colors.blue[600]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 16))),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple[700]),
                SizedBox(width: 8),
                Text(
                  "AI Analysis",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ..._parseAnalysisText(_analysis),
          ],
        ),
      ),
    );
  }

  List<Widget> _parseAnalysisText(String text) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    for (String line in lines) {
      if (line.trim().isEmpty) continue;

      if (line.startsWith('## ')) {
        // Section header
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.replaceAll('## ', ''),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
          ),
        );
      } else if (line.contains('**')) {
        // Bold text or numbered items
        if (RegExp(r'\*\*\d+\.').hasMatch(line)) {
          // Numbered list item
          final match = RegExp(r'\*\*(\d+)\.').firstMatch(line);
          if (match != null) {
            final number = match.group(1);
            final content = line.replaceAll(match.group(0)!, '').trim();
            widgets.add(
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$number. ",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        content,
                        style: TextStyle(fontSize: 16, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          // Bold text
          widgets.add(_parseBoldText(line));
        }
      } else {
        // Regular text
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(line, style: TextStyle(fontSize: 16, height: 1.4)),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _parseBoldText(String text) {
    final parts = text.split('**');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
          children:
              parts.asMap().entries.map((entry) {
                return TextSpan(
                  text: entry.value,
                  style:
                      entry.key % 2 == 1
                          ? TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          )
                          : null,
                );
              }).toList(),
        ),
      ),
    );
  }
}

class MotorReading {
  final DateTime timestamp;
  final double voltage;
  final double current;
  final double temperature;
  final int vibrationStatus;
  final double rawVibration;

  MotorReading({
    required this.timestamp,
    required this.voltage,
    required this.current,
    required this.temperature,
    required this.vibrationStatus,
    required this.rawVibration,
  });

  double get efficiency {
    const double torque = 350;
    const double n = 3000;
    final double pIn = voltage * current;
    final double pOut = torque * (2 * pi * n / 60);

    double efficiency = pIn != 0 ? (pOut / pIn) * 100 : 0;
    return efficiency.clamp(0, 100);
  }
}

extension CollectionExtensions on Iterable<double> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
  double get max => isEmpty ? 0 : reduce((a, b) => a > b ? a : b);
}
