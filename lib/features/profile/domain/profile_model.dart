import '../../../../core/utils/calculation_engine.dart';

class UserProfile {
  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String sex; // 'MALE', 'FEMALE', 'OTHER'
  final DateTime birthDate;
  final double heightCm;
  final double profileStartWeight; // READ-ONLY once daily entries > 0
  final int dailyTargetCalories;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.profileStartWeight,
    this.dailyTargetCalories = 2300,
    required this.createdAt,
    required this.updatedAt,
  });

  int get age => CalculationEngine.calculateAge(birthDate);

  String get fullName => '$firstName $lastName';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      sex: json['sex'] as String,
      birthDate: DateTime.parse(json['birth_date'] as String),
      heightCm: (json['height_cm'] as num).toDouble(),
      profileStartWeight: (json['profile_start_weight'] as num).toDouble(),
      dailyTargetCalories: (json['daily_target_calories'] as num?)?.toInt() ?? 2300,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'sex': sex,
      'birth_date': birthDate.toIso8601String().split('T').first,
      'height_cm': heightCm,
      'profile_start_weight': profileStartWeight,
      'daily_target_calories': dailyTargetCalories,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
