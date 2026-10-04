import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../daily_logger/data/daily_entry_repository.dart';
import '../../daily_logger/domain/daily_entry_model.dart';
import '../../missions/data/missions_repository.dart';
import '../../missions/domain/mission_model.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(SupabaseService.client);
});

final missionsRepositoryProvider = Provider<MissionsRepository>((ref) {
  return MissionsRepository(SupabaseService.client);
});

final dailyEntryRepositoryProvider = Provider<DailyEntryRepository>((ref) {
  return DailyEntryRepository(SupabaseService.client);
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.fetchProfile(user.id);
});

final activeMissionProvider = FutureProvider<Mission?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final repo = ref.watch(missionsRepositoryProvider);
  return await repo.fetchActiveMission(user.id);
});

final dailyEntriesProvider = FutureProvider<List<DailyEntry>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(dailyEntryRepositoryProvider);
  return await repo.fetchRecentEntries(user.id, limit: 30);
});

class ProfileController extends StateNotifier<AsyncValue<void>> {
  final ProfileRepository _profileRepo;
  final MissionsRepository _missionsRepo;
  final Ref _ref;

  ProfileController(this._profileRepo, this._missionsRepo, this._ref)
      : super(const AsyncValue.data(null));

  Future<bool> completeOnboarding({
    required String username,
    required String firstName,
    required String lastName,
    required String sex,
    required DateTime birthDate,
    required double heightCm,
    required double profileStartWeight,
    required int dailyTargetCalories,
    required MissionType firstMissionType,
    required double firstTargetWeight,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('No authenticated user session found.');
      }

      final now = DateTime.now().toUtc();

      // 1. Create Profile
      final profile = UserProfile(
        id: user.id,
        username: username.trim().toLowerCase(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        sex: sex,
        birthDate: birthDate,
        heightCm: heightCm,
        profileStartWeight: profileStartWeight,
        dailyTargetCalories: dailyTargetCalories,
        createdAt: now,
        updatedAt: now,
      );

      await _profileRepo.upsertProfile(profile);

      // 2. Create Initial Active Mission
      final initialMission = Mission(
        id: user.id, // Or auto-generated UUID in Postgres
        userId: user.id,
        missionType: firstMissionType,
        missionStartWeight: profileStartWeight,
        targetWeight: firstTargetWeight,
        status: MissionStatus.active,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await _missionsRepo.createMission(initialMission);

      // Invalidate cache to trigger re-evaluation
      _ref.invalidate(userProfileProvider);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<void>>((ref) {
  final profileRepo = ref.watch(profileRepositoryProvider);
  final missionsRepo = ref.watch(missionsRepositoryProvider);
  return ProfileController(profileRepo, missionsRepo, ref);
});
