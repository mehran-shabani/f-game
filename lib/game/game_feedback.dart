import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FeedbackCue { start, turn, crystal, nearMiss, shield, gameOver }

abstract final class GameFeedback {
  static const MethodChannel _channel = MethodChannel(
    'com.orbitforge.orbit_breaker/feedback',
  );

  static Future<void> play({
    required FeedbackCue cue,
    required bool sound,
    required bool haptics,
  }) async {
    if (!sound && !haptics) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('playFeedback', <String, Object>{
          'cue': cue.name,
          'sound': sound,
          'haptics': haptics,
        });
        return;
      } on MissingPluginException {
        // Fall through for tests and non-embedded Android environments.
      } on PlatformException {
        // Keep feedback best-effort; gameplay must never stop for device audio.
      }
    }

    if (haptics) {
      if (cue == FeedbackCue.shield || cue == FeedbackCue.gameOver) {
        await HapticFeedback.heavyImpact();
      } else if (cue == FeedbackCue.crystal || cue == FeedbackCue.nearMiss) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.selectionClick();
      }
    }
    if (sound) await SystemSound.play(SystemSoundType.click);
  }
}
