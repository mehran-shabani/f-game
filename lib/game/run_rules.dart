import 'dart:math' as math;

double angularDistance(double first, double second) {
  final difference = (first - second).abs() % (math.pi * 2);
  return math.min(difference, math.pi * 2 - difference);
}

int calculateScore({
  required double elapsedSeconds,
  required int crystals,
  required int nearMisses,
}) {
  return (elapsedSeconds * 5).floor() + crystals * 15 + nearMisses * 2;
}

double spawnIntervalFor(double elapsedSeconds) {
  return (1.35 - elapsedSeconds * 0.006).clamp(0.48, 1.35);
}

double hazardSpeedFor(double elapsedSeconds) {
  return (72 + elapsedSeconds * 0.7).clamp(72, 132);
}
