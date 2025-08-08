import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/mood_provider.dart';

class WeeklyMoodChart extends StatelessWidget {
  const WeeklyMoodChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MoodProvider>(
      builder: (context, moodProvider, child) {
        final recentMoods = moodProvider.getRecentMoods(7); // Last week
        
        if (recentMoods.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.timeline, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  'Your weekly mood history will appear here',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your mood daily to see weekly patterns!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        // Group moods by day and calculate average score
        final Map<DateTime, List<double>> moodsByDay = {};
        
        // Fill in all 7 days with empty data
        for (int i = 6; i >= 0; i--) {
          final day = DateTime.now().subtract(Duration(days: i));
          final dayKey = DateTime(day.year, day.month, day.day);
          moodsByDay[dayKey] = [];
        }
        
        // Add actual mood data
        for (final mood in recentMoods) {
          final day = DateTime(mood.date.year, mood.date.month, mood.date.day);
          final score = moodProvider.getMoodScore(mood.mood);
          
          if (moodsByDay.containsKey(day)) {
            moodsByDay[day]!.add(score);
          }
        }

        // Calculate daily averages
        final List<FlSpot> spots = [];
        final sortedDays = moodsByDay.keys.toList()..sort();
        
        for (int i = 0; i < sortedDays.length; i++) {
          final day = sortedDays[i];
          final scores = moodsByDay[day]!;
          if (scores.isNotEmpty) {
            final average = scores.reduce((a, b) => a + b) / scores.length;
            spots.add(FlSpot(i.toDouble(), average));
          }
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sanity State Trends',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: spots.isEmpty ? _buildEmptyChart(context, sortedDays) : LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 1:
                                return const Icon(Icons.sentiment_very_dissatisfied, size: 16, color: Colors.red);
                              case 2:
                                return const Icon(Icons.sentiment_dissatisfied, size: 16, color: Color(0xFFADCF86));
                              case 3:
                                return const Icon(Icons.sentiment_neutral, size: 16, color: Colors.grey);
                              case 4:
                                return const Icon(Icons.sentiment_satisfied, size: 16, color: Colors.blue);
                              case 5:
                                return const Icon(Icons.sentiment_very_satisfied, size: 16, color: Colors.green);
                              default:
                                return const SizedBox.shrink();
                            }
                          },
                          reservedSize: 32,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < sortedDays.length) {
                              final day = sortedDays[index];
                              final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  weekdays[day.weekday - 1],
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    minX: 0,
                    maxX: 6,
                    minY: 0.5,
                    maxY: 5.5,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: Theme.of(context).colorScheme.secondary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your mood patterns over the past week',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyChart(BuildContext context, List<DateTime> days) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'No mood data for this week',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}