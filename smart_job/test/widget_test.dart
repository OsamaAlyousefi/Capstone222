import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_job/data/local/local_smart_job_repository.dart';
import 'package:smart_job/data/repositories/smart_job_repository.dart';
import 'package:smart_job/main.dart';

void main() {
  testWidgets('shows SmartJob login shell on launch', (WidgetTester tester) async {
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

    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(
      find.text('Find jobs faster. Apply smarter. Track everything in one place.'),
      findsOneWidget,
    );
  });
}


