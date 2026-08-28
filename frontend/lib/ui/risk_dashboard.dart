import 'package:flutter/material.dart';
import '../models/risk_result.dart';

const _safe = Color(0xFF31D08C);
const _minor = Color(0xFFFFB01F);
const _high = Color(0xFFFF4B5C);

Color colorForLevel(RiskLevel level) => switch (level) {
      RiskLevel.safe => _safe,
      RiskLevel.minor => _minor,
      RiskLevel.high => _high,
    };

class RiskDashboard extends StatelessWidget {
  final RiskResult? result;
  final bool loading;

  const RiskDashboard({super.key, required this.result, required this.loading});

  @override
  Widget build(BuildContext context) {
    final color = result == null ? const Color(0xFF8B98AD) : colorForLevel(result!.level);
    final pct = result?.probabilityPercent ?? 0;
    final filledSegments = (pct / 5).round().clamp(0, 20);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18212F),
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  result == null ? 'ASSESSING…' : '${result!.emoji} ${result!.label}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: .6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: result?.level == RiskLevel.safe ? Colors.transparent : color,
                  borderRadius: BorderRadius.circular(20),
                  border: result?.level == RiskLevel.safe
                      ? Border.all(color: _safe.withValues(alpha: .5))
                      : null,
                ),
                child: Text(
                  result?.advice ?? 'Waiting…',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: result?.level == RiskLevel.safe ? _safe : const Color(0xFF0E1620),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$pct',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE9EEF6),
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 2),
                child: Text('%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  loading ? 'updating…' : 'model confidence in\nthis prediction',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF8B98AD), height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(20, (i) {
              return Expanded(
                child: Container(
                  height: 9,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i < filledSegments ? color : Colors.white.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          if (result != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: result!.probabilities.entries.map((e) {
                return Text(
                  '${e.key}: ${(e.value * 100).round()}%',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Color(0xFF63708A)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
