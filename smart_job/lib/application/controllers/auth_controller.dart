import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/smart_job_repository.dart';

class AuthState {
  const AuthState({
    required this.isAuthenticated,
    this.userEmail,
  });

  final bool isAuthenticated;
  final String? userEmail;

  AuthState copyWith({
    bool? isAuthenticated,
    String? userEmail,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userEmail: userEmail ?? this.userEmail,
    );
  }

  factory AuthState.signedOut() => const AuthState(isAuthenticated: false);
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repository = ref.read(smartJobRepositoryProvider);
    final email = repository.currentSessionEmail();
    if (email == null) {
      return AuthState.signedOut();
    }
    return AuthState(isAuthenticated: true, userEmail: email);
  }

  void signIn(String email) {
    final repository = ref.read(smartJobRepositoryProvider);
    repository.saveCurrentSessionEmail(email);
    state = AuthState(isAuthenticated: true, userEmail: email);
  }

  void signOut() {
    final repository = ref.read(smartJobRepositoryProvider);
    repository.clearCurrentSession();
    state = AuthState.signedOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
