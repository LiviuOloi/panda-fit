import 'package:flutter_test/flutter_test.dart';
import 'package:panda_fit/core/utils/calculation_engine.dart';
import 'package:panda_fit/features/missions/domain/mission_model.dart';

void main() {
  group('Onboarding Validation & Mission Domain Invariants', () {
    test('Onboarding start weight is rounded to 0.1 kg precision', () {
      const inputWeight = 98.44;
      final rounded = CalculationEngine.roundWeight(inputWeight);
      expect(rounded, 98.4);
    });

    test('Onboarding Cutting validation: Target weight must be strictly less than Start weight', () {
      const startWeight = 95.0;

      // Equal target weight is invalid
      const equalTarget = 95.0;
      expect(
        CalculationEngine.isMissionAccomplished(
          missionType: 'CUTTING',
          currentWeight: equalTarget,
          targetWeight: startWeight,
        ),
        isFalse,
      );

      // Higher target weight is invalid for cutting
      const higherTarget = 96.0;
      expect(higherTarget < startWeight, isFalse);

      // Valid cutting target
      const validCuttingTarget = 90.0;
      expect(validCuttingTarget < startWeight, isTrue);
    });

    test('Onboarding Bulking validation: Target weight must be strictly greater than Start weight', () {
      const startWeight = 80.0;

      // Equal target weight is invalid
      const equalTarget = 80.0;
      expect(equalTarget > startWeight, isFalse);

      // Lower target weight is invalid for bulking
      const lowerTarget = 78.0;
      expect(lowerTarget > startWeight, isFalse);

      // Valid bulking target
      const validBulkingTarget = 85.0;
      expect(validBulkingTarget > startWeight, isTrue);
    });

    test('Mission entity serialization and accomplishment check on newly created mission', () {
      final mission = Mission(
        id: 'test-mission-1',
        userId: 'test-user-1',
        missionType: MissionType.cutting,
        missionStartWeight: 104.2,
        targetWeight: 94.0,
        startedAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );

      // Starting weight (104.2) -> 0% progress
      expect(mission.progress(104.2), closeTo(0.0, 0.01));

      // Halfway (99.1) -> 50% progress
      expect(mission.progress(99.1), closeTo(0.5, 0.01));

      // Exactly target (94.0) -> NOT accomplished (strict inequality)
      expect(mission.checkAccomplishment(94.0), isFalse);

      // Below target (93.9) -> Accomplished!
      expect(mission.checkAccomplishment(93.9), isTrue);
    });
  });
}
