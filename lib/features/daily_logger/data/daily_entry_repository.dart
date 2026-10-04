import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/utils/calculation_engine.dart';
import '../domain/daily_entry_model.dart';

class DailyEntryRepository {
  final SupabaseClient? _client;

  DailyEntryRepository([SupabaseClient? client])
      : _client = client ?? SupabaseService.client;

  Future<List<DailyEntry>> fetchRecentEntries(String userId, {int limit = 30}) async {
    if (_client == null) return [];
    final res = await _client
        .from('daily_entries')
        .select()
        .eq('user_id', userId)
        .order('entry_date', ascending: false)
        .limit(limit);

    return (res as List<dynamic>)
        .map((e) => DailyEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDailyEntry(DailyEntry entry, {List<DailyEntry>? existingEntries}) async {
    if (_client == null) return;

    final weightsMap = <DateTime, double>{};

    if (existingEntries != null && existingEntries.isNotEmpty) {
      // Use existing in-memory entries to compute 7-day moving average instantly
      final windowStart = entry.entryDate.subtract(const Duration(days: 6));
      for (final e in existingEntries) {
        if (e.entryDate.isAfter(windowStart.subtract(const Duration(seconds: 1))) &&
            e.entryDate.isBefore(entry.entryDate.add(const Duration(days: 1)))) {
          if (e.weight != null) {
            weightsMap[e.entryDate] = e.weight!;
          }
        }
      }
    } else {
      // Fallback: Fetch the past 7 days from Supabase
      final windowStart = entry.entryDate.subtract(const Duration(days: 6));
      final pastEntriesRes = await _client
          .from('daily_entries')
          .select('entry_date, weight')
          .eq('user_id', entry.userId)
          .gte('entry_date', windowStart.toIso8601String().split('T').first)
          .lte('entry_date', entry.entryDate.toIso8601String().split('T').first);

      for (final row in pastEntriesRes as List<dynamic>) {
        final date = DateTime.parse(row['entry_date'] as String);
        final w = (row['weight'] as num?)?.toDouble();
        if (w != null) {
          weightsMap[date] = w;
        }
      }
    }

    // Add current entry's weight to calculation if present
    if (entry.weight != null) {
      weightsMap[entry.entryDate] = entry.weight!;
    }

    final calculatedMA = CalculationEngine.calculate7DayMovingAverage(
      targetDate: entry.entryDate,
      dailyWeights: weightsMap,
    );

    final payload = entry.toJson();
    payload['rolling_avg_7days'] = calculatedMA;

    await _client.from('daily_entries').upsert(
          payload,
          onConflict: 'user_id, entry_date',
        );
  }
}
