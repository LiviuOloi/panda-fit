class DailyEntry {
  final String id;
  final String userId;
  final DateTime entryDate;
  final double? weight;
  final double? rollingAvg7Days;
  final bool swimming;
  final bool planFollowed;
  final int? caloriesIn;
  final int? caloriesOut;
  final int netCalories;
  final String? selectedDinner; // 'A', 'B', 'C', 'CUSTOM', 'NONE'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyEntry({
    required this.id,
    required this.userId,
    required this.entryDate,
    this.weight,
    this.rollingAvg7Days,
    this.swimming = false,
    this.planFollowed = true,
    this.caloriesIn,
    this.caloriesOut,
    required this.netCalories,
    this.selectedDinner,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyEntry.fromJson(Map<String, dynamic> json) {
    final calIn = (json['calories_in'] as num?)?.toInt() ?? 0;
    final calOut = (json['calories_out'] as num?)?.toInt() ?? 0;
    return DailyEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      weight: (json['weight'] as num?)?.toDouble(),
      rollingAvg7Days: (json['rolling_avg_7days'] as num?)?.toDouble(),
      swimming: json['swimming'] as bool? ?? false,
      planFollowed: json['plan_followed'] as bool? ?? true,
      caloriesIn: json['calories_in'] != null ? calIn : null,
      caloriesOut: json['calories_out'] != null ? calOut : null,
      netCalories: (json['net_calories'] as num?)?.toInt() ?? (calIn - calOut),
      selectedDinner: json['selected_dinner'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'entry_date': entryDate.toIso8601String().split('T').first,
      'weight': weight,
      'rolling_avg_7days': rollingAvg7Days,
      'swimming': swimming,
      'plan_followed': planFollowed,
      'calories_in': caloriesIn,
      'calories_out': caloriesOut,
      'selected_dinner': selectedDinner,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
