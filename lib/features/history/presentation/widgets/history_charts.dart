import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({
    required this.title,
    required this.color,
    required this.data,
    super.key,
  });

  final String title;
  final Color color;
  final List<(String, double)> data;

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((d) => d.$2).fold<double>(0, (a, b) => a > b ? a : b);
    final yMax = maxY < 1 ? 1.0 : (maxY * 1.2).ceilToDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: yMax,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: data.length <= 14,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= data.length) return const SizedBox();
                          final key = data[i].$1;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              key.substring(5), // MM-DD
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < data.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: data[i].$2,
                            color: color,
                            width: data.length > 14 ? 4 : 14,
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
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
}
