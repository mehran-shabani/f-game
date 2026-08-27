import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Alignment, RadialGradient;
import 'package:flutter/foundation.dart' show ValueNotifier;

import 'game_feedback.dart';
import 'game_palette.dart';
import 'game_store.dart';
import 'run_rules.dart';

abstract final class OverlayId {
  static const home = 'home';
  static const hud = 'hud';
  static const pause = 'pause';
  static const gameOver = 'gameOver';
  static const tutorial = 'tutorial';
}

enum RunState { ready, playing, paused, gameOver }

class OrbitBreakerGame extends FlameGame with TapCallbacks {
  OrbitBreakerGame({required this.store});

  final GameStore store;
  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> runCrystals = ValueNotifier<int>(0);
  final ValueNotifier<int> shieldCharge = ValueNotifier<int>(0);
  final ValueNotifier<int> orbitDirection = ValueNotifier<int>(1);
  final ValueNotifier<RunState> runState = ValueNotifier<RunState>(
    RunState.ready,
  );
  final ValueNotifier<bool> newBest = ValueNotifier<bool>(false);

  final math.Random _random = math.Random();
  final math.Random _spaceRandom = math.Random(1907);
  final List<_Hazard> _hazards = <_Hazard>[];
  final List<_Crystal> _crystals = <_Crystal>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_TrailPoint> _trail = <_TrailPoint>[];
  final List<_SpaceStar> _stars = <_SpaceStar>[];

  double _playerAngle = -math.pi / 2;
  double _direction = 1;
  double _elapsed = 0;
  double _spawnClock = 0;
  double _crystalClock = 0;
  double _tapCooldown = 0;
  double _pulse = 0;
  double _spaceTravel = 0;
  double _impactFlash = 0;
  Color _impactColor = const Color(0x00FFFFFF);
  int _nearMisses = 0;
  bool _shieldActive = false;
  int lastReward = 0;

  Offset get _center => Offset(size.x / 2, size.y * 0.49);
  double get _orbitRadius => math.min(size.x * 0.31, size.y * 0.18);
  double get _playerRadius => math.max(9, size.x * 0.027);
  OrbitSkin get activeSkin => orbitSkins.firstWhere(
    (skin) => skin.id == store.profile.value.selectedSkin,
    orElse: () => orbitSkins.first,
  );

  @override
  Color backgroundColor() => gameBackground;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_stars.isEmpty && size.x > 0 && size.y > 0) {
      final seeded = math.Random(731);
      for (var index = 0; index < 112; index++) {
        final depth = 0.25 + seeded.nextDouble() * 0.75;
        _stars.add(
          _SpaceStar(
            x: seeded.nextDouble(),
            y: seeded.nextDouble(),
            depth: depth,
            phase: seeded.nextDouble() * math.pi * 2,
            tint: index % 11 == 0
                ? const Color(0xFF8BD8FF)
                : index % 17 == 0
                ? const Color(0xFFD4A8FF)
                : const Color(0xFFFFFFFF),
          ),
        );
      }
    }
  }

  void startRun() {
    _hazards.clear();
    _crystals.clear();
    _particles.clear();
    _trail.clear();
    _playerAngle = -math.pi / 2;
    _direction = _random.nextBool() ? 1 : -1;
    orbitDirection.value = _direction.toInt();
    _elapsed = 0;
    _spawnClock = 0.55;
    _crystalClock = 1.2;
    _tapCooldown = 0;
    _nearMisses = 0;
    _shieldActive = false;
    lastReward = 0;
    score.value = 0;
    runCrystals.value = 0;
    shieldCharge.value = 0;
    newBest.value = false;
    runState.value = RunState.playing;
    overlays
      ..remove(OverlayId.home)
      ..remove(OverlayId.gameOver)
      ..remove(OverlayId.pause)
      ..remove(OverlayId.tutorial)
      ..add(OverlayId.hud);
    resumeEngine();
    _feedback(FeedbackCue.start);
  }

  void requestStart() {
    if (store.profile.value.tutorialSeen) {
      startRun();
    } else {
      overlays.add(OverlayId.tutorial);
    }
  }

  void showTutorial() {
    overlays.add(OverlayId.tutorial);
  }

  void closeTutorial() {
    overlays.remove(OverlayId.tutorial);
  }

  void finishTutorialAndStart() {
    store.markTutorialSeen();
    startRun();
  }

  void showHome() {
    runState.value = RunState.ready;
    overlays
      ..remove(OverlayId.hud)
      ..remove(OverlayId.pause)
      ..remove(OverlayId.gameOver)
      ..remove(OverlayId.tutorial)
      ..add(OverlayId.home);
    resumeEngine();
  }

  void pauseRun() {
    if (runState.value != RunState.playing) return;
    runState.value = RunState.paused;
    overlays.add(OverlayId.pause);
  }

  void resumeRun() {
    if (runState.value != RunState.paused) return;
    overlays.remove(OverlayId.pause);
    runState.value = RunState.playing;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (runState.value != RunState.playing || _tapCooldown > 0) return;
    _direction *= -1;
    orbitDirection.value = _direction.toInt();
    _tapCooldown = 0.075;
    final player = _playerPosition;
    _burst(player, activeSkin.primary, count: 5, speed: 35);
    _feedback(FeedbackCue.turn);
  }

  Offset get _playerPosition =>
      _center +
      Offset(
        math.cos(_playerAngle) * _orbitRadius,
        math.sin(_playerAngle) * _orbitRadius,
      );

  @override
  void update(double dt) {
    final step = dt.clamp(0.0, 0.05);
    super.update(step);
    _pulse += step;
    _impactFlash = math.max(0, _impactFlash - step * 2.8);
    _updateSpace(step);
    _updateParticles(step);
    if (runState.value != RunState.playing) return;

    _elapsed += step;
    _tapCooldown = math.max(0, _tapCooldown - step);
    final angularSpeed = (1.92 + _elapsed * 0.009).clamp(1.92, 2.78);
    _playerAngle =
        (_playerAngle + _direction * angularSpeed * step) % (math.pi * 2);

    _trail.add(_TrailPoint(position: _playerPosition, life: 1));
    if (_trail.length > 24) _trail.removeAt(0);
    for (final point in _trail) {
      point.life -= step * 1.8;
    }
    _trail.removeWhere((point) => point.life <= 0);

    _spawnClock -= step;
    if (_spawnClock <= 0) {
      _spawnHazard();
      _spawnClock =
          spawnIntervalFor(_elapsed) * (0.84 + _random.nextDouble() * 0.28);
    }

    _crystalClock -= step;
    if (_crystalClock <= 0) {
      if (_crystals.isEmpty) _spawnCrystal();
      _crystalClock = 3.0 + _random.nextDouble() * 1.6;
    }

    _updateHazards(step);
    _updateCrystals(step);
    score.value = calculateScore(
      elapsedSeconds: _elapsed,
      crystals: runCrystals.value,
      nearMisses: _nearMisses,
    );
  }

  void _spawnHazard() {
    final radius = _orbitRadius + math.max(105, size.x * 0.3);
    final lead = _direction * (0.55 + _random.nextDouble() * 1.8);
    _addHazard(angle: _playerAngle + lead, radius: radius);

    if (_random.nextDouble() < hazardBurstChanceFor(_elapsed)) {
      final separation = 0.52 + _random.nextDouble() * 0.42;
      _addHazard(
        angle: _playerAngle + lead - _direction * separation,
        radius: radius + 34 + _random.nextDouble() * 28,
        sizeScale: 0.88,
      );
    }
  }

  void _addHazard({
    required double angle,
    required double radius,
    double sizeScale = 1,
  }) {
    _hazards.add(
      _Hazard(
        angle: angle,
        radius: radius,
        radialSpeed:
            hazardSpeedFor(_elapsed) * (0.92 + _random.nextDouble() * 0.2),
        rotation: _random.nextDouble() * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 4.2,
        size: (14 + _random.nextDouble() * 7) * sizeScale,
      ),
    );
  }

  void _spawnCrystal() {
    var angle = _random.nextDouble() * math.pi * 2;
    if (angularDistance(angle, _playerAngle) < 0.7) angle += 1.1;
    _crystals.add(_Crystal(angle: angle, life: 6.5));
  }

  void _updateHazards(double dt) {
    final player = _playerPosition;
    for (final hazard in _hazards) {
      hazard.radius -= hazard.radialSpeed * dt;
      hazard.rotation += hazard.rotationSpeed * dt;
      final position = _pointAt(hazard.angle, hazard.radius);
      final distance = (position - player).distance;

      if (!hazard.resolved && distance < hazard.size + _playerRadius * 0.75) {
        hazard.resolved = true;
        if (_shieldActive) {
          _shieldActive = false;
          shieldCharge.value = 0;
          _burst(position, activeSkin.primary, count: 28, speed: 150);
          _flash(activeSkin.primary, strength: 0.48);
          _feedback(FeedbackCue.shield);
        } else {
          _endRun();
          return;
        }
      }

      if (!hazard.resolved && hazard.radius < _orbitRadius - 3) {
        hazard.resolved = true;
        if (angularDistance(hazard.angle, _playerAngle) < 0.44) {
          _nearMisses++;
          _burst(position, dangerColor, count: 8, speed: 65);
          _flash(dangerColor, strength: 0.14);
          _feedback(FeedbackCue.nearMiss);
        }
      }
    }
    _hazards.removeWhere((hazard) => hazard.radius < 22);
  }

  void _updateCrystals(double dt) {
    final player = _playerPosition;
    for (final crystal in _crystals) {
      crystal.life -= dt;
      crystal.rotation += dt * 2.2;
      final position = _pointAt(crystal.angle, _orbitRadius);
      if ((position - player).distance < _playerRadius + 12) {
        crystal.collected = true;
        runCrystals.value++;
        var charge = shieldCharge.value + 1;
        if (charge >= 6) {
          charge = 6;
          _shieldActive = true;
        }
        shieldCharge.value = charge;
        _burst(position, crystalColor, count: 16, speed: 95);
        _flash(crystalColor, strength: 0.1);
        _feedback(FeedbackCue.crystal);
      }
    }
    _crystals.removeWhere((crystal) => crystal.collected || crystal.life <= 0);
  }

  void _endRun() {
    if (runState.value != RunState.playing) return;
    runState.value = RunState.gameOver;
    newBest.value = score.value > store.profile.value.bestScore;
    lastReward = math.max(1, runCrystals.value + score.value ~/ 75);
    _burst(_playerPosition, dangerColor, count: 42, speed: 190);
    _flash(dangerColor, strength: 0.72);
    _feedback(FeedbackCue.gameOver);
    overlays
      ..remove(OverlayId.hud)
      ..add(OverlayId.gameOver);
    store.completeRun(score: score.value, reward: lastReward);
  }

  Offset _pointAt(double angle, double radius) =>
      _center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);

  void _burst(
    Offset origin,
    Color color, {
    required int count,
    required double speed,
  }) {
    for (var index = 0; index < count; index++) {
      final angle = _random.nextDouble() * math.pi * 2;
      final velocity = speed * (0.35 + _random.nextDouble() * 0.65);
      _particles.add(
        _Particle(
          position: origin,
          velocity: Offset(math.cos(angle), math.sin(angle)) * velocity,
          color: color,
          life: 0.35 + _random.nextDouble() * 0.45,
          maxLife: 0.8,
          radius: 1.5 + _random.nextDouble() * 2.5,
        ),
      );
    }
  }

  void _updateParticles(double dt) {
    for (final particle in _particles) {
      particle.life -= dt;
      particle.position += particle.velocity * dt;
      particle.velocity *= 0.96;
    }
    _particles.removeWhere((particle) => particle.life <= 0);
  }

  void _updateSpace(double dt) {
    final travelSpeed = runState.value == RunState.playing ? 0.033 : 0.012;
    _spaceTravel = (_spaceTravel + dt * travelSpeed) % 1;
    for (final star in _stars) {
      star.y += dt * travelSpeed * (0.32 + star.depth * 1.15);
      if (star.y > 1.03) {
        star.y -= 1.08;
        star.x = (_spaceRandom.nextDouble() * 0.9) + 0.05;
      }
    }
  }

  void _flash(Color color, {required double strength}) {
    _impactColor = color;
    _impactFlash = math.max(_impactFlash, strength);
  }

  void _feedback(FeedbackCue cue) {
    final profile = store.profile.value;
    unawaited(
      GameFeedback.play(
        cue: cue,
        sound: profile.soundEnabled,
        haptics: profile.hapticsEnabled,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderBackground(canvas);
    _renderArena(canvas);
    _renderTrail(canvas);
    _renderCrystals(canvas);
    _renderHazards(canvas);
    _renderPlayer(canvas);
    _renderParticles(canvas);
    _renderImpactFlash(canvas);
  }

  void _renderBackground(Canvas canvas) {
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.05,
          colors: <Color>[Color(0xFF172651), Color(0xFF080B22), gameBackground],
          stops: <double>[0, 0.54, 1],
        ).createShader(bounds),
    );

    final nebulaShift = math.sin(_spaceTravel * math.pi * 2);
    _drawNebula(
      canvas,
      center: Offset(size.x * (0.12 + nebulaShift * 0.035), size.y * 0.24),
      radius: size.x * 0.56,
      color: const Color(0xFF314DFF),
      alpha: 0.075,
    );
    _drawNebula(
      canvas,
      center: Offset(size.x * (0.94 - nebulaShift * 0.025), size.y * 0.7),
      radius: size.x * 0.5,
      color: const Color(0xFFA12BFF),
      alpha: 0.055,
    );

    final starPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var index = 0; index < _stars.length; index++) {
      final star = _stars[index];
      final shimmer =
          0.2 + 0.48 * (0.5 + 0.5 * math.sin(_pulse * 1.35 + star.phase));
      final position = Offset(star.x * size.x, star.y * size.y);
      final trail =
          (runState.value == RunState.playing ? 3.2 : 1.3) * star.depth;
      starPaint
        ..strokeWidth = 0.55 + star.depth * 1.35
        ..color = star.tint.withValues(alpha: shimmer * star.depth);
      canvas.drawLine(
        position - Offset(0, trail),
        position + Offset(0, trail * 0.35),
        starPaint,
      );
    }
  }

  void _drawNebula(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double alpha,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.42),
    );
  }

  void _renderArena(Canvas canvas) {
    final center = _center;
    final pulse = 1 + math.sin(_pulse * 2.4) * 0.045;
    final coreColor = activeSkin.glow;
    canvas.drawCircle(
      center,
      42 * pulse,
      Paint()
        ..color = coreColor.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );
    canvas.drawCircle(
      center,
      23 * pulse,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            activeSkin.primary.withValues(alpha: 0.9),
            activeSkin.glow.withValues(alpha: 0.08),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 25)),
    );

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = activeSkin.primary.withValues(alpha: 0.2);
    final track = Rect.fromCircle(center: center, radius: _orbitRadius);
    for (var segment = 0; segment < 36; segment++) {
      final start = segment * math.pi * 2 / 36 + _pulse * 0.04;
      canvas.drawArc(track, start, 0.105, false, trackPaint);
    }

    final outerTrack = Rect.fromCircle(
      center: center,
      radius: _orbitRadius + 17,
    );
    final outerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = activeSkin.glow.withValues(alpha: 0.1);
    for (var segment = 0; segment < 12; segment++) {
      final start = segment * math.pi * 2 / 12 - _pulse * 0.09;
      canvas.drawArc(outerTrack, start, 0.22, false, outerPaint);
    }

    for (var node = 0; node < 4; node++) {
      final angle = _pulse * 0.16 + node * math.pi / 2;
      final position = _pointAt(angle, _orbitRadius + 17);
      canvas.drawCircle(
        position,
        1.8,
        Paint()..color = activeSkin.primary.withValues(alpha: 0.5),
      );
    }
  }

  void _renderTrail(Canvas canvas) {
    if (_trail.length < 2) return;
    for (var index = 0; index < _trail.length; index++) {
      final point = _trail[index];
      final alpha = point.life.clamp(0.0, 1.0) * 0.32;
      canvas.drawCircle(
        point.position,
        _playerRadius * point.life * 0.65,
        Paint()
          ..color = activeSkin.primary.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  void _renderPlayer(Canvas canvas) {
    final player = _playerPosition;
    final skin = activeSkin;
    canvas.drawCircle(
      player,
      _playerRadius * 2.2,
      Paint()
        ..color = skin.glow.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );
    if (_shieldActive) {
      canvas.drawCircle(
        player,
        _playerRadius * (1.65 + math.sin(_pulse * 5) * 0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = crystalColor.withValues(alpha: 0.85),
      );
    }
    canvas.drawCircle(
      player,
      _playerRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: <Color>[const Color(0xFFFFFFFF), skin.primary, skin.glow],
        ).createShader(Rect.fromCircle(center: player, radius: _playerRadius)),
    );
  }

  void _renderHazards(Canvas canvas) {
    for (final hazard in _hazards) {
      final position = _pointAt(hazard.angle, hazard.radius);
      final dangerAlpha = hazard.resolved ? 0.28 : 0.95;
      final inward = Offset(math.cos(hazard.angle), math.sin(hazard.angle));
      canvas.drawLine(
        position + inward * (hazard.size * 1.4),
        position + inward * (hazard.size * 3.2),
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = dangerColor.withValues(alpha: 0.14 * dangerAlpha),
      );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(hazard.rotation);
      final path = Path();
      for (var index = 0; index < 6; index++) {
        final angle = index * math.pi / 3;
        final radius = index.isEven ? hazard.size : hazard.size * 0.62;
        final point = Offset(math.cos(angle), math.sin(angle)) * radius;
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = dangerColor.withValues(alpha: 0.18 * dangerAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = dangerColor.withValues(alpha: dangerAlpha),
      );
      canvas.drawCircle(
        Offset.zero,
        hazard.size * 0.24,
        Paint()..color = const Color(0xFFFFD3DB).withValues(alpha: dangerAlpha),
      );
      canvas.restore();
    }
  }

  void _renderCrystals(Canvas canvas) {
    for (final crystal in _crystals) {
      final position = _pointAt(crystal.angle, _orbitRadius);
      final scale = 1 + math.sin(_pulse * 5 + crystal.angle) * 0.12;
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(crystal.rotation);
      final path = Path()
        ..moveTo(0, -10 * scale)
        ..lineTo(7 * scale, 0)
        ..lineTo(0, 10 * scale)
        ..lineTo(-7 * scale, 0)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = crystalColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawPath(path, Paint()..color = crystalColor);
      canvas.restore();
    }
  }

  void _renderParticles(Canvas canvas) {
    for (final particle in _particles) {
      canvas.drawCircle(
        particle.position,
        particle.radius * (particle.life / particle.maxLife).clamp(0.0, 1.0),
        Paint()
          ..color = particle.color.withValues(
            alpha: (particle.life / particle.maxLife).clamp(0.0, 1.0),
          ),
      );
    }
  }

  void _renderImpactFlash(Canvas canvas) {
    if (_impactFlash <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = _impactColor.withValues(alpha: _impactFlash * 0.16),
    );
  }
}

class _Hazard {
  _Hazard({
    required this.angle,
    required this.radius,
    required this.radialSpeed,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
  });

  final double angle;
  double radius;
  final double radialSpeed;
  double rotation;
  final double rotationSpeed;
  final double size;
  bool resolved = false;
}

class _Crystal {
  _Crystal({required this.angle, required this.life});

  final double angle;
  double life;
  double rotation = 0;
  bool collected = false;
}

class _TrailPoint {
  _TrailPoint({required this.position, required this.life});

  final Offset position;
  double life;
}

class _Particle {
  _Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.life,
    required this.maxLife,
    required this.radius,
  });

  Offset position;
  Offset velocity;
  final Color color;
  double life;
  final double maxLife;
  final double radius;
}

class _SpaceStar {
  _SpaceStar({
    required this.x,
    required this.y,
    required this.depth,
    required this.phase,
    required this.tint,
  });

  double x;
  double y;
  final double depth;
  final double phase;
  final Color tint;
}
