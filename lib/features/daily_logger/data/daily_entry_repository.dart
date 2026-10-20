import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/calculation_engine.dart';
import '../domain/daily_entry_model.dart';

class DailyEntrySaveResult {
  final bool isOffline;
  final DailyEntry entry;

  const DailyEntrySaveResult({required this.isOffline, required this.entry});
}

class DailyEntryRepository {
  final SupabaseClient? _client;

  DailyEntryRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  String _cacheKey(String userId) => 'pandafit_cached_entries_$userId';
  String _pendingKey(String userId) => 'pandafit_pending_entries_$userId';

  Future<List<DailyEntry>> fetchRecentEntries(String userId, {int limit = 30}) async {
    // 1. Try fetching from Supabase online
    if (_client != null) {
      try {
        final res = await _client
            .from('daily_entries')
            .select()
            .eq('user_id', userId)
            .order('entry_date', ascending: false)
            .limit(limit);

        final onlineEntries = (res as List<dynamic>)
            .map((e) => DailyEntry.fromJson(e as Map<String, dynamic>))
            .toList();

        // Check and sync any pending offline entries
        await _syncPendingEntries(userId);

        // Update local cache
        await _saveToCache(userId, onlineEntries);

        return onlineEntries;
      } catch (e) {
        debugPrint('Supabase fetch failed (falling back to offline cache): $e');
      }
    }

    // 2. Fallback: Load from local SharedPreferences cache
    return await _loadFromCache(userId);
  }

  Future<DailyEntry?> fetchEntryByDate(String userId, DateTime date) async {
    final entries = await fetchRecentEntries(userId);
    return entries.where((e) {
      return e.entryDate.year == date.year &&
          e.entryDate.month == date.month &&
          e.entryDate.day == date.day;
    }).firstOrNull;
  }

  Future<DailyEntrySaveResult> saveDailyEntry(DailyEntry entry, {List<DailyEntry>? existingEntries}) async {
    final weightsMap = <DateTime, double>{};

    final entriesPool = existingEntries ?? await _loadFromCache(entry.userId);
    if (entriesPool.isNotEmpty) {
      final windowStart = entry.entryDate.subtract(const Duration(days: 6));
      for (final e in entriesPool) {
        if (e.entryDate.isAfter(windowStart.subtract(const Duration(seconds: 1))) &&
            e.entryDate.isBefore(entry.entryDate.add(const Duration(days: 1)))) {
          if (e.weight != null) {
            weightsMap[e.entryDate] = e.weight!;
          }
        }
      }
    }

    if (entry.weight != null) {
      weightsMap[entry.entryDate] = entry.weight!;
    }

    final calculatedMA = CalculationEngine.calculate7DayMovingAverage(
      targetDate: entry.entryDate,
      dailyWeights: weightsMap,
    );

    final entryWithMA = DailyEntry(
      id: entry.id,
      userId: entry.userId,
      entryDate: entry.entryDate,
      weight: entry.weight,
      rollingAvg7Days: calculatedMA,
      swimming: entry.swimming,
      planFollowed: entry.planFollowed,
      caloriesIn: entry.caloriesIn,
      caloriesOut: entry.caloriesOut,
      netCalories: entry.netCalories,
      selectedDinner: entry.selectedDinner,
      notes: entry.notes,
      createdAt: entry.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    // Save to local cache immediately so UI updates instantly
    await _upsertInCache(entry.userId, entryWithMA);

    // Attempt online sync to Supabase
    bool isOffline = true;
    if (_client != null) {
      try {
        final payload = entryWithMA.toJson();
        payload['rolling_avg_7days'] = calculatedMA;

        await _client.from('daily_entries').upsert(
              payload,
              onConflict: 'user_id, entry_date',
            );
        isOffline = false;
      } catch (e) {
        debugPrint('Supabase upsert failed (saving to offline sync queue): $e');
        isOffline = true;
      }
    }

    if (isOffline) {
      await _addToPendingQueue(entry.userId, entryWithMA);
    }

    return DailyEntrySaveResult(isOffline: isOffline, entry: entryWithMA);
  }

  Future<void> _saveToCache(String userId, List<DailyEntry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = entries.map((e) => e.toJson()).toList();
      await prefs.setString(_cacheKey(userId), jsonEncode(list));
    } catch (_) {}
  }

  Future<List<DailyEntry>> _loadFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey(userId));
      if (str == null || str.isEmpty) return [];
      final List<dynamic> decoded = jsonDecode(str) as List<dynamic>;
      final list = decoded
          .map((e) => DailyEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.entryDate.compareTo(a.entryDate));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _upsertInCache(String userId, DailyEntry entry) async {
    final cached = await _loadFromCache(userId);
    final idx = cached.indexWhere(
      (e) =>
          e.entryDate.year == entry.entryDate.year &&
          e.entryDate.month == entry.entryDate.month &&
          e.entryDate.day == entry.entryDate.day,
    );

    if (idx >= 0) {
      cached[idx] = entry;
    } else {
      cached.insert(0, entry);
    }
    await _saveToCache(userId, cached);
  }

  Future<void> _addToPendingQueue(String userId, DailyEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_pendingKey(userId));
      final List<dynamic> list =
          str != null && str.isNotEmpty ? jsonDecode(str) as List<dynamic> : [];
      final dateKey = entry.entryDate.toIso8601String().split('T').first;
      final idx = list.indexWhere(
        (e) => e['entry_date'] == dateKey,
      );
      if (idx >= 0) {
        list[idx] = entry.toJson();
      } else {
        list.add(entry.toJson());
      }
      await prefs.setString(_pendingKey(userId), jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _syncPendingEntries(String userId) async {
    if (_client == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_pendingKey(userId));
      if (str == null || str.isEmpty) return;
      final List<dynamic> list = jsonDecode(str) as List<dynamic>;
      if (list.isEmpty) return;

      for (final item in list) {
        final payload = item as Map<String, dynamic>;
        await _client.from('daily_entries').upsert(
              payload,
              onConflict: 'user_id, entry_date',
            );
      }
      // Successfully synced all pending items, clear queue
      await prefs.remove(_pendingKey(userId));
      debugPrint('Successfully synced ${list.length} pending offline entries to Supabase.');
    } catch (e) {
      debugPrint('Pending sync failed, will retry next fetch: $e');
    }
  }
}
