import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_store.dart';
import 'game/orbit_breaker_game.dart';
import 'ui/game_overlays.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final store = GameStore();
  await store.load();
  runApp(OrbitBreakerApp(store: store));
}

class OrbitBreakerApp extends StatelessWidget {
  const OrbitBreakerApp({super.key, required this.store});

  final GameStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orbit Breaker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF55F6FF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF050816),
        fontFamily: 'sans-serif',
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF161D32),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: GameScreen(store: store),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.store});

  final GameStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final OrbitBreakerGame game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = OrbitBreakerGame(store: widget.store);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      game.pauseRun();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ClipRect(
        child: GameWidget<OrbitBreakerGame>(
          game: game,
          initialActiveOverlays: const [OverlayId.home],
          overlayBuilderMap: {
            OverlayId.home: (_, game) => HomeOverlay(game: game),
            OverlayId.hud: (_, game) => HudOverlay(game: game),
            OverlayId.pause: (_, game) => PauseOverlay(game: game),
            OverlayId.gameOver: (_, game) => GameOverOverlay(game: game),
            OverlayId.tutorial: (_, game) => TutorialOverlay(game: game),
          },
        ),
      ),
    );
  }
}
