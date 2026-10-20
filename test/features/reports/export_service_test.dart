import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:panda_fit/features/daily_logger/domain/daily_entry_model.dart';
import 'package:panda_fit/features/missions/domain/mission_model.dart';
import 'package:panda_fit/features/profile/domain/profile_model.dart';
import 'package:panda_fit/features/reports/data/export_service.dart';
import 'package:panda_fit/features/reports/domain/health_report_summary.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ro', null);
  });

  group('ExportService & HealthReportSummary Tests', () {
    final mockProfile = UserProfile(
      id: 'test-user-uuid-1234',
      username: 'pandafan',
      firstName: 'Alex',
      lastName: 'Popescu',
      sex: 'MALE',
      birthDate: DateTime(1995, 6, 15),
      heightCm: 182.0,
      profileStartWeight: 102.5,
      dailyTargetCalories: 2200,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final mockMission = Mission(
      id: 'mission-uuid-1',
      userId: 'test-user-uuid-1234',
      missionType: MissionType.cutting,
      missionStartWeight: 102.5,
      targetWeight: 94.0,
      status: MissionStatus.active,
      startedAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final List<DailyEntry> mockEntries = [
      DailyEntry(
        id: 'entry-1',
        userId: 'test-user-uuid-1234',
        entryDate: today,
        weight: 98.2,
        rollingAvg7Days: 98.5,
        swimming: true,
        planFollowed: true,
        caloriesIn: 2150,
        caloriesOut: 450,
        netCalories: 1700,
        selectedDinner: 'A',
        notes: 'Zi excelenta cu "inot intens"',
        createdAt: today,
        updatedAt: today,
      ),
      DailyEntry(
        id: 'entry-2',
        userId: 'test-user-uuid-1234',
        entryDate: yesterday,
        weight: 98.6,
        rollingAvg7Days: 98.8,
        swimming: false,
        planFollowed: true,
        caloriesIn: 2200,
        caloriesOut: 200,
        netCalories: 2000,
        selectedDinner: 'B',
        notes: 'Mers pe jos',
        createdAt: yesterday,
        updatedAt: yesterday,
      ),
      DailyEntry(
        id: 'entry-3',
        userId: 'test-user-uuid-1234',
        entryDate: twoDaysAgo,
        weight: 99.0,
        rollingAvg7Days: 99.0,
        swimming: false,
        planFollowed: false,
        caloriesIn: 2600,
        caloriesOut: 0,
        netCalories: 2600,
        selectedDinner: 'CUSTOM',
        notes: 'Prajitura aniversare',
        createdAt: twoDaysAgo,
        updatedAt: twoDaysAgo,
      ),
    ];

    test('HealthReportSummary.fromData builds analytical KPIs properly', () {
      final summary = HealthReportSummary.fromData(
        profile: mockProfile,
        entries: mockEntries,
        activeMission: mockMission,
      );

      expect(summary.totalEntriesLogged, 3);
      expect(summary.startWeight, 102.5);
      expect(summary.currentWeight, 98.2);
      expect(summary.lowestWeight, 98.2);
      expect(summary.highestWeight, 99.0);
      expect(summary.totalDelta, -4.3);
      expect(summary.currentMovingAvg, 98.5);
      expect(summary.bmr, greaterThan(1500));
      expect(summary.maintenanceTdee, greaterThan(summary.bmr));
      expect(summary.bmi, greaterThan(20.0));
      expect(summary.streakDays, greaterThanOrEqualTo(1));
    });

    test('generateCsv creates UTF-8 BOM, headers, and properly formatted rows', () {
      final summary = HealthReportSummary.fromData(
        profile: mockProfile,
        entries: mockEntries,
        activeMission: mockMission,
      );

      final csv = ExportService.generateCsv(summary);

      // Check UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);
      // Check Metadata comments
      expect(csv.contains('# PANDAFIT DATA EXPORT'), isTrue);
      expect(csv.contains('Alex Popescu'), isTrue);
      expect(csv.contains('pandafan'), isTrue);
      // Check column header
      expect(csv.contains('Data,Ziua,Greutate (kg),Medie 7 Zile (kg)'), isTrue);
      // Check row contents
      expect(csv.contains('98.2'), isTrue);
      expect(csv.contains('1700'), isTrue);
      // Check quotes escaping in notes
      expect(csv.contains('""inot intens""'), isTrue);
    });

    test('generateJsonBackup creates valid, parseable JSON with all fields', () {
      final summary = HealthReportSummary.fromData(
        profile: mockProfile,
        entries: mockEntries,
        activeMission: mockMission,
      );

      final jsonString = ExportService.generateJsonBackup(summary);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['app'], 'PandaFit');
      expect(decoded['version'], '1.0.0');
      expect(decoded['profile']['username'], 'pandafan');
      expect(decoded['active_mission']['target_weight'], 94.0);
      expect(decoded['entries_count'], 3);
      expect((decoded['entries'] as List).length, 3);
      expect(decoded['summary_kpis']['start_weight_kg'], 102.5);
      expect(decoded['summary_kpis']['total_delta_kg'], -4.3);
    });

    test('generatePdfReport generates non-empty PDF bytes starting with %PDF', () async {
      final summary = HealthReportSummary.fromData(
        profile: mockProfile,
        entries: mockEntries,
        activeMission: mockMission,
      );

      final pdfBytes = await ExportService.generatePdfReport(summary);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
      // PDF specification magic header: %PDF-
      final header = utf8.decode(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });
}
