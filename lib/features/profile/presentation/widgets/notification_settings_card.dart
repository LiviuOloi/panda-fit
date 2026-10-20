import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/panda_button.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  State<NotificationSettingsCard> createState() => _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  final _service = NotificationService();

  bool _morningEnabled = true;
  TimeOfDay _morningTime = const TimeOfDay(hour: 7, minute: 30);

  bool _eveningEnabled = true;
  TimeOfDay _eveningTime = const TimeOfDay(hour: 21, minute: 0);

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morningEnabled = prefs.getBool(NotificationService.keyMorningEnabled) ?? true;
      final mHour = prefs.getInt(NotificationService.keyMorningHour) ?? 7;
      final mMinute = prefs.getInt(NotificationService.keyMorningMinute) ?? 30;
      _morningTime = TimeOfDay(hour: mHour, minute: mMinute);

      _eveningEnabled = prefs.getBool(NotificationService.keyEveningEnabled) ?? true;
      final eHour = prefs.getInt(NotificationService.keyEveningHour) ?? 21;
      final eMinute = prefs.getInt(NotificationService.keyEveningMinute) ?? 0;
      _eveningTime = TimeOfDay(hour: eHour, minute: eMinute);

      _isLoading = false;
    });
  }

  Future<void> _toggleMorning(bool val) async {
    await HapticFeedback.selectionClick();
    if (val) {
      await _service.requestPermissions();
    }
    setState(() => _morningEnabled = val);
    await _service.scheduleDailyMorningReminder(
      hour: _morningTime.hour,
      minute: _morningTime.minute,
      enabled: val,
    );
  }

  Future<void> _pickMorningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _morningTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.emerald,
              surface: AppColors.surfaceElevated,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await HapticFeedback.selectionClick();
      setState(() => _morningTime = picked);
      await _service.scheduleDailyMorningReminder(
        hour: picked.hour,
        minute: picked.minute,
        enabled: _morningEnabled,
      );
    }
  }

  Future<void> _toggleEvening(bool val) async {
    await HapticFeedback.selectionClick();
    if (val) {
      await _service.requestPermissions();
    }
    setState(() => _eveningEnabled = val);
    await _service.scheduleDailyEveningReminder(
      hour: _eveningTime.hour,
      minute: _eveningTime.minute,
      enabled: val,
    );
  }

  Future<void> _pickEveningTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eveningTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.emerald,
              surface: AppColors.surfaceElevated,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await HapticFeedback.selectionClick();
      setState(() => _eveningTime = picked);
      await _service.scheduleDailyEveningReminder(
        hour: picked.hour,
        minute: picked.minute,
        enabled: _eveningEnabled,
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await HapticFeedback.mediumImpact();
    await _service.requestPermissions();
    await _service.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notificare de test trimisă! Verifică bara de notificări 🐼'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      borderColor: AppColors.amber.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: AppColors.amber, size: 20),
              SizedBox(width: 8),
              Text(
                'Mementouri & Notificări Locale',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Primește mementouri zilnice direct pe telefon pentru menținerea disciplinei și acuratețea mediei mobile.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // Morning Reminder Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, color: AppColors.amber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cântărire Dimineața',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Reamintire la ${_formatTime(_morningTime)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _morningEnabled ? _pickMorningTime : null,
                  child: Text(
                    _formatTime(_morningTime),
                    style: TextStyle(
                      color: _morningEnabled ? AppColors.emeraldLight : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _morningEnabled,
                  activeThumbColor: AppColors.emerald,
                  onChanged: _toggleMorning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Evening Reminder Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.nightlight_round, color: AppColors.cyan, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jurnal & Mese de Seară',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Reamintire la ${_formatTime(_eveningTime)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _eveningEnabled ? _pickEveningTime : null,
                  child: Text(
                    _formatTime(_eveningTime),
                    style: TextStyle(
                      color: _eveningEnabled ? AppColors.cyan : AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: _eveningEnabled,
                  activeThumbColor: AppColors.emerald,
                  onChanged: _toggleEvening,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Test notification button
          PandaButton(
            label: 'Trimite Notificare de Test',
            icon: Icons.send_to_mobile_rounded,
            variant: PandaButtonVariant.outline,
            width: double.infinity,
            onPressed: _sendTestNotification,
          ),
        ],
      ),
    );
  }
}
