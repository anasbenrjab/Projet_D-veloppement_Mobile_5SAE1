import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import '../domain/auth_exception.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.resetQuestion,
  });

  final UserModel? user;
  final bool isLoading;

  /// Non-null when an operation failed.  Shown directly in the UI.
  final String? error;

  /// Populated after a successful [AuthNotifier.getResetQuestion] call.
  /// The forgot-password screen uses this to render step 2.
  final String? resetQuestion;

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    String? resetQuestion,
    bool clearUser = false,
    bool clearError = false,
    bool clearResetQuestion = false,
  }) =>
      AuthState(
        user:          clearUser          ? null  : user          ?? this.user,
        isLoading:     isLoading                  ?? this.isLoading,
        error:         clearError         ? null  : error         ?? this.error,
        resetQuestion: clearResetQuestion ? null  : resetQuestion ?? this.resetQuestion,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  // ── Session restore ───────────────────────────────────────────────────────

  /// Called from [SplashScreen].  Restores a previous session if the stored
  /// user id resolves to an active account.
  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.getSessionUser();
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      // Session restore failure is non-fatal — treat as logged out.
      state = state.copyWith(isLoading: false, clearUser: true);
    }
  }

  // ── Login / Register ──────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.login(email: email, password: password);
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String userType,
    required String resetQuestion,
    required String resetAnswer,
    String? restaurantName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _repo.register(
        email:          email,
        password:       password,
        userType:       userType,
        resetQuestion:  resetQuestion,
        resetAnswer:    resetAnswer,
        restaurantName: restaurantName,
      );
      state = state.copyWith(isLoading: false, user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  // ── Password management ───────────────────────────────────────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.user == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.changePassword(
        userId:          state.user!.id,
        currentPassword: currentPassword,
        newPassword:     newPassword,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  /// Step 1 of the forgot-password flow.
  ///
  /// Loads the security question for [email].  On success, [AuthState.resetQuestion]
  /// is populated and the screen can show step 2.  On failure (no account /
  /// no question), [AuthState.error] is set with a generic message.
  Future<void> getResetQuestion(String email) async {
    state = state.copyWith(
        isLoading: true, clearError: true, clearResetQuestion: true);
    try {
      final question = await _repo.getResetQuestion(email);
      if (question == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Aucune question de sécurité trouvée pour cet email.',
        );
      } else {
        state = state.copyWith(isLoading: false, resetQuestion: question);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  /// Step 2 of the forgot-password flow.
  ///
  /// Returns `true` on success so the screen can navigate away.
  Future<bool> resetPassword({
    required String email,
    required String answer,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.resetPassword(
        email:       email,
        answer:      answer,
        newPassword: newPassword,
      );
      state = state.copyWith(
          isLoading: false, clearResetQuestion: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  // ── Account ───────────────────────────────────────────────────────────────

  Future<void> deleteAccount() async {
    if (state.user == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.deleteAccount(state.user!.id);
      state = const AuthState(); // full reset
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);

  void clearResetQuestion() =>
      state = state.copyWith(clearResetQuestion: true, clearError: true);

  /// Converts any thrown value into a user-facing French string.
  ///
  /// - [AuthException] → use its message directly (already user-facing)
  /// - [DatabaseException] → generic message (internal detail must not leak)
  /// - anything else → generic fallback
  String _parseError(Object e) {
    if (e is AuthException) return e.message;
    if (e is DatabaseException) {
      return 'Une erreur interne est survenue. Réessayez.';
    }
    return 'Une erreur inattendue est survenue.';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);
