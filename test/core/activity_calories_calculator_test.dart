import 'package:flutter_test/flutter_test.dart';
import 'package:panda_fit/core/utils/activity_calories_calculator.dart';

void main() {
  group('PhysicalActivityType & Pessimistic Calorie Burn Calculations', () {
    test('Pessimistic formula accurately discounts MET for weightlifting', () {
      // 100 kg user, 45 minutes, Weightlifting (pessimistic MET 3.5)
      // Burn = 0.85 * 3.5 * 100 * (45 / 60) = 223.125 -> 223 kcal
      final burned = PhysicalActivityType.weightlifting.calculateBurn(
        weightKg: 100.0,
        durationMinutes: 45,
      );
      expect(burned, 223);
    });

    test('Swimming correctly identifies swimming flag and computes burn', () {
      expect(PhysicalActivityType.swimming.isSwimming, isTrue);
      expect(PhysicalActivityType.running.isSwimming, isFalse);

      // 80 kg user, 60 minutes, Swimming (pessimistic MET 5.0)
      // Burn = 0.85 * 5.0 * 80 * (60 / 60) = 340 kcal
      final burned = PhysicalActivityType.swimming.calculateBurn(
        weightKg: 80.0,
        durationMinutes: 60,
      );
      expect(burned, 340);
    });

    test('Zero or negative duration/weight returns 0', () {
      expect(PhysicalActivityType.running.calculateBurn(weightKg: 0, durationMinutes: 30), 0);
      expect(PhysicalActivityType.running.calculateBurn(weightKg: 80, durationMinutes: 0), 0);
      expect(PhysicalActivityType.running.calculateBurn(weightKg: -10, durationMinutes: 30), 0);
    });

    test('LoggedActivity properly toggles between duration mode and direct custom calories', () {
      final item = LoggedActivity(
        id: 'test-1',
        activityType: PhysicalActivityType.running,
        durationMinutes: 30,
        isDurationMode: true,
      );

      // 80 kg, 30 min running (pessimistic MET 7.0)
      // 0.85 * 7.0 * 80 * 0.5 = 238 kcal
      expect(item.getCalories(80.0), 238);

      // Switch to direct custom calories (e.g. from chest strap monitor)
      item.isDurationMode = false;
      item.customCalories = 290;
      expect(item.getCalories(80.0), 290);
    });
  });
}
