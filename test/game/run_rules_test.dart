import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_breaker/game/run_rules.dart';

void main() {
  group('angularDistance', () {
    test('returns the shortest distance across the zero boundary', () {
      expect(angularDistance(0.1, math.pi * 2 - 0.1), closeTo(0.2, 0.0001));
    });

    test('is symmetric', () {
      expect(angularDistance(1.2, 4.8), angularDistance(4.8, 1.2));
    });
  });

  test('score rewards survival, crystals, and near misses', () {
    expect(calculateScore(elapsedSeconds: 10, crystals: 2, nearMisses: 3), 86);
  });

  test('difficulty values remain within safe bounds', () {
    expect(spawnIntervalFor(0), 1.12);
    expect(spawnIntervalFor(10000), 0.34);
    expect(hazardSpeedFor(0), 88);
    expect(hazardSpeedFor(10000), 176);
    expect(hazardBurstChanceFor(10), 0);
    expect(hazardBurstChanceFor(14), 0.16);
    expect(hazardBurstChanceFor(10000), 0.46);
  });
}
