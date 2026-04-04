import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smart_job/data/repositories/smart_job_repository.dart';
import 'package:smart_job/presentation/home/home_screen.dart';
import 'package:smart_job/theme/app_theme.dart';

import 'test_support/in_memory_smart_job_repository.dart';

void main() {
  testWidgets('home screen renders feed content', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final repository = InMemorySmartJobRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartJobRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Jobs feed'), findsOneWidget);
    expect(find.text('Flutter Product Engineer'), findsOneWidget);
  });
}
