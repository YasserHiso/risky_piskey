import 'package:flutter_test/flutter_test.dart';

import 'package:drive_risk_simulator/main.dart';

void main() {
  testWidgets('Simulator page renders the risk dashboard and controls', (
    tester,
  ) async {
    await tester.pumpWidget(const DriveRiskApp());
    await tester.pump();

    expect(find.text('Risky Piskey'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Seatbelt'), findsOneWidget);
  });
}
