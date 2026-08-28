import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../models/scenario.dart';

class DriveGame extends FlameGame {
  Scenario scenario;
  double speedKmh;
  DriveGame({required this.scenario, this.speedKmh = 60});

  late RectangleComponent sky;
  late RectangleComponent grass;
  late RectangleComponent road;
  late RectangleComponent dirt;
  late PositionComponent sceneRoot;
  late CircleComponent sunMoon;
  late _LaneMarkings _lanes;
  late _CarComponent _car;
  late _WeatherLayer _weatherLayer;

  @override
  Future<void> onLoad() async {
    sceneRoot = PositionComponent(size: size, anchor: Anchor.center, position: size / 2);
    add(sceneRoot);

    final groundTop = size.y * 0.62;

    sky = RectangleComponent(
      size: Vector2(size.x, groundTop),
      position: Vector2.zero(),
      paint: Paint()..color = const Color(0xFF79C8EE),
    );
    sceneRoot.add(sky);

    sunMoon = CircleComponent(
      radius: 18,
      position: Vector2(size.x - 50, 40),
      paint: Paint()..color = const Color(0xFFFFE58A),
    );
    sceneRoot.add(sunMoon);

    _addHills(groundTop);

    dirt = RectangleComponent(
      size: Vector2(size.x, size.y - groundTop),
      position: Vector2(0, groundTop),
      paint: Paint()..color = const Color(0xFFA98B63),
    );
    sceneRoot.add(dirt);

    grass = RectangleComponent(
      size: Vector2(size.x, 14),
      position: Vector2(0, groundTop),
      paint: Paint()..color = const Color(0xFF7CC08A),
    );
    sceneRoot.add(grass);

    road = RectangleComponent(
      size: Vector2(size.x, 70),
      position: Vector2(0, groundTop + 14),
      paint: Paint()..color = const Color(0xFF4C5464),
    );
    sceneRoot.add(road);

    _lanes = _LaneMarkings(
      position: Vector2(0, groundTop + 14 + 33),
      trackWidth: size.x,
    );
    sceneRoot.add(_lanes);

    _car = _CarComponent(
      position: Vector2(size.x * 0.26, groundTop + 14 + 5),
    );
    sceneRoot.add(_car);

    _weatherLayer = _WeatherLayer(sceneSize: size);
    add(_weatherLayer);

    applyScenario(scenario);
  }

  void applyScenario(Scenario s) {
    scenario = s;

    Color skyTop, skyBottom, hillNear, hillFar, roadColor;
    if (s.light == 'Dark_Unlit') {
      skyTop = const Color(0xFF060B18);
      skyBottom = const Color(0xFF151F35);
      hillFar = const Color(0xFF141C1F);
      hillNear = const Color(0xFF0E1517);
      roadColor = const Color(0xFF1C222E);
      sunMoon.paint.color = const Color(0xFFCBD3E0);
    } else if (s.isNight) {
      skyTop = const Color(0xFF0B1324);
      skyBottom = const Color(0xFF1E2B44);
      hillFar = const Color(0xFF1D2E33);
      hillNear = const Color(0xFF152329);
      roadColor = const Color(0xFF242B38);
      sunMoon.paint.color = const Color(0xFFE7EDF7);
    } else if (s.isRain || s.isFog || s.isStorm) {
      skyTop = const Color(0xFF5E6E82);
      skyBottom = const Color(0xFF93A1B0);
      hillFar = const Color(0xFF5C7F68);
      hillNear = const Color(0xFF456B54);
      roadColor = const Color(0xFF3B4353);
      sunMoon.paint.color = Colors.transparent;
    } else {
      skyTop = const Color(0xFF79C8EE);
      skyBottom = const Color(0xFFCFEBF7);
      hillFar = const Color(0xFF93C39B);
      hillNear = const Color(0xFF6FAE7C);
      roadColor = const Color(0xFF4C5464);
      sunMoon.paint.color = const Color(0xFFFFE58A);
    }
    sky.paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, sky.size.y),
      [skyTop, skyBottom],
    );
    _hillFarPaint.color = hillFar;
    _hillNearPaint.color = hillNear;
    road.paint.color = roadColor;

    _weatherLayer.setConditions(
      rain: s.isRain || s.isStorm,
      fog: s.isFog,
      night: s.isNight,
      unlit: s.light == 'Dark_Unlit',
      windy: s.isStorm,
    );
  }

  final Paint _hillFarPaint = Paint()..color = const Color(0xFF93C39B);
  final Paint _hillNearPaint = Paint()..color = const Color(0xFF6FAE7C);

  void _addHills(double groundTop) {
    final farPath = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(size.x * 0.2, groundTop - 55, size.x * 0.45, groundTop - 20)
      ..quadraticBezierTo(size.x * 0.7, groundTop + 10, size.x, groundTop - 35)
      ..lineTo(size.x, groundTop)
      ..close();
    final nearPath = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(size.x * 0.25, groundTop - 30, size.x * 0.55, groundTop - 5)
      ..quadraticBezierTo(size.x * 0.8, groundTop + 15, size.x, groundTop - 15)
      ..lineTo(size.x, groundTop)
      ..close();
    sceneRoot.add(_PathComponent(path: farPath, paint: _hillFarPaint));
    sceneRoot.add(_PathComponent(path: nearPath, paint: _hillNearPaint));
  }

  @override
  void update(double dt) {
    super.update(dt);
    final scrollSpeed = 20 + (speedKmh / 200) * 260;
    _lanes.scroll(dt * scrollSpeed);
  }
}

class _PathComponent extends PositionComponent {
  final Path path;
  final Paint paint;
  _PathComponent({required this.path, required this.paint});
  @override
  void render(Canvas canvas) => canvas.drawPath(path, paint);
}

class _LaneMarkings extends PositionComponent {
  double _offset = 0;
  final double trackWidth;
  _LaneMarkings({required Vector2 position, required this.trackWidth})
      : super(position: position, size: Vector2(trackWidth, 4));

  void scroll(double dx) {
    _offset = (_offset + dx) % 60;
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFD5DBE4).withValues(alpha: .85);
    for (double x = -_offset; x < trackWidth; x += 60) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 28, 4), paint);
    }
  }
}

class _CarComponent extends PositionComponent {
  _CarComponent({required Vector2 position}) : super(position: position, size: Vector2(120, 56));

  @override
  void render(Canvas canvas) {
    final body = Paint()..color = const Color(0xFFF1F4F9);
    final windows = Paint()..color = const Color(0xFF3A455A);
    final wheel = Paint()..color = const Color(0xFF1B212B);
    final rim = Paint()..color = const Color(0xFFC3CBD8);
    final tail = Paint()..color = const Color(0xFFFF5B69);
    final head = Paint()..color = const Color(0xFFFFE9A8);
    final shadow = Paint()..color = Colors.black.withValues(alpha: .18);

    canvas.drawOval(Rect.fromCenter(center: const Offset(60, 54), width: 108, height: 8), shadow);

    final bodyPath = Path()
      ..moveTo(4, 40)
      ..quadraticBezierTo(4, 44, 8, 44)
      ..lineTo(112, 44)
      ..quadraticBezierTo(116, 44, 116, 38)
      ..lineTo(116, 32)
      ..quadraticBezierTo(116, 28, 111, 27)
      ..lineTo(98, 24)
      ..lineTo(86, 11)
      ..quadraticBezierTo(83, 7, 78, 7)
      ..lineTo(48, 7)
      ..quadraticBezierTo(43, 7, 41, 10)
      ..lineTo(30, 24)
      ..lineTo(10, 26)
      ..quadraticBezierTo(4, 27, 4, 32)
      ..close();
    canvas.drawPath(bodyPath, body);

    canvas.drawPath(
      Path()
        ..moveTo(47, 11)
        ..lineTo(65, 11)
        ..lineTo(65, 23)
        ..lineTo(38, 23)
        ..close(),
      windows,
    );
    canvas.drawPath(
      Path()
        ..moveTo(69, 11)
        ..lineTo(78, 11)
        ..lineTo(86, 23)
        ..lineTo(69, 23)
        ..close(),
      windows,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(107, 30, 8, 6), const Radius.circular(2)),
      head,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(4, 30, 7, 6), const Radius.circular(2)),
      tail,
    );

    for (final cx in [33.0, 90.0]) {
      canvas.drawCircle(Offset(cx, 45), 10.5, wheel);
      canvas.drawCircle(Offset(cx, 45), 4.2, rim);
    }
  }
}

class _WeatherLayer extends PositionComponent with HasGameReference<DriveGame> {
  bool rain = false, fog = false, night = false, unlit = false, windy = false;
  final List<Offset> _drops = [];
  final List<Offset> _gusts = [];
  final Vector2 sceneSize;
  final Random _rng = Random(7);

  _WeatherLayer({required this.sceneSize}) : super(size: sceneSize) {
    for (var i = 0; i < 40; i++) {
      _drops.add(Offset(_rng.nextDouble() * sceneSize.x, _rng.nextDouble() * sceneSize.y));
    }
    for (var i = 0; i < 6; i++) {
      _gusts.add(Offset(_rng.nextDouble() * sceneSize.x, sceneSize.y * (0.35 + _rng.nextDouble() * 0.4)));
    }
  }

  void setConditions({
    required bool rain,
    required bool fog,
    required bool night,
    required bool unlit,
    required bool windy,
  }) {
    this.rain = rain;
    this.fog = fog;
    this.night = night;
    this.unlit = unlit;
    this.windy = windy;
  }

  double _t = 0;
  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    if (night) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sceneSize.x, sceneSize.y),
        Paint()..color = const Color(0xFF060B18).withValues(alpha: unlit ? 0.55 : 0.35),
      );
      if (!unlit) {
        final groundTop = sceneSize.y * 0.62;
        final carX = sceneSize.x * 0.26;
        final carY = groundTop + 14 + 5;
        final headlightX = carX + 111;
        final headlightY = carY + 33;
        final beamReach = sceneSize.x * 0.3;
        final beam = Path()
          ..moveTo(headlightX, headlightY - 4)
          ..lineTo(headlightX, headlightY + 4)
          ..lineTo(headlightX + beamReach, headlightY + 30)
          ..lineTo(headlightX + beamReach, headlightY + 4)
          ..close();
        canvas.drawPath(beam, Paint()..color = const Color(0xFFFFF1C4).withValues(alpha: .22));
      }
    }
    if (fog) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sceneSize.x, sceneSize.y),
        Paint()..color = Colors.white.withValues(alpha: .35),
      );
    }
    if (rain) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..strokeWidth = 1.4;
      for (final d in _drops) {
        final yOff = (d.dy + _t * 500) % sceneSize.y;
        canvas.drawLine(Offset(d.dx, yOff), Offset(d.dx - 6, yOff + 14), paint);
      }
    }
    if (windy) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: .28)
        ..strokeWidth = 2;
      for (final g in _gusts) {
        final xOff = (g.dx - _t * 220) % (sceneSize.x + 60) - 30;
        canvas.drawLine(Offset(xOff, g.dy), Offset(xOff - 26, g.dy + 3), paint);
      }
    }
  }
}
