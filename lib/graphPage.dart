import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class DataGraphPage extends StatefulWidget {
  @override
  _DataGraphPageState createState() => _DataGraphPageState();
}

class _DataGraphPageState extends State<DataGraphPage> {
  // final DatabaseReference _databaseRef =
  //     FirebaseDatabase.instanceFor(
  //       app: Firebase.app(),
  //       databaseURL:
  //           "https://esptrial1-e2df8-default-rtdb.asia-southeast1.firebasedatabase.app/",
  //     ).ref();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<FlSpot> currentData = [];
  List<FlSpot> voltageData = [];
  List<FlSpot> efficiencyData = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchHistoricalData();
  }

  Future<void> fetchHistoricalData() async {
    try {
      const String userId = "j1ExGKeg1mSqdre4gIhRWXPZhaR2";
      DatabaseReference readingsRef = _databaseRef.child(
        "UsersData/$userId/readings",
      );

      DataSnapshot snapshot = await readingsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'No data available';
        });
        return;
      }

      Map<String, dynamic> data = Map<String, dynamic>.from(
        snapshot.value as Map,
      );

      List<FlSpot> tempCurrentData = [];
      List<FlSpot> tempVoltageData = [];
      List<FlSpot> tempEfficiencyData = [];

      // Convert to list and sort by timestamp
      var entries = data.entries.toList();
      entries.sort((a, b) {
        DateTime? timeA = _parseTimestamp(a.value['timestamp']);
        DateTime? timeB = _parseTimestamp(b.value['timestamp']);
        return (timeA ?? DateTime.now()).compareTo(timeB ?? DateTime.now());
      });

      int index = 0;
      for (var entry in entries) {
        try {
          double current =
              double.tryParse(entry.value["current"].toString()) ?? 0;
          double voltage =
              double.tryParse(entry.value["voltage"].toString()) ?? 0;

          double pIn = current * voltage;
          const double torque = 350;
          const double n = 3000;
          double pOut = torque * (2 * 3.14 * n / 6000);
          double efficiency = pIn != 0 ? (pOut / pIn) * 100 : 0;

          tempCurrentData.add(FlSpot(index.toDouble(), current));
          tempVoltageData.add(FlSpot(index.toDouble(), voltage));
          tempEfficiencyData.add(FlSpot(index.toDouble(), efficiency));

          index++;
        } catch (e) {
          print("Error processing data point: $e");
        }
      }

      setState(() {
        currentData = tempCurrentData;
        voltageData = tempVoltageData;
        efficiencyData = tempEfficiencyData;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  DateTime? _parseTimestamp(dynamic timestamp) {
    try {
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      } else if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      print("Error parsing timestamp: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Motor Performance Trends"),
        centerTitle: true,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : _buildGraphContent(),
    );
  }

  Widget _buildGraphContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildGraphCard(
              title: "Current (A)",
              data: currentData,
              color: Colors.blue,
              unit: 'A',
            ),
            const SizedBox(height: 16),
            _buildGraphCard(
              title: "Voltage (V)",
              data: voltageData,
              color: Colors.red,
              unit: 'V',
            ),
            const SizedBox(height: 16),
            // _buildGraphCard(
            //   title: "Efficiency (%)",
            //   data: efficiencyData,
            //   color: Colors.green,
            //   unit: '%',
            //   fixedMaxY: 100,
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphCard({
    required String title,
    required List<FlSpot> data,
    required Color color,
    required String unit,
    double? fixedMaxY,
  }) {
    final maxY = fixedMaxY ?? _calculateMaxY(data);
    final minY = fixedMaxY != null ? 0 : _calculateMinY(data);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child:
                  data.isEmpty
                      ? const Center(child: Text("No data available"))
                      : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: data.isEmpty ? 1 : data.last.x,
                          minY: minY.toDouble(),
                          maxY: maxY,
                          lineTouchData: LineTouchData(
                            enabled: true,
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  return LineTooltipItem(
                                    'Reading ${spot.x.toInt() + 1}\n${spot.y.toStringAsFixed(2)}$unit',
                                    TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (value, _) => Text(
                                      '${value.toInt() + 1}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                reservedSize: 30,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget:
                                    (value, _) => Text(
                                      '${value.toInt()}$unit',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                reservedSize: 40,
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: [
                            LineChartBarData(
                              spots: data,
                              isCurved: true,
                              color: color,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY(List<FlSpot> data) {
    if (data.isEmpty) return 100;
    return data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1;
  }

  double _calculateMinY(List<FlSpot> data) {
    if (data.isEmpty) return 0;
    return data.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 0.9;
  }
}
