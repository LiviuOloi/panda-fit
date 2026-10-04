import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../domain/mission_model.dart';

class MissionsRepository {
  final SupabaseClient? _client;

  MissionsRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  Future<Mission?> fetchActiveMission(String userId) async {
    if (_client == null) return null;
    final res = await _client
        .from('missions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'ACTIVE')
        .order('started_at', ascending: false)
        .maybeSingle();

    if (res == null) return null;
    return Mission.fromJson(res);
  }

  Future<List<Mission>> fetchAllMissions(String userId) async {
    if (_client == null) return [];
    final res = await _client
        .from('missions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (res as List<dynamic>)
        .map((m) => Mission.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> createMission(Mission mission) async {
    if (_client == null) return;
    await _client.from('missions').insert(mission.toJson());
  }

  Future<void> updateMissionStatus({
    required String missionId,
    required MissionStatus status,
    DateTime? achievedAt,
  }) async {
    if (_client == null) return;
    await _client.from('missions').update({
      'status': status.name.toUpperCase(),
      'achieved_at': achievedAt?.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', missionId);
  }
}
