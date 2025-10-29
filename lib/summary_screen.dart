import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'models/history_model.dart';
import 'drawer.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  List<DailySummary> _daily = [];
  List<WeeklySummary> _weekly = [];
  String _insight = "";
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  // ---------- Safe converters ----------
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble(); // int/double → double
    try {
      return double.parse(v.toString());
    } catch (_) {
      return 0.0;
    }
  }

  double _average(Iterable values) {
    final list = values.map(_toDouble).toList();
    if (list.isEmpty) return 0.0;
    return list.reduce((a, b) => a + b) / list.length;
  }

  // ---------- Load & aggregate ----------
  Future<void> _loadSummaries() async {
    final box = Hive.box<HistoryModel>('history');
    final allData = box.values.toList();

    if (allData.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    // Group by day
    final Map<String, List<HistoryModel>> byDay = {};
    for (final d in allData) {
      final key = DateFormat('yyyy-MM-dd').format(d.date);
      byDay.putIfAbsent(key, () => []).add(d);
    }

    final daily = byDay.entries.map((e) {
      final avgBpm = _average(e.value.map((x) => x.bpm));
      final avgTemp = _average(e.value.map((x) => x.temperature));
      return DailySummary(date: e.key, avgBpm: avgBpm, avgTemp: avgTemp);
    }).toList();

    // Group by week
    final Map<String, List<DailySummary>> byWeek = {};
    for (final d in daily) {
      final weekLabel = _getWeekLabel(DateTime.parse(d.date));
      byWeek.putIfAbsent(weekLabel, () => []).add(d);
    }

    final weekly = byWeek.entries.map((e) {
      final avgBpm = _average(e.value.map((x) => x.avgBpm));
      final avgTemp = _average(e.value.map((x) => x.avgTemp));
      final health = _evaluateHealth(avgBpm, avgTemp);
      return WeeklySummary(
        week: e.key,
        avgBpm: avgBpm,
        avgTemp: avgTemp,
        healthStatus: health,
      );
    }).toList();

    setState(() {
      _daily = daily;
      _weekly = weekly;
      _insight = _generateHealthInsight(daily);
      _loading = false;
    });
  }

  // ---------- Insight & status ----------
  String _generateHealthInsight(List<DailySummary> data) {
    if (data.isEmpty) return "No health data available yet.";

    final last = data.last;

    // ✅ คำนวณค่าเฉลี่ย (ปลอด error และ type ปลอดภัย)
    final avgBpm = _average(data.map<double>((e) => e.avgBpm));
    final avgTemp = _average(data.map<double>((e) => e.avgTemp));

    // ✅ วิเคราะห์เทียบกับค่าเฉลี่ยที่แท้จริง
    if (last.avgTemp > avgTemp + 0.5 && last.avgBpm > avgBpm + 10) {
      return "💬 Your heart rate and temperature are higher than normal — you may be fatigued or have a mild fever. Get rest and stay hydrated.";
    } else if (last.avgBpm > avgBpm + 15 && last.avgTemp <= avgTemp + 0.2) {
      return "💬 Your heart rate is elevated but your temperature is normal — could be due to stress or lack of sleep.";
    } else if (last.avgBpm < avgBpm - 15 && last.avgTemp < avgTemp - 0.5) {
      return "💬 Both your heart rate and temperature are lower than usual — if you feel dizzy, consult a doctor.";
    } else {
      return "💬 Everything looks healthy 👍 Keep maintaining good habits!";
    }
  }

  String _evaluateHealth(double bpm, double temp) {
    if (bpm < 60 && temp < 37) return "Excellent 🟢";
    if (bpm < 80 && temp < 37.5) return "Normal 🟡";
    return "Needs Attention 🔴";
  }

  Color _statusColor(String status) {
    if (status.contains("Excellent")) return Colors.green;
    if (status.contains("Normal")) return Colors.orange;
    return Colors.redAccent;
  }

  String _getWeekLabel(DateTime date) {
    final weekNumber = ((date.day - 1) / 7).floor() + 1;
    return "Week $weekNumber (${DateFormat('MMM yyyy').format(date)})";
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(
        title: const Text("Health Summary"),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.primary,
        elevation: 0.5,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _overallCard(),
                  const SizedBox(height: 12),
                  _insightCard(),
                  const SizedBox(height: 20),
                  _sectionHeader("📅 Daily Summary"),
                  ..._daily.map(
                    (d) => _summaryCard(
                      title: DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.parse(d.date)),
                      bpm: d.avgBpm,
                      temp: d.avgTemp,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader("📆 Weekly Summary"),
                  ..._weekly.map(
                    (w) => _summaryCard(
                      title: w.week,
                      bpm: w.avgBpm,
                      temp: w.avgTemp,
                      status: w.healthStatus,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _overallCard() {
    if (_daily.isEmpty) return const SizedBox();
    final avgBpm = _average(_daily.map((e) => e.avgBpm));
    final avgTemp = _average(_daily.map((e) => e.avgTemp));
    final status = _evaluateHealth(avgBpm, avgTemp);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.teal[600],
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Overall Health Summary 💚",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "💓 Avg BPM: ${avgBpm.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              "🌡️ Avg Temp: ${avgTemp.toStringAsFixed(1)} °C",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "💬 Status: $status",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _insightCard() => Card(
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights, color: Colors.teal, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _insight,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3A8A),
      ),
    ),
  );

  Widget _summaryCard({
    required String title,
    required double bpm,
    required double temp,
    String? status,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.favorite, color: Colors.redAccent),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("💓 ${bpm.toStringAsFixed(1)} bpm"),
              Text("🌡️ ${temp.toStringAsFixed(1)} °C"),
              if (status != null)
                Text(
                  "💬 $status",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Helper data classes ----------
class DailySummary {
  final String date;
  final double avgBpm;
  final double avgTemp;
  DailySummary({
    required this.date,
    required this.avgBpm,
    required this.avgTemp,
  });
}

class WeeklySummary {
  final String week;
  final double avgBpm;
  final double avgTemp;
  final String healthStatus;
  WeeklySummary({
    required this.week,
    required this.avgBpm,
    required this.avgTemp,
    required this.healthStatus,
  });
}
