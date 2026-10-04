import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/profile_model.dart';

class ProfileRepository {
  final SupabaseClient? _client;

  ProfileRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  Future<UserProfile?> fetchProfile(String userId) async {
    if (_client == null) return null;
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (res == null) return null;
    return UserProfile.fromJson(res);
  }

  Future<void> upsertProfile(UserProfile profile) async {
    if (_client == null) return;
    await _client.from('profiles').upsert(profile.toJson());
  }

  /// Checks if daily entries exist to determine starting weight lock state
  Future<bool> hasDailyEntries(String userId) async {
    if (_client == null) return false;
    final res = await _client
        .from('daily_entries')
        .select('id')
        .eq('user_id', userId)
        .limit(1);

    return res.isNotEmpty;
  }
}
