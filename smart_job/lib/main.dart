import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/controllers/auth_controller.dart' hide AuthState;
import 'application/controllers/smart_job_controller.dart';
import 'data/database/smart_job_database.dart';
import 'data/local/local_smart_job_repository.dart';
import 'data/remote/smart_job_remote_sync.dart';
import 'data/repositories/smart_job_repository.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

late final SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  supabase = Supabase.instance.client;
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
      child: const MyApp(),
    ),
  );
}

Future<SmartJobRemoteSync?> _initializeRemoteSync() async {
  try {
    return SmartJobRemoteSync.fromClient(supabase);
  } catch (_) {
    return null;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return AuthGate(
      goRouter: goRouter,
      themeMode: themeMode,
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({
    super.key,
    required this.goRouter,
    required this.themeMode,
  });

  final GoRouter goRouter;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        _syncAuthState(ref, session);

        return MaterialApp.router(
          title: 'SmartJob',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: goRouter,
        );
      },
    );
  }

  void _syncAuthState(WidgetRef ref, Session? session) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authNotifier = ref.read(authControllerProvider.notifier);
      final smartJobNotifier = ref.read(smartJobControllerProvider.notifier);
      final authState = ref.read(authControllerProvider);
      final email = session?.user.email?.trim().toLowerCase();

      if (email == null || session == null) {
        if (authState.isAuthenticated) {
          authNotifier.signOut();
          smartJobNotifier.resetForLogout();
        }
        return;
      }

      if (!authState.isAuthenticated || authState.userEmail != email) {
        authNotifier.signIn(email);
        smartJobNotifier.loadAccountForLogin(email);
      }
    });
  }
}

class SmartJobApp extends MyApp {
  const SmartJobApp({super.key});
}
