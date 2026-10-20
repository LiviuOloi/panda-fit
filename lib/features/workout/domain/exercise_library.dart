import 'exercise_model.dart';

class ExerciseLibrary {
  ExerciseLibrary._();

  static const List<ExerciseInfo> allExercises = [
    // PIEPT (Chest)
    ExerciseInfo(
      id: 'chest_bench_press',
      nameRo: 'Împins cu Bara din Culcat',
      nameEn: 'Barbell Bench Press',
      muscleGroup: MuscleGroup.chest,
      equipment: 'Bară & Bancă',
    ),
    ExerciseInfo(
      id: 'chest_incline_db_press',
      nameRo: 'Împins cu Gantere din Plan Înclinat',
      nameEn: 'Incline Dumbbell Press',
      muscleGroup: MuscleGroup.chest,
      equipment: 'Gantere & Bancă Înclinată',
    ),
    ExerciseInfo(
      id: 'chest_dips',
      nameRo: 'Flotări la Paralele (Dips)',
      nameEn: 'Chest Dips',
      muscleGroup: MuscleGroup.chest,
      equipment: 'Bare Paralele / Greutate Corporală',
    ),
    ExerciseInfo(
      id: 'chest_cable_fly',
      nameRo: 'Fluturări la Cabluri',
      nameEn: 'Cable Flyes / Crossover',
      muscleGroup: MuscleGroup.chest,
      equipment: 'Scripete Cabluri',
    ),
    ExerciseInfo(
      id: 'chest_pushups',
      nameRo: 'Flotări Clasice',
      nameEn: 'Push-ups',
      muscleGroup: MuscleGroup.chest,
      equipment: 'Greutate Corporală',
    ),
    ExerciseInfo(
      id: 'chest_machine_press',
      nameRo: 'Împins la Aparat (Chest Press)',
      nameEn: 'Machine Chest Press',
      muscleGroup: MuscleGroup.chest,
      equipment: 'Aparat',
    ),

    // SPATE (Back)
    ExerciseInfo(
      id: 'back_deadlift',
      nameRo: 'Îndreptări cu Bara',
      nameEn: 'Barbell Conventional Deadlift',
      muscleGroup: MuscleGroup.back,
      equipment: 'Bară Olimpică',
    ),
    ExerciseInfo(
      id: 'back_pullups',
      nameRo: 'Tracțiuni la Bară (Priză Pronație / Supinație)',
      nameEn: 'Pull-ups / Chin-ups',
      muscleGroup: MuscleGroup.back,
      equipment: 'Bară de Tracțiuni',
    ),
    ExerciseInfo(
      id: 'back_lat_pulldown',
      nameRo: 'Tracțiuni la Scripete (Lat Pulldown)',
      nameEn: 'Lat Pulldown',
      muscleGroup: MuscleGroup.back,
      equipment: 'Scripete Vertical',
    ),
    ExerciseInfo(
      id: 'back_barbell_row',
      nameRo: 'Ramat cu Bara din Aplecat',
      nameEn: 'Barbell Bent-Over Row',
      muscleGroup: MuscleGroup.back,
      equipment: 'Bară Olimpică',
    ),
    ExerciseInfo(
      id: 'back_cable_row',
      nameRo: 'Ramat la Cablu Orizontal',
      nameEn: 'Seated Cable Row',
      muscleGroup: MuscleGroup.back,
      equipment: 'Scripete Orizontal',
    ),
    ExerciseInfo(
      id: 'back_db_row',
      nameRo: 'Ramat cu Gantera pe un Braț',
      nameEn: 'One-Arm Dumbbell Row',
      muscleGroup: MuscleGroup.back,
      equipment: 'Ganteră & Bancă',
    ),
    ExerciseInfo(
      id: 'back_hyperextension',
      nameRo: 'Hiperextensii Lombare',
      nameEn: 'Back Hyperextensions',
      muscleGroup: MuscleGroup.back,
      equipment: 'Bancă Romană',
    ),

    // PICIOARE (Legs)
    ExerciseInfo(
      id: 'legs_squat',
      nameRo: 'Genuflexiuni cu Bara pe Spate',
      nameEn: 'Barbell Back Squat',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Bară & Squat Rack',
    ),
    ExerciseInfo(
      id: 'legs_leg_press',
      nameRo: 'Presa de Picioare (Leg Press)',
      nameEn: '45° Leg Press',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Aparat Presă',
    ),
    ExerciseInfo(
      id: 'legs_romanian_deadlift',
      nameRo: 'Îndreptări Românești (RDL)',
      nameEn: 'Romanian Deadlift (RDL)',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Bară / Gantere',
    ),
    ExerciseInfo(
      id: 'legs_lunges',
      nameRo: 'Fandări Pășite cu Gantere',
      nameEn: 'Walking Dumbbell Lunges',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Gantere',
    ),
    ExerciseInfo(
      id: 'legs_leg_extension',
      nameRo: 'Extensii Picioare la Aparat',
      nameEn: 'Leg Extensions',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Aparat Cvadricepși',
    ),
    ExerciseInfo(
      id: 'legs_leg_curl',
      nameRo: 'Flexii Picioare din Culcat / Șezut',
      nameEn: 'Lying / Seated Leg Curls',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Aparat Ischiogambieri',
    ),
    ExerciseInfo(
      id: 'legs_calf_raise',
      nameRo: 'Ridicări pe Vârfuri pentru Gambe',
      nameEn: 'Standing / Seated Calf Raises',
      muscleGroup: MuscleGroup.legs,
      equipment: 'Aparat Gambe / Treaptă',
    ),

    // UMERI (Shoulders)
    ExerciseInfo(
      id: 'shoulders_ohp',
      nameRo: 'Împins Deasupra Capului cu Bara (OHP)',
      nameEn: 'Overhead Press (OHP)',
      muscleGroup: MuscleGroup.shoulders,
      equipment: 'Bară Olimpică',
    ),
    ExerciseInfo(
      id: 'shoulders_db_press',
      nameRo: 'Împins cu Gantere din Șezut',
      nameEn: 'Seated Dumbbell Shoulder Press',
      muscleGroup: MuscleGroup.shoulders,
      equipment: 'Gantere & Bancă',
    ),
    ExerciseInfo(
      id: 'shoulders_lateral_raise',
      nameRo: 'Ridicări Laterale cu Gantere',
      nameEn: 'Dumbbell Lateral Raises',
      muscleGroup: MuscleGroup.shoulders,
      equipment: 'Gantere',
    ),
    ExerciseInfo(
      id: 'shoulders_face_pull',
      nameRo: 'Face Pulls la Scripete',
      nameEn: 'Face Pulls (Deltoid Posterior)',
      muscleGroup: MuscleGroup.shoulders,
      equipment: 'Scripete & Frânghie',
    ),
    ExerciseInfo(
      id: 'shoulders_rear_delt_fly',
      nameRo: 'Fluturări Inversate la Aparat / Gantere',
      nameEn: 'Rear Delt Flyes / Reverse Pec Deck',
      muscleGroup: MuscleGroup.shoulders,
      equipment: 'Aparat / Gantere',
    ),

    // BRATE (Arms)
    ExerciseInfo(
      id: 'arms_bicep_curl_barbell',
      nameRo: 'Flexii Biceps cu Bara Dreaptă / Z',
      nameEn: 'Barbell / EZ-Bar Bicep Curl',
      muscleGroup: MuscleGroup.arms,
      equipment: 'Bară Z / Olimpică',
    ),
    ExerciseInfo(
      id: 'arms_bicep_hammer_curl',
      nameRo: 'Flexii Ciocan cu Gantere (Hammer Curls)',
      nameEn: 'Dumbbell Hammer Curls',
      muscleGroup: MuscleGroup.arms,
      equipment: 'Gantere',
    ),
    ExerciseInfo(
      id: 'arms_cable_curl',
      nameRo: 'Flexii Biceps la Scripete',
      nameEn: 'Cable Bicep Curls',
      muscleGroup: MuscleGroup.arms,
      equipment: 'Scripete Jos',
    ),
    ExerciseInfo(
      id: 'arms_tricep_pushdown',
      nameRo: 'Extensii Triceps la Scripete cu Frânghia',
      nameEn: 'Cable Tricep Rope Pushdown',
      muscleGroup: MuscleGroup.arms,
      equipment: 'Scripete & Frânghie',
    ),
    ExerciseInfo(
      id: 'arms_skull_crushers',
      nameRo: 'Extensii Triceps din Culcat (Skull Crushers)',
      nameEn: 'Lying Triceps Extension (Skull Crushers)',
      muscleGroup: MuscleGroup.arms,
      equipment: 'Bară Z & Bancă',
    ),

    // ABDOMEN / CORE
    ExerciseInfo(
      id: 'core_hanging_leg_raise',
      nameRo: 'Ridicări de Picioare din Atârnat la Bară',
      nameEn: 'Hanging Leg Raises',
      muscleGroup: MuscleGroup.core,
      equipment: 'Bară de Tracțiuni',
    ),
    ExerciseInfo(
      id: 'core_cable_crunch',
      nameRo: 'Crunch la Scripete din Îngenuncheat',
      nameEn: 'Kneeling Cable Crunch',
      muscleGroup: MuscleGroup.core,
      equipment: 'Scripete & Frânghie',
    ),
    ExerciseInfo(
      id: 'core_plank',
      nameRo: 'Plank Izometric',
      nameEn: 'Forearm Plank',
      muscleGroup: MuscleGroup.core,
      equipment: 'Saltea / Greutate Corporală',
    ),

    // CARDIO & SWIMMING
    ExerciseInfo(
      id: 'cardio_treadmill',
      nameRo: 'Alergare pe Bandă / Panta',
      nameEn: 'Incline Treadmill Run / Walk',
      muscleGroup: MuscleGroup.cardio,
      equipment: 'Bandă de Alergat',
    ),
    ExerciseInfo(
      id: 'cardio_swimming',
      nameRo: 'Înot Bazin (Laps)',
      nameEn: 'Swimming Laps',
      muscleGroup: MuscleGroup.cardio,
      equipment: 'Bazin de Înot',
    ),
    ExerciseInfo(
      id: 'cardio_stationary_bike',
      nameRo: 'Bicicletă Staționară',
      nameEn: 'Stationary Cycling',
      muscleGroup: MuscleGroup.cardio,
      equipment: 'Bicicletă',
    ),

    // FULL BODY & FUNCTIONAL
    ExerciseInfo(
      id: 'fullbody_burpees',
      nameRo: 'Burpees Complete',
      nameEn: 'Full Body Burpees',
      muscleGroup: MuscleGroup.fullBody,
      equipment: 'Greutate Corporală',
    ),
    ExerciseInfo(
      id: 'fullbody_kb_swing',
      nameRo: 'Balansări cu Kettlebell (KB Swings)',
      nameEn: 'Kettlebell Swings',
      muscleGroup: MuscleGroup.fullBody,
      equipment: 'Kettlebell',
    ),
    ExerciseInfo(
      id: 'fullbody_thrusters',
      nameRo: 'Thrusters (Genuflexiune cu Împins)',
      nameEn: 'Dumbbell / Barbell Thrusters',
      muscleGroup: MuscleGroup.fullBody,
      equipment: 'Gantere / Bară',
    ),
  ];

  /// Find exercise by ID
  static ExerciseInfo? findById(String id) {
    try {
      return allExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Preset routine templates
  static List<WorkoutTemplate> get presetTemplates => const [
        WorkoutTemplate(
          id: 'template_push',
          name: 'Push Day (Piept, Umeri, Triceps)',
          split: WorkoutSplit.push,
          description: 'Focus pe mușchii de împingere: piept, deltoizi anteriori/laterali și triceps.',
          exerciseIds: [
            'chest_bench_press',
            'chest_incline_db_press',
            'shoulders_db_press',
            'shoulders_lateral_raise',
            'arms_tricep_pushdown',
          ],
        ),
        WorkoutTemplate(
          id: 'template_pull',
          name: 'Pull Day (Spate & Biceps)',
          split: WorkoutSplit.pull,
          description: 'Focus pe mușchii de tragere: dorsal, trapez, deltoid posterior și biceps.',
          exerciseIds: [
            'back_pullups',
            'back_barbell_row',
            'back_cable_row',
            'shoulders_face_pull',
            'arms_bicep_hammer_curl',
          ],
        ),
        WorkoutTemplate(
          id: 'template_legs',
          name: 'Legs Day (Picioare & Gambe)',
          split: WorkoutSplit.legs,
          description: 'Antrenament complet pentru trenul inferior: cvadricepși, ischiogambieri și gambe.',
          exerciseIds: [
            'legs_squat',
            'legs_romanian_deadlift',
            'legs_leg_press',
            'legs_leg_curl',
            'legs_calf_raise',
          ],
        ),
        WorkoutTemplate(
          id: 'template_upper',
          name: 'Upper Body (Partea Superioară)',
          split: WorkoutSplit.upper,
          description: 'Antrenament complet echilibrat pentru tot trunchiul superior.',
          exerciseIds: [
            'chest_incline_db_press',
            'back_lat_pulldown',
            'shoulders_db_press',
            'back_db_row',
            'arms_tricep_pushdown',
            'arms_bicep_curl_barbell',
          ],
        ),
        WorkoutTemplate(
          id: 'template_lower_core',
          name: 'Lower Body & Core',
          split: WorkoutSplit.lower,
          description: 'Picioare intense combinate cu stabilitate abdominală și core.',
          exerciseIds: [
            'legs_squat',
            'legs_lunges',
            'legs_leg_extension',
            'core_hanging_leg_raise',
            'core_plank',
          ],
        ),
        WorkoutTemplate(
          id: 'template_fullbody_45',
          name: 'Full Body Express (45 Min)',
          split: WorkoutSplit.fullBody,
          description: 'Rutină compusă ideală pentru eficiență maximă de timp și stimulare metabolică.',
          exerciseIds: [
            'legs_squat',
            'chest_bench_press',
            'back_pullups',
            'shoulders_lateral_raise',
            'core_cable_crunch',
          ],
        ),
      ];
}

class WorkoutTemplate {
  final String id;
  final String name;
  final WorkoutSplit split;
  final String description;
  final List<String> exerciseIds;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.split,
    required this.description,
    required this.exerciseIds,
  });

  List<WorkoutExercise> buildInitialExercises() {
    return exerciseIds
        .map((id) => ExerciseLibrary.findById(id))
        .whereType<ExerciseInfo>()
        .map(
          (info) => WorkoutExercise(
            exerciseInfo: info,
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 20.0, reps: 10),
              ExerciseSet(setNumber: 2, weightKg: 20.0, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 20.0, reps: 10),
            ],
          ),
        )
        .toList();
  }
}
