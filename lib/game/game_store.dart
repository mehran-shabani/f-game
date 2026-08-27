import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class PlayerProfile {
  const PlayerProfile({
    this.bestScore = 0,
    this.crystals = 0,
    this.selectedSkin = 0,
    this.unlockedSkins = const <int>{0},
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.tutorialSeen = false,
  });

  final int bestScore;
  final int crystals;
  final int selectedSkin;
  final Set<int> unlockedSkins;
  final bool hapticsEnabled;
  final bool soundEnabled;
  final bool tutorialSeen;

  PlayerProfile copyWith({
    int? bestScore,
    int? crystals,
    int? selectedSkin,
    Set<int>? unlockedSkins,
    bool? hapticsEnabled,
    bool? soundEnabled,
    bool? tutorialSeen,
  }) {
    return PlayerProfile(
      bestScore: bestScore ?? this.bestScore,
      crystals: crystals ?? this.crystals,
      selectedSkin: selectedSkin ?? this.selectedSkin,
      unlockedSkins: unlockedSkins ?? this.unlockedSkins,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
    );
  }
}

class GameStore {
  GameStore({SharedPreferencesAsync? preferences}) {
    if (preferences != null) _preferences = preferences;
  }

  static const _bestKey = 'best_score';
  static const _crystalsKey = 'crystals';
  static const _skinKey = 'selected_skin';
  static const _unlockedKey = 'unlocked_skins';
  static const _hapticsKey = 'haptics_enabled';
  static const _soundKey = 'sound_enabled';
  static const _tutorialKey = 'tutorial_seen';

  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();
  final ValueNotifier<PlayerProfile> profile = ValueNotifier<PlayerProfile>(
    const PlayerProfile(),
  );

  Future<void> load() async {
    final unlockedValues = await _prefs.getStringList(_unlockedKey);
    final unlocked =
        unlockedValues?.map(int.tryParse).whereType<int>().toSet() ?? <int>{0};
    unlocked.add(0);

    profile.value = PlayerProfile(
      bestScore: await _prefs.getInt(_bestKey) ?? 0,
      crystals: await _prefs.getInt(_crystalsKey) ?? 0,
      selectedSkin: await _prefs.getInt(_skinKey) ?? 0,
      unlockedSkins: unlocked,
      hapticsEnabled: await _prefs.getBool(_hapticsKey) ?? true,
      soundEnabled: await _prefs.getBool(_soundKey) ?? true,
      tutorialSeen: await _prefs.getBool(_tutorialKey) ?? false,
    );
  }

  Future<void> completeRun({required int score, required int reward}) async {
    final current = profile.value;
    final next = current.copyWith(
      bestScore: score > current.bestScore ? score : current.bestScore,
      crystals: current.crystals + reward,
    );
    profile.value = next;
    await Future.wait<void>([
      _prefs.setInt(_bestKey, next.bestScore),
      _prefs.setInt(_crystalsKey, next.crystals),
    ]);
  }

  Future<bool> selectOrUnlockSkin({
    required int skinId,
    required int cost,
  }) async {
    final current = profile.value;
    if (current.unlockedSkins.contains(skinId)) {
      profile.value = current.copyWith(selectedSkin: skinId);
      await _prefs.setInt(_skinKey, skinId);
      return true;
    }
    if (current.crystals < cost) return false;

    final unlocked = <int>{...current.unlockedSkins, skinId};
    final next = current.copyWith(
      crystals: current.crystals - cost,
      selectedSkin: skinId,
      unlockedSkins: unlocked,
    );
    profile.value = next;
    await Future.wait<void>([
      _prefs.setInt(_crystalsKey, next.crystals),
      _prefs.setInt(_skinKey, skinId),
      _prefs.setStringList(
        _unlockedKey,
        unlocked.map((value) => '$value').toList(),
      ),
    ]);
    return true;
  }

  Future<void> setHaptics(bool enabled) async {
    profile.value = profile.value.copyWith(hapticsEnabled: enabled);
    await _prefs.setBool(_hapticsKey, enabled);
  }

  Future<void> setSound(bool enabled) async {
    profile.value = profile.value.copyWith(soundEnabled: enabled);
    await _prefs.setBool(_soundKey, enabled);
  }

  Future<void> markTutorialSeen() async {
    profile.value = profile.value.copyWith(tutorialSeen: true);
    await _prefs.setBool(_tutorialKey, true);
  }
}
