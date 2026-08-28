import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../api/risk_api_client.dart';
import '../game/drive_game.dart';
import '../models/risk_result.dart';
import '../models/scenario.dart';
import 'controls_panel.dart';
import 'risk_dashboard.dart';

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});

  @override
  State<SimulatorPage> createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> {
  final RiskApiClient _api = RiskApiClient();
  late DriveGame _game;
  final Random _rng = Random();

  Scenario _scenario = kScenarios.first;
  double _speedKmh = 60;
  bool _seatbeltWorn = true;

  RiskResult? _result;
  bool _loading = false;
  String? _error;
  bool _backendUp = true;

  Timer? _envTimer;
  Timer? _debounce;
  int _secondsToNextChange = 10;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _game = DriveGame(scenario: _scenario, speedKmh: _speedKmh);
    _checkBackend();
    _requestPrediction();
    _envTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _cycleScenario(),
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _secondsToNextChange = _secondsToNextChange > 0
            ? _secondsToNextChange - 1
            : 10;
      });
    });
  }

  Future<void> _checkBackend() async {
    final up = await _api.checkHealth();
    if (mounted) setState(() => _backendUp = up);
  }

  void _cycleScenario() {
    Scenario next;
    do {
      next = kScenarios[_rng.nextInt(kScenarios.length)];
    } while (next.name == _scenario.name && kScenarios.length > 1);
    setState(() {
      _scenario = next;
      _secondsToNextChange = 10;
    });
    _game.applyScenario(next);
    _requestPrediction();
  }

  void _onSpeedChanged(double value) {
    setState(() {
      _speedKmh = value;
      _game.speedKmh = value;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _requestPrediction);
  }

  void _onSeatbeltChanged(bool worn) {
    setState(() => _seatbeltWorn = worn);
    _requestPrediction();
  }

  Future<void> _requestPrediction() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final fields = _scenario.toApiFields(
      speedKmh: _speedKmh,
      seatbeltWorn: _seatbeltWorn,
    );
    try {
      final result = await _api.predict(fields);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        _backendUp = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _backendUp = false;
        _error = 'Could not reach the prediction server.\n$e';
      });
    }
  }

  @override
  void dispose() {
    _envTimer?.cancel();
    _debounce?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _TopBar(backendUp: _backendUp),
                if (!_backendUp)
                  _BackendWarning(error: _error, onRetry: _requestPrediction),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _SimScene(
                          game: _game,
                          scenario: _scenario,
                          secondsToNextChange: _secondsToNextChange,
                          riskLevel: _result?.level,
                        ),
                        RiskDashboard(result: _result, loading: _loading),
                        ControlsPanel(
                          speedKmh: _speedKmh,
                          seatbeltWorn: _seatbeltWorn,
                          onSpeedChanged: _onSpeedChanged,
                          onSeatbeltChanged: _onSeatbeltChanged,
                        ),
                        _IoStrip(
                          scenario: _scenario,
                          speedKmh: _speedKmh,
                          seatbeltWorn: _seatbeltWorn,
                          result: _result,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool backendUp;
  const _TopBar({required this.backendUp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Risky Piskey',
            style: TextStyle(
              color: Color(0xFFE9EEF6),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: backendUp
                      ? const Color(0xFF31D08C)
                      : const Color(0xFFFF4B5C),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                backendUp ? 'model live' : 'offline',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Color(0xFF8B98AD),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackendWarning extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  const _BackendWarning({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4B5C).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFFF4B5C), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Backend unreachable. Start it with:\nml/.venv/bin/uvicorn backend.main:app --port 8000',
              style: TextStyle(fontSize: 11, color: Color(0xFFFF4B5C)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _SimScene extends StatelessWidget {
  final DriveGame game;
  final Scenario scenario;
  final int secondsToNextChange;
  final RiskLevel? riskLevel;

  const _SimScene({
    required this.game,
    required this.scenario,
    required this.secondsToNextChange,
    required this.riskLevel,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = riskLevel == RiskLevel.high
        ? const Color(0xFFFF4B5C)
        : Colors.white.withValues(alpha: .09);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ringColor,
          width: riskLevel == RiskLevel.high ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: GameWidget(game: game)),
          Positioned(
            left: 10,
            top: 10,
            right: 10,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _pill('Weather', scenario.weather),
                _pill('Road', scenario.roadSurface),
                _pill('Light', scenario.isNight ? 'Night' : 'Day'),
                if (scenario.isStorm) _pill('Wind', 'visual only'),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _tag('next change ${secondsToNextChange}s'),
          ),
          Positioned(left: 10, bottom: 10, child: _tag(scenario.name)),
        ],
      ),
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111C).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Color(0xFF9DA9BC),
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEEF3FA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B111C).withValues(alpha: .72),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.5,
          color: Color(0xFFDCE4EF),
        ),
      ),
    );
  }
}

class _IoStrip extends StatelessWidget {
  final Scenario scenario;
  final double speedKmh;
  final bool seatbeltWorn;
  final RiskResult? result;

  const _IoStrip({
    required this.scenario,
    required this.speedKmh,
    required this.seatbeltWorn,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final input =
        '${speedKmh.round()}km/h · belt ${seatbeltWorn ? "Y" : "N"} · '
        '${scenario.weather} · ${scenario.roadSurface} · ${scenario.isNight ? "night" : "day"}';
    final output = result == null ? '…' : result!.prediction;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF131B27),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Row(
        children: [
          const Text(
            'INPUT',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              color: Color(0xFF5C6880),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              input,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                color: Color(0xFFC7D2E2),
              ),
            ),
          ),
          Text(
            '→ $output',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFB01F),
            ),
          ),
        ],
      ),
    );
  }
}
