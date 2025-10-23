import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'models/history_model.dart';
import 'drawer.dart'; // ✅ ใช้ Drawer เดียวกับ Dashboard

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    String okText = 'Delete',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(okText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _clearAll(BuildContext context) async {
    final box = Hive.box<HistoryModel>('history');
    final messenger = ScaffoldMessenger.of(context);

    if (box.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No history to clear')),
      );
      return;
    }

    final ok = await _confirm(
      context,
      title: 'Clear All History',
      message: 'This will delete all history records. Continue?',
      okText: 'Clear All',
    );

    if (ok) {
      await box.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('All history cleared')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<HistoryModel>('history');
    final dfDate = DateFormat('MMM d, yyyy - HH:mm');
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const MainDrawer(), // ✅ ใช้ Drawer เดียวกับทุกหน้า
      appBar: AppBar(
        title: const Text("History"),
        actions: [
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.delete_forever_rounded),
            onPressed: () => _clearAll(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Heart Rate Trend",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),

            // ✅ กราฟจริง (BPM + Temp)
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isDark
                    ? []
                    : const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<HistoryModel> b, _) {
                  final items = b.values.toList();
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        "No data yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  final bpmSpots = <FlSpot>[];
                  final tempSpots = <FlSpot>[];

                  for (int i = 0; i < items.length; i++) {
                    bpmSpots.add(FlSpot(i.toDouble(), items[i].bpm.toDouble()));
                    tempSpots.add(FlSpot(i.toDouble(), items[i].temperature));
                  }

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey[300], strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            interval: 10,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: bpmSpots,
                          isCurved: true,
                          color: Colors.redAccent,
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.redAccent.withOpacity(0.15),
                          ),
                          dotData: FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: tempSpots,
                          isCurved: true,
                          color: const Color(0xFF10B981),
                          barWidth: 3,
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF10B981).withOpacity(0.15),
                          ),
                          dotData: FlDotData(show: false),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              "Recent Measurements",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<HistoryModel> b, _) {
                  final items = b.values.toList()
                    ..sort((a, b) => b.date.compareTo(a.date));

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        "No history yet",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final h = items[i];
                      final dateText = dfDate.format(h.date);

                      return Dismissible(
                        key: ValueKey(h.key),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                        confirmDismiss: (_) => _confirm(
                          context,
                          title: 'Delete Entry',
                          message:
                              'Delete record:\n$dateText • ${h.bpm} BPM • ${h.temperature.toStringAsFixed(1)} °C ?',
                        ),
                        onDismissed: (_) async {
                          await h.delete();
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Entry deleted')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isDark
                                ? []
                                : const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateText,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${h.bpm} BPM",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.thermostat,
                                    color: Colors.teal,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${h.temperature.toStringAsFixed(1)} °C",
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1E3A8A),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
