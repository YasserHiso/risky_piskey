enum RiskLevel { safe, minor, high }

class RiskResult {
  final String prediction;
  final RiskLevel level;
  final double probability;
  final int probabilityPercent;
  final Map<String, double> probabilities;

  const RiskResult({
    required this.prediction,
    required this.level,
    required this.probability,
    required this.probabilityPercent,
    required this.probabilities,
  });

  factory RiskResult.fromJson(Map<String, dynamic> json) {
    final prediction = json['prediction'] as String;
    final level = switch (prediction) {
      'No_Accident' => RiskLevel.safe,
      'Minor' => RiskLevel.minor,
      'Major' => RiskLevel.high,
      _ => RiskLevel.minor,
    };
    return RiskResult(
      prediction: prediction,
      level: level,
      probability: (json['probability'] as num).toDouble(),
      probabilityPercent: json['probability_percent'] as int,
      probabilities: (json['probabilities'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
  }

  String get label => switch (level) {
        RiskLevel.safe => 'SAFE',
        RiskLevel.minor => 'MINOR RISK',
        RiskLevel.high => 'HIGH RISK',
      };

  String get emoji => switch (level) {
        RiskLevel.safe => '🟢',
        RiskLevel.minor => '🟡',
        RiskLevel.high => '🔴',
      };

  String get advice => switch (level) {
        RiskLevel.safe => 'Conditions look safe',
        RiskLevel.minor => 'Stay alert',
        RiskLevel.high => '⚠ SLOW DOWN',
      };
}
