import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../data/models/client_profile_model.dart';
import '../data/models/restaurant_profile_model.dart';
import '../data/repositories/profile_repository.dart';
import '../domain/profile_exception.dart';

// ── Sealed profile union ──────────────────────────────────────────────────────

/// Discriminated union so screens never have to cast or check user_type
/// themselves.
sealed class ProfileData {
  const ProfileData();
}

final class ClientData extends ProfileData {
  const ClientData(this.profile);
  final ClientProfileModel profile;
}

final class RestaurantData extends ProfileData {
  const RestaurantData(this.profile);
  final RestaurantProfileModel profile;
}

// ── State ─────────────────────────────────────────────────────────────────────

class ProfileState {
  const ProfileState({
    this.data,
    this.isLoading = false,
    this.error,
  });

  /// Typed profile data. Null until the first successful load.
  final ProfileData? data;
  final bool isLoading;

  /// Non-null when an operation failed. Shown directly in the UI.
  final String? error;

  ProfileState copyWith({
    ProfileData? data,
    bool?        isLoading,
    String?      error,
    bool         clearError = false,
  }) =>
      ProfileState(
        data:      data      ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._repo) : super(const ProfileState());

  final ProfileRepository _repo;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadClientProfile(int userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repo.getClientProfile(userId);
      state = state.copyWith(isLoading: false, data: ClientData(profile));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  Future<void> loadRestaurantProfile(int userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repo.getRestaurantProfile(userId);
      state = state.copyWith(isLoading: false, data: RestaurantData(profile));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
    }
  }

  // ── Update ────────────────────────────────────────────────────────────────

  /// Returns `true` on success so the screen can pop itself.
  Future<bool> updateClientProfile({
    required int userId,
    String?      fullName,
    String?      phone,
    List<String>? dietaryPreferences,
    List<String>? allergies,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateClientProfile(
        userId:              userId,
        fullName:            fullName,
        phone:               phone,
        dietaryPreferences:  dietaryPreferences,
        allergies:           allergies,
      );
      await loadClientProfile(userId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  /// Returns `true` on success so the screen can pop itself.
  Future<bool> updateRestaurantProfile({
    required int         userId,
    String?              name,
    String?              address,
    double?              latitude,
    double?              longitude,
    Map<String, dynamic>? openingHours,
    String?              cuisineType,
    String?              description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateRestaurantProfile(
        userId:       userId,
        name:         name,
        address:      address,
        latitude:     latitude,
        longitude:    longitude,
        openingHours: openingHours,
        cuisineType:  cuisineType,
        description:  description,
      );
      await loadRestaurantProfile(userId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
  }

  Future<String?> savePhoto({
    required int    userId,
    required String userType,
    required String sourcePath,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final path = await _repo.saveProfilePhoto(
        userId:     userId,
        userType:   userType,
        sourcePath: sourcePath,
      );
      // Reload so the screen shows the new photo immediately.
      if (userType == 'client') {
        await loadClientProfile(userId);
      } else {
        await loadRestaurantProfile(userId);
      }
      return path;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void clearError() => state = state.copyWith(clearError: true);

  String _parseError(Object e) {
    if (e is ProfileException) return e.message;
    if (e is DatabaseException) return 'Une erreur interne est survenue.';
    return 'Une erreur inattendue est survenue.';
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ref.watch(profileRepositoryProvider)),
);
