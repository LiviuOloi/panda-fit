import '../../../../core/utils/calculation_engine.dart';

enum MissionType { cutting, bulking }
enum MissionStatus { active, accomplished, abandoned }

class Mission {
  final String id;
  final String userId;
  final MissionType missionType;
  final double missionStartWeight;
  final double targetWeight;
  final MissionStatus status;
  final DateTime startedAt;
  final DateTime? achievedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Mission({
    required this.id,
    required this.userId,
    required this.missionType,
    required this.missionStartWeight,
    required this.targetWeight,
    this.status = MissionStatus.active,
    required this.startedAt,
    this.achievedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check whether the mission is accomplished given current morning weight
  /// Enforces STRICT INEQUALITY invariant from AGENTS.md
  bool checkAccomplishment(double currentWeight) {
    return CalculationEngine.isMissionAccomplished(
      missionType: missionType == MissionType.cutting ? 'CUTTING' : 'BULKING',
      currentWeight: currentWeight,
      targetWeight: targetWeight,
    );
  }

  /// Calculates progress ratio (0.0 to 1.0)
  double progress(double currentWeight) {
    return CalculationEngine.calculateMissionProgress(
      missionType: missionType == MissionType.cutting ? 'CUTTING' : 'BULKING',
      startWeight: missionStartWeight,
      targetWeight: targetWeight,
      currentWeight: currentWeight,
    );
  }

  factory Mission.fromJson(Map<String, dynamic> json) {
    final typeStr = json['mission_type'] as String;
    final statusStr = json['status'] as String;

    return Mission(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      missionType: typeStr == 'CUTTING' ? MissionType.cutting : MissionType.bulking,
      missionStartWeight: (json['mission_start_weight'] as num).toDouble(),
      targetWeight: (json['target_weight'] as num).toDouble(),
      status: statusStr == 'ACCOMPLISHED'
          ? MissionStatus.accomplished
          : statusStr == 'ABANDONED'
              ? MissionStatus.abandoned
              : MissionStatus.active,
      startedAt: DateTime.parse(json['started_at'] as String),
      achievedAt: json['achieved_at'] != null ? DateTime.parse(json['achieved_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'mission_type': missionType == MissionType.cutting ? 'CUTTING' : 'BULKING',
      'mission_start_weight': missionStartWeight,
      'target_weight': targetWeight,
      'status': status.name.toUpperCase(),
      'started_at': startedAt.toIso8601String(),
      'achieved_at': achievedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty && id != userId) {
      map['id'] = id;
    }
    return map;
  }
}
