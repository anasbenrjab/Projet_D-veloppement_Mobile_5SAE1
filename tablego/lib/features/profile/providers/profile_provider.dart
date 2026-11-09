import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/data/user_data_changes.dart';
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
  ProfileNotifier(this._repo, {this.onClientPreferencesChanged})
      : super(const ProfileState());

  final ProfileRepository _repo;

  /// Called after a client profile (diets, allergies…) was saved.
  final void Function()? onClientPreferencesChanged;

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
      onClientPreferencesChanged?.call();
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
    final bool needsGeocoding;
    try {
      needsGeocoding = await _repo.updateRestaurantProfile(
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
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _parseError(e));
      return false;
    }
    // The save is done; the map position follows when Nominatim answers.
    if (needsGeocoding) pendingGeocoding = _geocodeInBackground(userId);
    return true;
  }

  /// The background geocoding started by the last save, if any.  Tests await
  /// it; the UI does not.
  @visibleForTesting
  Future<void>? pendingGeocoding;

  /// Never throws: a geocoding failure only means "no map".
  Future<void> _geocodeInBackground(int userId) async {
    try {
      final updated = await _repo.geocodeRestaurantAddress(userId);
      if (updated && mounted) await loadRestaurantProfile(userId);
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] geocoding skipped: $e');
    }
  }

  /// Stores a picked photo and returns the reference that was saved (a file
  /// path on mobile, a `data:` URI on web).
  ///
  /// [sourcePath] is the picked file's path (mobile only); [bytes] carries the
  /// image content and is what web stores in the `profile_photos` table.
  Future<String?> savePhoto({
    required int       userId,
    required String    userType,
    required List<int> bytes,
    String?            mimeType,
    String?            sourcePath,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final ref = await _repo.saveProfilePhoto(
        userId:     userId,
        userType:   userType,
        bytes:      bytes,
        mimeType:   mimeType,
        sourcePath: sourcePath,
      );
      // Reload so the screen shows the new photo immediately.
      if (userType == 'client') {
        await loadClientProfile(userId);
      } else {
        await loadRestaurantProfile(userId);
      }
      return ref;
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

/// Saving a client profile bumps [userDataChangesProvider], so the
/// recommendations follow new diets and allergies immediately.
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(
    ref.watch(profileRepositoryProvider),
    onClientPreferencesChanged: () =>
        ref.read(userDataChangesProvider.notifier).changed(),
  ),
);
