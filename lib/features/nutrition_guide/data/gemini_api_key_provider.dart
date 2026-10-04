import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _geminiApiKeyStorageKey = 'panda_gemini_api_key';

class GeminiApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  GeminiApiKeyNotifier() : super(const AsyncValue.loading()) {
    _loadKey();
  }

  Future<void> _loadKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString(_geminiApiKeyStorageKey);
      state = AsyncValue.data(storedKey);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_geminiApiKeyStorageKey, trimmed);
      state = AsyncValue.data(trimmed);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> removeKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_geminiApiKeyStorageKey);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final geminiApiKeyProvider =
    StateNotifierProvider<GeminiApiKeyNotifier, AsyncValue<String?>>((ref) {
  return GeminiApiKeyNotifier();
});
