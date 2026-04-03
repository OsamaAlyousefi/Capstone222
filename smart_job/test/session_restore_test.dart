import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:smart_job/data/repositories/smart_job_repository.dart';
import 'package:smart_job/main.dart';

import 'test_support/in_memory_smart_job_repository.dart';

void main() {
  testWidgets('restores a persisted signed-in session on launch', (WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final repository = InMemorySmartJobRepository();
    final account = repository.createAccount(
      fullName: 'Session User',
      email: 'session@example.com',
    );
    repository.saveAccount(
      account.copyWith(
        profile: account.profile.copyWith(hasCompletedOnboarding: true),
      ),
    );
    repository.saveCurrentSessionEmail('session@example.com');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          smartJobRepositoryProvider.overrideWithValue(repository),
        ],
        child: const SmartJobApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Jobs feed'), findsOneWidget);
  });
}
