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

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
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

  Future<void> _loadSummaries() async {
    final box = Hive.box<HistoryModel>('history');
    final allData = box.values.toList();

    if (allData.isEmpty) {
      setState(() => _loading = false);
      return;
    }

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

  String _generateHealthInsight(List<DailySummary> data) {
    if (data.isEmpty) return "No health data available yet.";

    final last = data.last;
    final avgBpm = _average(data.map((e) => e.avgBpm));
    final avgTemp = _average(data.map((e) => e.avgTemp));

    if (last.avgTemp > avgTemp + 0.5 && last.avgBpm > avgBpm + 10) {
      return "💬 Heart rate & temperature are higher than usual — possible fatigue or mild fever.";
    } else if (last.avgBpm > avgBpm + 15) {
      return "💬 Elevated heart rate — may indicate stress or lack of rest.";
    } else if (last.avgBpm < avgBpm - 15 && last.avgTemp < avgTemp - 0.5) {
      return "💬 Both metrics are low — rest and hydrate properly.";
    } else {
      return "💬 Everything looks stable and healthy 👍";
    }
  }

  String _evaluateHealth(double bpm, double temp) {
    if (bpm < 60 && temp < 37) return "Excellent 🟢";
    if (bpm < 80 && temp < 37.5) return "Normal 🟡";
    return "Needs Attention 🔴";
  }

  Color _statusColor(String status) {
    if (status.contains("Excellent")) return Colors.greenAccent;
    if (status.contains("Normal")) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _getWeekLabel(DateTime date) {
    final weekNumber = ((date.day - 1) / 7).floor() + 1;
    return "Week $weekNumber (${DateFormat('MMM yyyy').format(date)})";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(
        title: const Text("Health Summary"),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0.5,
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.brightness == Brightness.dark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [const Color(0xFFE0F2FE), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _overallCard(theme),
                  const SizedBox(height: 12),
                  _insightCard(theme),
                  const SizedBox(height: 24),
                  _sectionHeader("📅 Daily Summary", theme),
                  const SizedBox(height: 8),
                  ..._daily.map(
                    (d) => _summaryCard(
                      title: DateFormat(
                        'dd MMM yyyy',
                      ).format(DateTime.parse(d.date)),
                      bpm: d.avgBpm,
                      temp: d.avgTemp,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionHeader("📆 Weekly Summary", theme),
                  const SizedBox(height: 8),
                  ..._weekly.map(
                    (w) => _summaryCard(
                      title: w.week,
                      bpm: w.avgBpm,
                      temp: w.avgTemp,
                      status: w.healthStatus,
                      theme: theme,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _overallCard(ThemeData theme) {
    if (_daily.isEmpty) return const SizedBox();
    final avgBpm = _average(_daily.map((e) => e.avgBpm));
    final avgTemp = _average(_daily.map((e) => e.avgTemp));
    final status = _evaluateHealth(avgBpm, avgTemp);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overall Health 💚",
            style: TextStyle(color: Colors.white, fontSize: 20),
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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: colorScheme.surface,
      elevation: theme.brightness == Brightness.dark ? 0 : 4,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.insights,
              color: colorScheme.primary.withValues(alpha: 0.9),
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _insight,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text, ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    ),
  );

  Widget _summaryCard({
    required String title,
    required double bpm,
    required double temp,
    String? status,
    required ThemeData theme,
  }) {
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: theme.brightness == Brightness.dark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
          child: Icon(
            Icons.favorite,
            color: colorScheme.primary.withValues(alpha: 0.9),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "💓 ${bpm.toStringAsFixed(1)} bpm",
                style: TextStyle(color: colorScheme.onSurface),
              ),
              Text(
                "🌡️ ${temp.toStringAsFixed(1)} °C",
                style: TextStyle(color: colorScheme.onSurface),
              ),
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

// ---------- Data Models ----------
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
