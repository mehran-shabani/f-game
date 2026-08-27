import 'package:flutter/material.dart';

import '../game/game_palette.dart';
import '../game/game_store.dart';
import '../game/orbit_breaker_game.dart';

class HomeOverlay extends StatelessWidget {
  const HomeOverlay({super.key, required this.game});

  final OrbitBreakerGame game;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: ValueListenableBuilder<PlayerProfile>(
          valueListenable: game.store.profile,
          builder: (context, profile, _) {
            final selectedSkin = orbitSkins.firstWhere(
              (skin) => skin.id == profile.selectedSkin,
              orElse: () => orbitSkins.first,
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.diamond_rounded,
                        value: '${profile.crystals}',
                        color: crystalColor,
                      ),
                      const Spacer(),
                      _RoundIconButton(
                        tooltip: 'How to play',
                        icon: Icons.help_outline_rounded,
                        onPressed: game.showTutorial,
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        tooltip: profile.soundEnabled
                            ? 'Sound on'
                            : 'Sound off',
                        icon: profile.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        onPressed: () =>
                            game.store.setSound(!profile.soundEnabled),
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        tooltip: profile.hapticsEnabled
                            ? 'Haptics on'
                            : 'Haptics off',
                        icon: profile.hapticsEnabled
                            ? Icons.vibration_rounded
                            : Icons.phone_android_rounded,
                        onPressed: () =>
                            game.store.setHaptics(!profile.hapticsEnabled),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  const Text(
                    'ORBIT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      height: 0.88,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                    ),
                  ),
                  Text(
                    'BREAKER',
                    style: TextStyle(
                      color: selectedSkin.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10,
                      shadows: [
                        Shadow(
                          color: selectedSkin.glow.withValues(alpha: 0.9),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'BEST  ${profile.bestScore.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      color: Color(0xFF8E9AB9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const Spacer(),
                  _SkinPicker(game: game, profile: profile),
                  const SizedBox(height: 28),
                  NeonButton(
                    label: 'START RUN',
                    icon: Icons.play_arrow_rounded,
                    color: selectedSkin.primary,
                    onPressed: game.requestStart,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'TAP TO REVERSE  •  DODGE  •  COLLECT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF697696),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({super.key, required this.game});

  final OrbitBreakerGame game;

  @override
  Widget build(BuildContext context) {
    return _ModalScrim(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HOW TO PLAY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 24),
            const _TutorialStep(
              icon: Icons.touch_app_rounded,
              color: Color(0xFF55F6FF),
              title: 'TAP TO REVERSE',
              detail:
                  'The orb moves by itself. Tap anywhere to change direction.',
            ),
            const SizedBox(height: 16),
            const _TutorialStep(
              icon: Icons.warning_rounded,
              color: dangerColor,
              title: 'DODGE RED MINES',
              detail: 'Reverse before a red mine reaches your orbit.',
            ),
            const SizedBox(height: 16),
            const _TutorialStep(
              icon: Icons.diamond_rounded,
              color: crystalColor,
              title: 'COLLECT 5 = SHIELD',
              detail: 'Green crystals charge a shield that blocks one hit.',
            ),
            const SizedBox(height: 26),
            NeonButton(
              label: 'GOT IT — PLAY',
              color: game.activeSkin.primary,
              icon: Icons.play_arrow_rounded,
              onPressed: game.finishTutorialAndStart,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: game.closeTutorial,
              child: const Text('BACK'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  const _TutorialStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  color: Color(0xFF9CA8C5),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final OrbitBreakerGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: game.runCrystals,
                            builder: (_, value, _) => _StatChip(
                              icon: Icons.diamond_rounded,
                              value: '$value',
                              color: crystalColor,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: game.score,
                                builder: (_, value, _) => Text(
                                  value.toString().padLeft(4, '0'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              ValueListenableBuilder<int>(
                                valueListenable: game.shieldCharge,
                                builder: (_, charge, _) => Row(
                                  children: List.generate(5, (index) {
                                    final active = index < charge;
                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      width: 14,
                                      height: 3,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? crystalColor
                                            : Colors.white.withValues(
                                                alpha: 0.13,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: active
                                            ? const [
                                                BoxShadow(
                                                  color: crystalColor,
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(width: 40, height: 40),
                        ],
                      ),
                      const Spacer(),
                      ValueListenableBuilder<int>(
                        valueListenable: game.orbitDirection,
                        builder: (_, direction, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 120),
                          child: Text(
                            direction > 0 ? 'TAP  ↻' : 'TAP  ↺',
                            key: ValueKey(direction),
                            style: TextStyle(
                              color: game.activeSkin.primary.withValues(
                                alpha: 0.48,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 16),
              child: Material(
                color: Colors.transparent,
                child: _RoundIconButton(
                  tooltip: 'Pause',
                  icon: Icons.pause_rounded,
                  onPressed: game.pauseRun,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final OrbitBreakerGame game;

  @override
  Widget build(BuildContext context) {
    return _ModalScrim(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_rounded, color: Colors.white, size: 42),
            const SizedBox(height: 12),
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 26),
            NeonButton(
              label: 'RESUME',
              color: game.activeSkin.primary,
              icon: Icons.play_arrow_rounded,
              onPressed: game.resumeRun,
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: game.showHome, child: const Text('END RUN')),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final OrbitBreakerGame game;

  @override
  Widget build(BuildContext context) {
    return _ModalScrim(
      child: ValueListenableBuilder<int>(
        valueListenable: game.score,
        builder: (context, score, _) {
          return ValueListenableBuilder<PlayerProfile>(
            valueListenable: game.store.profile,
            builder: (context, profile, _) {
              return GlassPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: game.newBest,
                      builder: (_, isBest, _) => Text(
                        isBest ? 'NEW BEST!' : 'SIGNAL LOST',
                        style: TextStyle(
                          color: isBest ? crystalColor : dangerColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      score.toString().padLeft(4, '0'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 54,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'BEST ${profile.bestScore}   •   +${game.lastReward} ◆',
                      style: const TextStyle(
                        color: Color(0xFFA8B2CD),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    NeonButton(
                      label: 'RETRY',
                      color: game.activeSkin.primary,
                      icon: Icons.refresh_rounded,
                      onPressed: game.startRun,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: game.showHome,
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: const Text('HOME'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SkinPicker extends StatelessWidget {
  const _SkinPicker({required this.game, required this.profile});

  final OrbitBreakerGame game;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: orbitSkins.map((skin) {
        final selected = profile.selectedSkin == skin.id;
        final unlocked = profile.unlockedSkins.contains(skin.id);
        return Semantics(
          button: true,
          label: unlocked
              ? 'Select ${skin.name}'
              : 'Unlock ${skin.name} for ${skin.cost} crystals',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final success = await game.store.selectOrUnlockSkin(
                skinId: skin.id,
                cost: skin.cost,
              );
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Collect ${skin.cost} crystals to unlock ${skin.name}.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 76,
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: selected
                    ? skin.primary.withValues(alpha: 0.13)
                    : Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? skin.primary.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: skin.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: skin.glow, blurRadius: 14)],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    unlocked ? skin.name : '${skin.cost} ◆',
                    style: TextStyle(
                      color: unlocked ? Colors.white70 : crystalColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.bolt_rounded, size: 22),
          label: Text(label),
          style: FilledButton.styleFrom(
            foregroundColor: const Color(0xFF06101C),
            backgroundColor: color,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
      decoration: BoxDecoration(
        color: gamePanel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 40, spreadRadius: 8),
        ],
      ),
      child: child,
    );
  }
}

class _ModalScrim extends StatelessWidget {
  const _ModalScrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB8050816),
      child: SafeArea(child: Center(child: child)),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      color: Colors.white70,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        fixedSize: const Size(40, 40),
      ),
    );
  }
}
