import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_breaker/game/game_store.dart';
import 'package:orbit_breaker/game/orbit_breaker_game.dart';
import 'package:orbit_breaker/main.dart';
import 'package:orbit_breaker/ui/game_overlays.dart';

void main() {
  testWidgets('home screen exposes the game identity and start action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(OrbitBreakerApp(store: GameStore()));
    await tester.pump();

    expect(find.text('ORBIT'), findsOneWidget);
    expect(find.text('BREAKER'), findsOneWidget);
    expect(find.text('START RUN'), findsOneWidget);
  });

  testWidgets('tap through the HUD reverses the orbit direction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = OrbitBreakerGame(store: GameStore());
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget<OrbitBreakerGame>(
          game: game,
          overlayBuilderMap: {
            OverlayId.hud: (_, game) => HudOverlay(game: game),
          },
        ),
      ),
    );
    await tester.pump();
    game.startRun();
    await tester.pump();

    final directionBeforeTap = game.orbitDirection.value;
    await tester.tapAt(const Offset(180, 400));
    await tester.pump(const Duration(milliseconds: 60));

    expect(game.orbitDirection.value, -directionBeforeTap);
  });
}
