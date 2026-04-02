import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  AuthState build() => AuthState.signedOut();

  void signIn(String email) {
    state = AuthState(isAuthenticated: true, userEmail: email);
  }

  void signOut() {
    state = AuthState.signedOut();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
