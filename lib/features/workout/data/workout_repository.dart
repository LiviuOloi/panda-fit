import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/exercise_model.dart';

class WorkoutRepository {
  static const String _storageKey = 'pandafit_workout_sessions';

  Future<List<WorkoutSession>> loadWorkoutSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = jsonDecode(jsonStr) as List<dynamic>;
      final sessions = list
          .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
          .toList();
      // Order descending by start time
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return sessions;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadWorkoutSessions();

    // Check if session already exists, update or prepend
    final existingIndex = current.indexWhere((s) => s.id == session.id);
    if (existingIndex >= 0) {
      current[existingIndex] = session;
    } else {
      current.insert(0, session);
    }

    final rawList = current.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(rawList));
  }

  Future<void> deleteWorkoutSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadWorkoutSessions();
    current.removeWhere((s) => s.id == sessionId);

    final rawList = current.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(rawList));
  }
}
