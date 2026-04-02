import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_job/data/local/local_smart_job_repository.dart';
import 'package:smart_job/data/repositories/smart_job_repository.dart';
import 'package:smart_job/main.dart';

void main() {
  testWidgets('login routes a new account into CV onboarding', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartJobRepositoryProvider.overrideWithValue(
            LocalSmartJobRepository(sharedPreferences),
          ),
        ],
        child: const SmartJobApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    final loginButton = find.widgetWithText(ElevatedButton, 'Login');
    await tester.ensureVisible(loginButton);
    await tester.tap(loginButton, warnIfMissed: false);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Upload your CV or start with the builder.'), findsOneWidget);
    expect(find.text('Real CV upload'), findsOneWidget);
  });
}
