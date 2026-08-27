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
  return (1.12 - elapsedSeconds * 0.008).clamp(0.34, 1.12);
}

double hazardSpeedFor(double elapsedSeconds) {
  return (88 + elapsedSeconds * 1.05).clamp(88, 176);
}

double hazardBurstChanceFor(double elapsedSeconds) {
  if (elapsedSeconds < 14) return 0;
  return (0.16 + (elapsedSeconds - 14) * 0.006).clamp(0.16, 0.46);
}
