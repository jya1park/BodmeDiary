import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({
    required this.title,
    required this.color,
    required this.data,
    this.valueFormatter,
    super.key,
  });

  final String title;
  final Color color;
  final List<(String, double)> data;

  /// 막대 위에 표시될 숫자 포맷. null 이면 정수로 표시.
  final String Function(double value)? valueFormatter;

  String _formatValue(double v) {
    if (valueFormatter != null) return valueFormatter!(v);
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((d) => d.$2).fold<double>(0, (a, b) => a > b ? a : b);
    // 라벨 공간 확보를 위해 약간 더 여유 있게
    final yMax = maxY < 1 ? 1.0 : (maxY * 1.3).ceilToDouble();
    final manyBars = data.length > 14;
    final labelFontSize = manyBars ? 8.0 : 10.0;

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
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: yMax,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  // 항상 막대 위에 값 표시 (tooltip 을 라벨 처럼 사용)
                  barTouchData: BarTouchData(
                    enabled: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 2,
                      getTooltipItem: (group, _, rod, __) {
                        if (rod.toY <= 0) {
                          return null; // 0 인 막대는 라벨 생략
                        }
                        return BarTooltipItem(
                          _formatValue(rod.toY),
                          TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: labelFontSize,
                          ),
                        );
                      },
                    ),
                  ),
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
                          if (i < 0 || i >= data.length) {
                            return const SizedBox();
                          }
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
                        showingTooltipIndicators: data[i].$2 > 0 ? [0] : [],
                        barRods: [
                          BarChartRodData(
                            toY: data[i].$2,
                            color: color,
                            width: manyBars ? 4 : 14,
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
