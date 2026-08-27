import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Alignment, RadialGradient;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';

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
  final List<_Hazard> _hazards = <_Hazard>[];
  final List<_Crystal> _crystals = <_Crystal>[];
  final List<_Particle> _particles = <_Particle>[];
  final List<_TrailPoint> _trail = <_TrailPoint>[];
  final List<Offset> _stars = <Offset>[];

  double _playerAngle = -math.pi / 2;
  double _direction = 1;
  double _elapsed = 0;
  double _spawnClock = 0;
  double _crystalClock = 0;
  double _tapCooldown = 0;
  double _pulse = 0;
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
      for (var index = 0; index < 72; index++) {
        _stars.add(Offset(seeded.nextDouble(), seeded.nextDouble()));
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
    _feedback();
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
    _feedback();
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
    _updateParticles(step);
    if (runState.value != RunState.playing) return;

    _elapsed += step;
    _tapCooldown = math.max(0, _tapCooldown - step);
    final angularSpeed = (1.78 + _elapsed * 0.004).clamp(1.78, 2.28);
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
      if (_crystals.length < 2) _spawnCrystal();
      _crystalClock = 2.4 + _random.nextDouble() * 1.6;
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
    _hazards.add(
      _Hazard(
        angle: _playerAngle + lead,
        radius: radius,
        radialSpeed:
            hazardSpeedFor(_elapsed) * (0.9 + _random.nextDouble() * 0.2),
        rotation: _random.nextDouble() * math.pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 3.4,
        size: 12 + _random.nextDouble() * 5,
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
          _feedback(heavy: true);
        } else {
          _endRun();
          return;
        }
      }

      if (!hazard.resolved && hazard.radius < _orbitRadius - 3) {
        hazard.resolved = true;
        if (angularDistance(hazard.angle, _playerAngle) < 0.52) {
          _nearMisses++;
          _burst(position, dangerColor, count: 8, speed: 65);
          _feedback();
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
        if (charge >= 5) {
          charge = 5;
          _shieldActive = true;
        }
        shieldCharge.value = charge;
        _burst(position, crystalColor, count: 16, speed: 95);
        _feedback();
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
    _feedback(heavy: true);
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

  void _feedback({bool heavy = false}) {
    final profile = store.profile.value;
    if (profile.hapticsEnabled) {
      if (heavy) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    if (profile.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
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
  }

  void _renderBackground(Canvas canvas) {
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.05,
          colors: <Color>[Color(0xFF101B3E), gameBackground],
        ).createShader(bounds),
    );
    final starPaint = Paint()..color = const Color(0xFFFFFFFF);
    for (var index = 0; index < _stars.length; index++) {
      final star = _stars[index];
      final shimmer =
          0.18 + 0.32 * (0.5 + 0.5 * math.sin(_pulse * 1.5 + index));
      starPaint.color = const Color(0xFFFFFFFF).withValues(alpha: shimmer);
      canvas.drawCircle(
        Offset(star.dx * size.x, star.dy * size.y),
        index % 7 == 0 ? 1.3 : 0.7,
        starPaint,
      );
    }
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
