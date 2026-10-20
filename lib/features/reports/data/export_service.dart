import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/file_downloader/file_download_helper.dart';
import '../../missions/domain/mission_model.dart';
import '../domain/health_report_summary.dart';

class ExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Generates a structured CSV file with UTF-8 BOM for seamless Excel compatibility
  static String generateCsv(HealthReportSummary summary) {
    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Header comment block
    buffer.writeln('# PANDAFIT DATA EXPORT');
    buffer.writeln('# Utilizator: ${summary.profile.fullName} (@${summary.profile.username})');
    buffer.writeln('# Greutate de Start: ${summary.startWeight} kg');
    buffer.writeln('# Greutate Curenta: ${summary.currentWeight} kg (Delta: ${summary.totalDelta >= 0 ? "+" : ""}${summary.totalDelta.toStringAsFixed(1)} kg)');
    buffer.writeln('# Data Export: ${_dateFormat.format(summary.generatedAt)}');
    buffer.writeln('#');

    // Column headers
    buffer.writeln('Data,Ziua,Greutate (kg),Medie 7 Zile (kg),Delta Start (kg),Calorii Consumate (kcal),Calorii Arse (kcal),Calorii Net (kcal),Plan Urmat,Inot / Activitate,Cina,Note');

    final dayFormat = DateFormat('EEEE', 'ro');

    for (final entry in summary.entries) {
      final dateStr = _dateFormat.format(entry.entryDate);
      final dayName = dayFormat.format(entry.entryDate);
      final weightStr = entry.weight?.toStringAsFixed(1) ?? '';
      final maStr = entry.rollingAvg7Days?.toStringAsFixed(1) ?? '';
      final delta = entry.weight != null ? (entry.weight! - summary.startWeight).toStringAsFixed(1) : '';
      final calIn = entry.caloriesIn?.toString() ?? '';
      final calOut = entry.caloriesOut?.toString() ?? '';
      final netCal = entry.netCalories.toString();
      final planStr = entry.planFollowed ? 'DA' : 'NU';
      final swimStr = entry.swimming ? 'DA' : 'NU';
      final dinnerStr = entry.selectedDinner ?? '';

      // Escape quotes in notes
      final cleanNotes = entry.notes != null
          ? '"${entry.notes!.replaceAll('"', '""').replaceAll('\n', ' ')}"'
          : '""';

      buffer.writeln('$dateStr,$dayName,$weightStr,$maStr,$delta,$calIn,$calOut,$netCal,$planStr,$swimStr,$dinnerStr,$cleanNotes');
    }

    return buffer.toString();
  }

  /// Generates a full raw JSON backup for safe external storage or restore
  static String generateJsonBackup(HealthReportSummary summary) {
    final Map<String, dynamic> data = {
      'app': 'PandaFit',
      'version': '1.0.0',
      'exported_at': summary.generatedAt.toIso8601String(),
      'profile': summary.profile.toJson(),
      'active_mission': summary.activeMission?.toJson(),
      'entries_count': summary.entries.length,
      'entries': summary.entries.map((e) => e.toJson()).toList(),
      'summary_kpis': {
        'start_weight_kg': summary.startWeight,
        'current_weight_kg': summary.currentWeight,
        'lowest_weight_kg': summary.lowestWeight,
        'highest_weight_kg': summary.highestWeight,
        'total_delta_kg': summary.totalDelta,
        'current_ma_7days_kg': summary.currentMovingAvg,
        'weekly_rate_kg': summary.weeklyChangeRate,
        'streak_days': summary.streakDays,
        'diet_adherence_percent': summary.dietAdherencePercent,
        'bmr_kcal': summary.bmr,
        'maintenance_tdee_kcal': summary.maintenanceTdee,
        'bmi': summary.bmi,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Downloads CSV file on web or copies to clipboard
  static void downloadCsv(String csvContent, {String? filename}) {
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final name = filename ?? 'PandaFit_Jurnal_$now.csv';

    if (kIsWeb) {
      downloadFileWeb(csvContent, name, 'text/csv;charset=utf-8');
    } else {
      Clipboard.setData(ClipboardData(text: csvContent));
    }
  }

  /// Downloads JSON backup file on web or copies to clipboard
  static void downloadJson(String jsonContent, {String? filename}) {
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final name = filename ?? 'PandaFit_Backup_$now.json';

    if (kIsWeb) {
      downloadFileWeb(jsonContent, name, 'application/json;charset=utf-8');
    } else {
      Clipboard.setData(ClipboardData(text: jsonContent));
    }
  }

  /// Constructs a publication-grade PDF Health & Progress Report with custom typography and layout
  static Future<Uint8List> generatePdfReport(HealthReportSummary summary) async {
    final pdf = pw.Document(
      title: 'Raport de Progres & Sanatate PandaFit - ${summary.profile.fullName}',
      author: 'PandaFit High-Precision Engine',
    );

    final emerald = PdfColor.fromHex('#10B981');
    final emeraldDark = PdfColor.fromHex('#047857');
    final cyan = PdfColor.fromHex('#06B6D4');
    final slate = PdfColor.fromHex('#0F172A');
    final cardBg = PdfColor.fromHex('#F8FAFC');
    final textDark = PdfColor.fromHex('#1E293B');
    final textMuted = PdfColor.fromHex('#64748B');
    final borderCol = PdfColor.fromHex('#E2E8F0');

    final mission = summary.activeMission;
    final isCutting = mission?.missionType == MissionType.cutting;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header Banner
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: slate,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text(
                            'PANDAFIT',
                            style: pw.TextStyle(
                              color: emerald,
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            '· HEALTH & PROGRESS REPORT',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Raport Analitic de Compozitie Corporala & Optimizare Glicemica',
                        style: pw.TextStyle(color: textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Emis la: ${_dateFormat.format(summary.generatedAt)}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'ID: ${summary.profile.id.length >= 8 ? summary.profile.id.substring(0, 8) : summary.profile.id}',
                        style: pw.TextStyle(color: textMuted, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // User Biometrics & Profile Overview
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: cardBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderCol),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        summary.profile.fullName.isNotEmpty ? summary.profile.fullName : summary.profile.username,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textDark),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${summary.profile.age} ani · Sex: ${summary.profile.sex} · Inaltime: ${summary.profile.heightCm} cm · BMI: ${summary.bmi}',
                        style: pw.TextStyle(fontSize: 10, color: textMuted),
                      ),
                    ],
                  ),
                  pw.Row(
                    children: [
                      _buildMetricPill(
                        'Start',
                        '${summary.startWeight} kg',
                        textDark,
                        borderCol,
                      ),
                      pw.SizedBox(width: 8),
                      _buildMetricPill(
                        'Curent (MA7)',
                        '${summary.currentMovingAvg.toStringAsFixed(1)} kg',
                        emeraldDark,
                        emerald,
                      ),
                      pw.SizedBox(width: 8),
                      _buildMetricPill(
                        'Total Delta',
                        '${summary.totalDelta >= 0 ? "+" : ""}${summary.totalDelta.toStringAsFixed(1)} kg',
                        summary.totalDelta <= 0 ? emeraldDark : PdfColors.amber800,
                        borderCol,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Active Mission Card (if present)
            if (mission != null) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: cardBg,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: emerald),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          isCutting ? 'MISIUNE ACTIVA: CUTTING (Deficit de Slabire)' : 'MISIUNE ACTIVA: BULKING (Surplus Curat)',
                          style: pw.TextStyle(color: emeraldDark, fontWeight: pw.FontWeight.bold, fontSize: 11),
                        ),
                        pw.Text(
                          'Tinta: ${mission.targetWeight} kg',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: textDark),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          summary.weeklyChangeRate != null
                              ? 'Ritm Mediu: ${summary.weeklyChangeRate!.toStringAsFixed(2)} kg/saptamana'
                              : 'Ritm Mediu: In calculare',
                          style: pw.TextStyle(fontSize: 10, color: textDark),
                        ),
                        pw.Text(
                          summary.missionEta != null
                              ? 'Data Estimata: ${_dateFormat.format(summary.missionEta!.estimatedTargetDate)} (${summary.missionEta!.weeksRemaining.toStringAsFixed(1)} sapt)'
                              : 'Estimare: Necesita mai multe inregistrari',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: cyan),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // 3-Quadrant Metabolic & Consistency Grid
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildInfoCard(
                    'Profil Metabolic',
                    [
                      'Consum Bazal (BMR): ${summary.bmr} kcal/zi',
                      'Mentenanta (TDEE): ${summary.maintenanceTdee} kcal/zi',
                      'Tinta Zilnica: ${summary.profile.dailyTargetCalories} kcal/zi',
                    ],
                    cardBg,
                    borderCol,
                    textDark,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildInfoCard(
                    'Consistenta & Aderenta',
                    [
                      'Seria Activa: ${summary.streakDays} zile consecutive',
                      'Aderenta Dieta: ${summary.dietAdherencePercent.toStringAsFixed(0)}% zile bifate',
                      'Total Inregistrari: ${summary.totalEntriesLogged} zile',
                    ],
                    cardBg,
                    borderCol,
                    textDark,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildInfoCard(
                    'Bilant Energetic Mediu',
                    [
                      'Calorii Consumate: ~${summary.avgCaloriesIn} kcal',
                      'Calorii Arse: ~${summary.avgCaloriesOut} kcal',
                      'Energie Neta: ~${summary.avgNetCalories} kcal/zi',
                    ],
                    cardBg,
                    borderCol,
                    textDark,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // Weight & Log History Table
            pw.Text(
              'Jurnal de Progres (Ultimele Inregistrari)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: borderCol, width: 0.5),
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Data', isHeader: true),
                    _buildTableCell('Greutate (kg)', isHeader: true),
                    _buildTableCell('Medie 7 Zile (kg)', isHeader: true),
                    _buildTableCell('Calorii Net (kcal)', isHeader: true),
                    _buildTableCell('Dieta Urmata', isHeader: true),
                    _buildTableCell('Activitate', isHeader: true),
                  ],
                ),
                // Table Rows (up to last 20 entries)
                ...summary.entries.take(20).map((entry) {
                  final net = '${entry.netCalories} kcal';
                  final isFollowed = entry.planFollowed ? 'DA' : 'NU';
                  final activity = entry.swimming ? 'Inot' : (entry.caloriesOut != null && entry.caloriesOut! > 0 ? '${entry.caloriesOut} kcal' : '-');

                  return pw.TableRow(
                    children: [
                      _buildTableCell(_dateFormat.format(entry.entryDate)),
                      _buildTableCell(entry.weight?.toStringAsFixed(1) ?? '-'),
                      _buildTableCell(entry.rollingAvg7Days?.toStringAsFixed(1) ?? '-'),
                      _buildTableCell(net),
                      _buildTableCell(isFollowed),
                      _buildTableCell(activity),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 20),

            // Scientific & Methodology Disclaimer
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: cardBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: borderCol),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Rigoare Metodologica PandaFit:',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: textDark),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Greutatea corporala zilnica fluctueaza natural din cauza retentiei de apa, glicogenului si a tranzitului. PandaFit utilizeaza o medie mobila pe 7 zile pentru a elimina aceste anomalii si formule pesimiste de consum caloric pentru a preveni erorile de supraestimare a efortului fizic.',
                    style: pw.TextStyle(fontSize: 8, color: textMuted),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Opens the native print preview / PDF download sheet (works on Web, Mobile, Desktop)
  static Future<void> previewOrPrintPdf(HealthReportSummary summary) async {
    final pdfBytes = await generatePdfReport(summary);
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.layoutPdf(
      name: 'PandaFit_Health_Report_$now.pdf',
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  static pw.Widget _buildMetricPill(String label, String value, PdfColor valColor, PdfColor borderCol) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderCol),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: valColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoCard(
    String title,
    List<String> lines,
    PdfColor bg,
    PdfColor border,
    PdfColor textDark,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark)),
          pw.SizedBox(height: 6),
          ...lines.map(
            (l) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                l,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }
}
