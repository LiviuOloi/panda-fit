import 'package:flutter_test/flutter_test.dart';
import 'package:panda_fit/core/utils/calculation_engine.dart';

void main() {
  group('CalculationEngine Unit Tests & Domain Invariants', () {
    test('Weight precision rounding strictly maintains 0.1 kg precision', () {
      expect(CalculationEngine.roundWeight(102.44), 102.4);
      expect(CalculationEngine.roundWeight(102.45), 102.5);
      expect(CalculationEngine.roundWeight(98.11), 98.1);
      expect(CalculationEngine.roundWeight(98.19), 98.2);
    });

    test('Age calculation correctly handles birthdays before and after current date', () {
      final refDate = DateTime(2026, 10, 4);
      
      // Birthday already happened this year
      final bdayPast = DateTime(1994, 6, 15);
      expect(CalculationEngine.calculateAge(bdayPast, refDate), 32);

      // Birthday has not happened yet this year
      final bdayFuture = DateTime(1994, 11, 20);
      expect(CalculationEngine.calculateAge(bdayFuture, refDate), 31);
    });

    test('7-Day Rolling Moving Average with partial days (< 7 days)', () {
      final targetDate = DateTime(2026, 10, 7);
      final dailyWeights = {
        DateTime(2026, 10, 5): 100.0,
        DateTime(2026, 10, 6): 99.0,
        DateTime(2026, 10, 7): 98.0,
      };

      // (100.0 + 99.0 + 98.0) / 3 = 99.0
      final ma = CalculationEngine.calculate7DayMovingAverage(
        targetDate: targetDate,
        dailyWeights: dailyWeights,
      );
      expect(ma, 99.0);
    });

    test('7-Day Rolling Moving Average with missing middle dates and exactly 7-day window', () {
      final targetDate = DateTime(2026, 10, 10);
      final dailyWeights = {
        // Outside 7-day window (target - 6 is Oct 4):
        DateTime(2026, 10, 2): 105.0, // should be excluded
        DateTime(2026, 10, 3): 104.0, // should be excluded
        // Inside 7-day window [Oct 4 .. Oct 10]:
        DateTime(2026, 10, 4): 100.0,
        DateTime(2026, 10, 6): 99.0,
        DateTime(2026, 10, 10): 98.0,
      };

      // Average of 100.0, 99.0, 98.0 = 99.0
      final ma = CalculationEngine.calculate7DayMovingAverage(
        targetDate: targetDate,
        dailyWeights: dailyWeights,
      );
      expect(ma, 99.0);
    });

    test('Total Delta calculation', () {
      expect(
        CalculationEngine.calculateTotalDelta(currentWeight: 98.4, profileStartWeight: 104.2),
        -5.8,
      );
      expect(
        CalculationEngine.calculateTotalDelta(currentWeight: 106.0, profileStartWeight: 104.0),
        2.0,
      );
    });

    test('Cutting Mission: Strict inequality invariant (< target)', () {
      const target = 95.0;

      // 95.1 kg -> Active (Not accomplished)
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'CUTTING',
          currentWeight: 95.1,
          targetWeight: target,
        ),
        isFalse,
      );

      // 95.0 kg -> Active (Tying the target is NOT accomplished)
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'CUTTING',
          currentWeight: 95.0,
          targetWeight: target,
        ),
        isFalse,
      );

      // 94.9 kg -> Accomplished! (Strict inequality satisfied)
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'CUTTING',
          currentWeight: 94.9,
          targetWeight: target,
        ),
        isTrue,
      );
    });

    test('Bulking Mission: Strict inequality invariant (> target)', () {
      const target = 100.0;

      // 99.9 kg -> Active (Not accomplished)
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'BULKING',
          currentWeight: 99.9,
          targetWeight: target,
        ),
        isFalse,
      );

      // 100.0 kg -> Active (Tying target is NOT accomplished)
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'BULKING',
          currentWeight: 100.0,
          targetWeight: target,
        ),
        isFalse,
      );

      // 100.1 kg -> Accomplished! (Strict inequality satisfied)
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'BULKING',
          currentWeight: 100.1,
          targetWeight: target,
        ),
        isTrue,
      );
    });
  });
}
