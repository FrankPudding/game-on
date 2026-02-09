import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config.dart';
import 'core/injection_container.dart';
import 'presentation/screens/main_navigation.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('Initializing app...');
    await initInjection(AppConfig());
    debugPrint('Initialization complete.');

    runApp(
      const ProviderScope(
        child: GameOnApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint('CRITICAL ERROR during initialization: $e');
    debugPrint(stack.toString());

    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SelectableText('Failed to initialize: $e\n\n$stack'),
            ),
          ),
        ),
      ),
    );
  }
}

class GameOnApp extends StatelessWidget {
  const GameOnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game On',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigation(),
    );
  }
}
