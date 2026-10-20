import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/panda_button.dart';
import '../../daily_logger/domain/daily_entry_model.dart';
import '../../missions/domain/mission_model.dart';
import '../../profile/domain/profile_model.dart';
import '../data/export_service.dart';
import '../domain/health_report_summary.dart';

class ExportReportDialog extends ConsumerStatefulWidget {
  final UserProfile profile;
  final List<DailyEntry> entries;
  final Mission? activeMission;

  const ExportReportDialog({
    super.key,
    required this.profile,
    required this.entries,
    this.activeMission,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile profile,
    required List<DailyEntry> entries,
    Mission? activeMission,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ExportReportDialog(
        profile: profile,
        entries: entries,
        activeMission: activeMission,
      ),
    );
  }

  @override
  ConsumerState<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends ConsumerState<ExportReportDialog> {
  bool _isGeneratingPdf = false;
  bool _isExportingCsv = false;
  bool _isExportingJson = false;

  late final HealthReportSummary _summary;

  @override
  void initState() {
    super.initState();
    _summary = HealthReportSummary.fromData(
      profile: widget.profile,
      entries: widget.entries,
      activeMission: widget.activeMission,
    );
  }

  Future<void> _handlePdfExport() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await ExportService.previewOrPrintPdf(_summary);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📄 Raportul PDF a fost generat pentru previzualizare și salvare!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare la generarea PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  void _handleCsvExport() {
    setState(() => _isExportingCsv = true);
    try {
      final csv = ExportService.generateCsv(_summary);
      ExportService.downloadCsv(csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📊 Fișierul CSV (Excel) a fost descărcat cu succes!'),
            backgroundColor: AppColors.cyan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare la descărcarea CSV: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  void _handleJsonExport() {
    setState(() => _isExportingJson = true);
    try {
      final json = ExportService.generateJsonBackup(_summary);
      ExportService.downloadJson(json);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('💾 Backup-ul JSON complet a fost generat și salvat!'),
            backgroundColor: AppColors.emerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eroare la descărcarea backup-ului JSON: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingJson = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.glassBorder),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.assessment_outlined, color: AppColors.emerald, size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Rapoarte & Export Date',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Descarcă rapoarte profesionale de sănătate sau date brute pentru Excel, Google Sheets și arhivare.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 18),

              // Summary Stats Preview Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickMetric(
                      'Zile Logate',
                      '${_summary.totalEntriesLogged}',
                      AppColors.textPrimary,
                    ),
                    Container(height: 30, width: 1, color: AppColors.glassBorder),
                    _buildQuickMetric(
                      'Medie 7 Zile',
                      '${_summary.currentMovingAvg.toStringAsFixed(1)} kg',
                      AppColors.emerald,
                    ),
                    Container(height: 30, width: 1, color: AppColors.glassBorder),
                    _buildQuickMetric(
                      'Delta Total',
                      '${_summary.totalDelta >= 0 ? "+" : ""}${_summary.totalDelta.toStringAsFixed(1)} kg',
                      _summary.totalDelta <= 0 ? AppColors.emerald : AppColors.amber,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: PDF Clinical Health Report
              _buildExportOptionCard(
                icon: Icons.picture_as_pdf_outlined,
                iconColor: AppColors.emerald,
                title: 'Raport Clinic PDF (A4)',
                subtitle:
                    'Document complet de prezentare pentru medic/nutriționist: media mobilă, profil metabolic (BMR, TDEE), constanță, ritm săptămânal și tabel detaliat.',
                buttonLabel: 'Previzualizează & Printează PDF',
                isLoading: _isGeneratingPdf,
                buttonVariant: PandaButtonVariant.primary,
                onPressed: _handlePdfExport,
              ),
              const SizedBox(height: 14),

              // Option 2: CSV Spreadsheet
              _buildExportOptionCard(
                icon: Icons.table_chart_outlined,
                iconColor: AppColors.cyan,
                title: 'Foaie de Calcul CSV (Excel / Sheets)',
                subtitle:
                    'Tabel compatibil Excel cu delimitatori standard, UTF-8 BOM, calorii nete, aderență și note pentru analize avansate.',
                buttonLabel: 'Descarcă Fișier CSV',
                isLoading: _isExportingCsv,
                buttonVariant: PandaButtonVariant.secondary,
                onPressed: _handleCsvExport,
              ),
              const SizedBox(height: 14),

              // Option 3: JSON Full Backup
              _buildExportOptionCard(
                icon: Icons.data_object_outlined,
                iconColor: AppColors.amber,
                title: 'Backup Complet Date (JSON)',
                subtitle:
                    'Copie de siguranță brută a profilului, istoricului de cântăriri și a misiunii active pentru stocare sigură offline.',
                buttonLabel: 'Descarcă Backup JSON',
                isLoading: _isExportingJson,
                buttonVariant: PandaButtonVariant.outline,
                onPressed: _handleJsonExport,
              ),
              const SizedBox(height: 16),

              // Close footer
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Închide', style: TextStyle(color: AppColors.textMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildExportOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required bool isLoading,
    required PandaButtonVariant buttonVariant,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PandaButton(
              label: buttonLabel,
              icon: icon,
              variant: buttonVariant,
              isLoading: isLoading,
              onPressed: isLoading ? null : onPressed,
            ),
          ),
        ],
      ),
    );
  }
}
