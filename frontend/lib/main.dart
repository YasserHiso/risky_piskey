import 'package:flutter/material.dart';
import 'ui/simulator_page.dart';

void main() {
  runApp(const DriveRiskApp());
}

class DriveRiskApp extends StatelessWidget {
  const DriveRiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Risky Piskey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0C1017),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF31D08C),
          brightness: Brightness.dark,
        ),
      ),
      home: const SimulatorPage(),
    );
  }
}
