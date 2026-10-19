import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/profile_repository.dart';

class ProfileState {
  final Map<String, dynamic>? data;
  final bool isLoading;
  final String? error;

  const ProfileState({this.data, this.isLoading = false, this.error});

  ProfileState copyWith({
    Map<String, dynamic>? data,
    bool? isLoading,
    String? error,
  }) =>
      ProfileState(
        data: data ?? this.data,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._repo) : super(const ProfileState());

  final ProfileRepository _repo;

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getProfile();
      state = state.copyWith(isLoading: false, data: data);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateClientProfile({
    String? fullName,
    String? phone,
    List<String>? dietaryPreferences,
    List<String>? allergies,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.updateClientProfile(
        fullName: fullName,
        phone: phone,
        dietaryPreferences: dietaryPreferences,
        allergies: allergies,
      );
      await loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateRestaurantProfile({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? openingHours,
    String? cuisineType,
    String? description,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.updateRestaurantProfile(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        openingHours: openingHours,
        cuisineType: cuisineType,
        description: description,
      );
      await loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ref.watch(profileRepositoryProvider)),
);
