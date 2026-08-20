import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:game_on/presentation/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme', () {
    testWidgets('should expose brand colors', (tester) async {
      expect(AppTheme.accentRed, const Color(0xFFAE0C00));
      expect(AppTheme.accentRedDark, const Color(0xFF8B0000));
      expect(AppTheme.accentRedLight, const Color(0xFFD32F2F));
      expect(AppTheme.backgroundLight, const Color(0xFFF8F9FA));
      expect(AppTheme.successGreen, const Color(0xFF2E7D32));
      expect(AppTheme.errorRed, const Color(0xFFB00020));
    });

    testWidgets('lightTheme should use material 3 and light brightness',
        (tester) async {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppTheme.backgroundLight);
      expect(theme.primaryColor, AppTheme.accentRed);
      expect(theme.colorScheme.primary, AppTheme.accentRed);
      expect(theme.colorScheme.error, AppTheme.errorRed);
    });

    testWidgets('lightTheme should style app bar, buttons and navigation bar',
        (tester) async {
      final theme = AppTheme.lightTheme;

      expect(theme.appBarTheme.backgroundColor, AppTheme.accentRed);
      expect(theme.appBarTheme.foregroundColor, Colors.white);
      expect(theme.appBarTheme.centerTitle, isTrue);

      final elevatedStyle = theme.elevatedButtonTheme.style;
      expect(elevatedStyle, isNotNull);
      expect(elevatedStyle!.backgroundColor!.resolve({}), AppTheme.accentRed);
      expect(elevatedStyle.foregroundColor!.resolve({}), Colors.white);

      expect(theme.navigationBarTheme.backgroundColor, AppTheme.surfaceWhite);

      final textButtonStyle = theme.textButtonTheme.style;
      expect(textButtonStyle, isNotNull);
      expect(textButtonStyle!.foregroundColor!.resolve({}), AppTheme.accentRed);

      final outlinedStyle = theme.outlinedButtonTheme.style;
      expect(outlinedStyle, isNotNull);
      expect(outlinedStyle!.side!.resolve({}), isNotNull);
    });

    testWidgets('lightTheme should build in a MaterialApp without crashing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Text('Test')),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets(
        'lightTheme should resolve focused field and selected navigation states',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                const TextField(decoration: InputDecoration(labelText: 'Name')),
                NavigationBar(
                  selectedIndex: 0,
                  destinations: const [
                    NavigationDestination(
                        icon: Icon(Icons.home), label: 'Home'),
                    NavigationDestination(
                        icon: Icon(Icons.settings), label: 'Settings'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      // Focus the text field so the floating label / prefix icon resolve.
      await tester.showKeyboard(find.byType(TextField));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    });
  });
}
