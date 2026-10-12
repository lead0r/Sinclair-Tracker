import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'episode_list_page.dart';
import 'episode_state_provider.dart';
import 'list_view_preferences.dart';
import 'services/cover_storage/cover_prefetch_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(SinclairTrackerApp(preferences: preferences));
}

class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences) {
    _mode = switch (_preferences.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _palette = AppColorPalette.values.firstWhere(
      (palette) => palette.name == _preferences.getString('theme_palette'),
      orElse: () => AppColorPalette.bloodRed,
    );
  }

  final SharedPreferences _preferences;
  late ThemeMode _mode;
  late AppColorPalette _palette;

  ThemeMode get mode => _mode;
  AppColorPalette get palette => _palette;

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    await _preferences.setString('theme_mode', mode.name);
  }

  Future<void> setPalette(AppColorPalette palette) async {
    _palette = palette;
    notifyListeners();
    await _preferences.setString('theme_palette', palette.name);
  }
}

enum AppColorPalette {
  bloodRed('Blutrot', Color(0xFFD11A2A)),
  violet('Violett', Color(0xFF7C3AED)),
  magenta('Magenta', Color(0xFFC2185B)),
  midnightBlue('Nachtblau', Color(0xFF2563EB)),
  emerald('Smaragd', Color(0xFF00897B)),
  silver('Silber', Color(0xFF607D8B));

  const AppColorPalette(this.label, this.seedColor);

  final String label;
  final Color seedColor;
}

class SinclairTrackerApp extends StatelessWidget {
  const SinclairTrackerApp({super.key, required this.preferences});

  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController(preferences)),
        ChangeNotifierProvider(
          create: (_) => EpisodeListPreferences(preferences),
        ),
        ChangeNotifierProvider(create: (_) => EpisodeStateProvider()..load()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Sinclair Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: _theme(Brightness.light, theme.palette.seedColor),
          darkTheme: _theme(Brightness.dark, theme.palette.seedColor),
          home: const _AppGate(),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness, Color seedColor) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _promptScheduled = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EpisodeStateProvider>();
    if (state.loading && state.episodes.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null && state.episodes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Der Episodenkatalog konnte nicht geladen werden.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: state.load,
                  child: const Text('Erneut versuchen'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (!_promptScheduled && state.episodes.isNotEmpty) {
      _promptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _offerCoverDownload(state),
      );
    }
    return const EpisodeListPage();
  }

  Future<void> _offerCoverDownload(EpisodeStateProvider state) async {
    final service = CoverWarmupService.instance;
    final plan = await service.planForOnboarding(episodes: state.episodes);
    if (!mounted || plan == null) return;
    final megabytes = (plan.estimatedBytesTotal / (1024 * 1024)).round();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cover offline speichern?'),
        content: Text(
          '${plan.missingCount} Cover können dauerhaft auf diesem Gerät '
          'gespeichert werden (ca. $megabytes MB). Die App funktioniert auch ohne Download.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Später'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await service.startWarmup(
        plan: plan,
        userInitiated: true,
        persistOptIn: true,
      );
    } else {
      await service.postponeOnboarding();
    }
  }
}
