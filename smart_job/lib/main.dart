import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application/controllers/smart_job_controller.dart';
import 'data/database/smart_job_database.dart';
import 'data/local/local_smart_job_repository.dart';
import 'data/remote/smart_job_remote_sync.dart';
import 'data/repositories/smart_job_repository.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  final database = await SmartJobDatabase.open(
    legacyPreferences: sharedPreferences,
  );
  final remoteSync = await _initializeRemoteSync();
  final repository = LocalSmartJobRepository(
    database,
    remoteSync: remoteSync,
  );

  final sessionEmail = database.currentSessionEmail();
  if (remoteSync != null && sessionEmail != null) {
    try {
      final remoteAccount = await remoteSync.fetchAccount(sessionEmail);
      if (remoteAccount != null) {
        repository.cacheRemoteAccount(remoteAccount);
      }
    } catch (_) {
      // Boot with local data if the remote backend is unavailable.
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        smartJobRepositoryProvider.overrideWithValue(repository),
        smartJobRemoteSyncProvider.overrideWithValue(remoteSync),
      ],
      child: const SmartJobApp(),
    ),
  );
}

Future<SmartJobRemoteSync?> _initializeRemoteSync() async {
  try {
    return await SmartJobRemoteSync.initializeFromEnvironment();
  } catch (_) {
    return null;
  }
}

class SmartJobApp extends ConsumerWidget {
  const SmartJobApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SmartJob',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
    );
  }
}
