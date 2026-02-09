import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repositories/database_service.dart';
import 'screens/main_navigation.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    print('DEBUG: Initializing database...');
    await DatabaseService.init();
    print('DEBUG: Database initialized.');

    runApp(
      const ProviderScope(
        child: GameOnApp(),
      ),
    );
  } catch (e, stack) {
    print('CRITICAL ERROR during initialization: $e');
    print(stack);

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
