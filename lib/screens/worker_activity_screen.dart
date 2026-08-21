import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:csv/csv.dart';
import '../services/complaint_service.dart';
import '../utils/file_download_helper.dart';

class WorkerActivityScreen extends StatefulWidget {
  const WorkerActivityScreen({super.key});

  @override
  State<WorkerActivityScreen> createState() => _WorkerActivityScreenState();
}

class _WorkerActivityScreenState extends State<WorkerActivityScreen> {
  String _selectedRangeLabel = "This Month";
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  final List<String> _rangeOptions = const [
    "Today",
    "Yesterday",
    "This Week",
    "This Month",
    "Custom",
  ];

  @override
  void initState() {
    super.initState();
    _applyRangePreset("This Month");
  }

  void _applyRangePreset(String label) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (label) {
      case "Yesterday":
        final yesterday = now.subtract(const Duration(days: 1));
        start = DateTime(yesterday.year, yesterday.month, yesterday.day);
        end = start;
        break;
      case "This Week":
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        end = DateTime(now.year, now.month, now.day);
        break;
      case "This Month":
        // 26th of previous month to 25th of current month cycle
        if (now.day >= 26) {
          start = DateTime(now.year, now.month, 26);
          end = DateTime(now.month == 12 ? now.year + 1 : now.year, now.month == 12 ? 1 : now.month + 1, 25);
        } else {
          start = DateTime(now.month == 1 ? now.year - 1 : now.year, now.month == 1 ? 12 : now.month - 1, 26);
          end = DateTime(now.year, now.month, 25);
        }
        break;
      case "Today":
      default:
        start = DateTime(now.year, now.month, now.day);
        end = start;
    }
    setState(() {
      _selectedRangeLabel = label;
      _rangeStart = start;
      _rangeEnd = end;
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
      helpText: "Select Date Range",
    );
    if (picked != null) {
      setState(() {
        _selectedRangeLabel = "Custom";
        _rangeStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _rangeEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "N/A";
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--:--";
    return DateFormat('hh:mm a').format(dt);
  }

  String _rangeDisplayText() {
    if (_rangeStart.year == _rangeEnd.year &&
        _rangeStart.month == _rangeEnd.month &&
        _rangeStart.day == _rangeEnd.day) {
      return DateFormat('dd MMM yyyy').format(_rangeStart);
    }
    return "${DateFormat('dd MMM yyyy').format(_rangeStart)} - ${DateFormat('dd MMM yyyy').format(_rangeEnd)}";
  }

  Widget _buildRangeBar() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _rangeOptions.map((label) {
                final isSelected = _selectedRangeLabel == label;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: Colors.indigo.shade700,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) {
                      if (label == "Custom") {
                        _pickCustomRange();
                      } else {
                        _applyRangePreset(label);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Report cycle: ${_rangeDisplayText()}",
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateMonthlyAttendanceExcel(context),
                icon: const Icon(Icons.table_chart, size: 14),
                label: const Text("Attendance Sheet", style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool isPresent, bool isActive) {
    if (!isActive) {
      return Chip(
        label: const Text("Inactive", style: TextStyle(color: Colors.white, fontSize: 11)),
        backgroundColor: Colors.grey.shade600,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }
    return Chip(
      label: Text(
        isPresent ? "Present" : "Absent",
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: isPresent ? Colors.green.shade700 : Colors.red.shade700,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // --- DETAILED ATTENDANCE SHEET EXCEL / CSV GENERATOR ---
  Future<void> _generateMonthlyAttendanceExcel(BuildContext context) async {
    final service = Provider.of<ComplaintService>(context, listen: false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Generating Detailed Attendance Sheet (26th - 25th)...")),
    );

    try {
      final technicians = await service.getAllTechniciansStream().first;
      List<List<dynamic>> rows = [];

      for (var tech in technicians) {
        final techName = tech['name'] ?? 'Unknown';
        final techUid = tech['uid'] ?? '';
        final building = tech['buildingName'] ?? tech['building'] ?? tech['locationName'] ?? tech['siteName'] ?? tech['assignedBuilding'] ?? 'N/A';

        // Section header per technician
        rows.add(["Technician Name: $techName", "Building: $building"]);
        rows.add(["Date", "Status", "Time In", "Time Out", "OT Hrs", "Remarks"]);

        // Fetch logs for this technician covering the full cycle
        List<Map<String, dynamic>> logs = [];
        try {
          logs = await service.getTechnicianActivityLogs(
            techUid,
            startDate: _rangeStart,
            endDate: DateTime(_rangeEnd.year, _rangeEnd.month, _rangeEnd.day, 23, 59, 59),
          ).first;
        } catch (_) {
          logs = [];
        }

        // Group logs by calendar date (yyyy-MM-dd)
        Map<String, List<Map<String, dynamic>>> logsByDate = {};
        for (var log in logs) {
          DateTime? ts;
          try {
            ts = (log['timestamp'])?.toDate();
          } catch (_) {
            ts = null;
          }
          if (ts != null) {
            String dateKey = DateFormat('yyyy-MM-dd').format(ts);
            logsByDate.putIfAbsent(dateKey, () => []).add(log);
          }
        }

        // Iterate day-by-day without missing any dates from range start to end
        DateTime currentDate = _rangeStart;
        while (!currentDate.isAfter(_rangeEnd)) {
          String dateKey = DateFormat('yyyy-MM-dd').format(currentDate);
          String displayDate = DateFormat('dd MMM yyyy (EEE)').format(currentDate);
          
          List<Map<String, dynamic>> dayLogs = logsByDate[dateKey] ?? [];

          if (dayLogs.isEmpty) {
            rows.add([displayDate, "Absent", "--", "--", "0.0", "Absent"]);
          } else {
            // Sort chronologically
            dayLogs.sort((a, b) => 
              (a['timestamp']?.toDate() ?? DateTime(2000)).compareTo(b['timestamp']?.toDate() ?? DateTime(2000))
            );

            List<String> timeIns = [];
            List<String> timeOuts = [];

            for (int i = 0; i < dayLogs.length; i += 2) {
              DateTime? inTime = dayLogs[i]['timestamp']?.toDate();
              if (inTime != null) {
                timeIns.add(DateFormat('hh:mm a').format(inTime));
              }
              if (i + 1 < dayLogs.length) {
                DateTime? outTime = dayLogs[i+1]['timestamp']?.toDate();
                if (outTime != null) {
                  timeOuts.add(DateFormat('hh:mm a').format(outTime));
                }
              } else {
                DateTime? lastTime = dayLogs.last['timestamp']?.toDate();
                if (lastTime != null && timeOuts.isEmpty) {
                  timeOuts.add(DateFormat('hh:mm a').format(lastTime));
                } else {
                  timeOuts.add("--");
                }
              }
            }

            String timeInStr = timeIns.isEmpty ? DateFormat('hh:mm a').format(dayLogs.first['timestamp'].toDate()) : timeIns.join(" / ");
            String timeOutStr = timeOuts.isEmpty ? DateFormat('hh:mm a').format(dayLogs.last['timestamp'].toDate()) : timeOuts.join(" / ");

            double otHours = 0;
            bool isFriday = currentDate.weekday == DateTime.friday;

            for (int i = 0; i < dayLogs.length - 1; i += 2) {
              DateTime? inTime = dayLogs[i]['timestamp']?.toDate();
              DateTime? outTime = dayLogs[i+1]['timestamp']?.toDate();
              if (inTime == null || outTime == null) continue;

              if (isFriday) {
                otHours += outTime.difference(inTime).inMinutes / 60.0;
              } else {
                DateTime dutyStart = DateTime(inTime.year, inTime.month, inTime.day, 8, 0);
                DateTime dutyEnd = DateTime(inTime.year, inTime.month, inTime.day, 17, 0);
                double minutes = 0;
                
                if (inTime.isBefore(dutyStart)) {
                  DateTime effOut = outTime.isBefore(dutyStart) ? outTime : dutyStart;
                  minutes += effOut.difference(inTime).inMinutes;
                }
                if (outTime.isAfter(dutyEnd)) {
                  DateTime effIn = inTime.isAfter(dutyEnd) ? inTime : dutyEnd;
                  minutes += outTime.difference(effIn).inMinutes;
                }
                otHours += minutes / 60.0;
              }
            }

            String remarks = isFriday ? "Friday (Full OT)" : (otHours > 0 ? "OT Worked" : "Normal Duty");
            if (timeIns.length > 1) remarks += " / Split Shift";

            rows.add([
              displayDate,
              "Present",
              timeInStr,
              timeOutStr,
              otHours.toStringAsFixed(1),
              remarks,
            ]);
          }

          currentDate = currentDate.add(const Duration(days: 1));
        }

        rows.add([]);
        rows.add([]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      List<int> bytes = utf8.encode(csvData);

      String fileName = "attendance_cycle_${DateFormat('yyyyMMdd').format(_rangeStart)}.csv";
      await saveAndDownloadFile(bytes, fileName);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance Sheet downloaded successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate attendance sheet: $e")),
      );
    }
  }

  // --- PDF PRODUCTIVITY SUMMARY GENERATOR ---
  Future<void> _downloadProductivityPdf(
    BuildContext context,
    ComplaintService service,
    String techUid,
    String techName,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Generating PDF for $techName...")),
      );

      final timeInOut = await service.getTechnicianTimeInOut(techUid, _rangeStart, _rangeEnd);
      final productivity = await service.getTechnicianProductivitySummary(techName, _rangeStart, _rangeEnd);

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Technician Productivity Report", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text("Technician Name: $techName", style: pw.TextStyle(fontSize: 14)),
                pw.Text("Cycle: ${_rangeDisplayText()}", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.Divider(height: 20),
                
                pw.Text("Time In / Time Out", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Time In: ${_formatTime(timeInOut['timeIn'])}"),
                    pw.Text("Time Out: ${_formatTime(timeInOut['timeOut'])}"),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                pw.Text("Productivity Summary", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Bullet(text: "Total Handled: ${productivity['total'] ?? 0}"),
                pw.Bullet(text: "Resolved: ${productivity['resolved'] ?? 0}"),
                pw.Bullet(text: "Standby: ${productivity['standby'] ?? 0}"),
                pw.Bullet(text: "Pending / In Progress: ${productivity['pendingOrInProgress'] ?? 0}"),
              ],
            );
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final sanitizedName = techName.replaceAll(RegExp(r'\s+'), '_');
      await saveAndDownloadFile(bytes, "productivity_$sanitizedName.pdf");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF downloaded successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to download PDF: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Worker Activity"),
        backgroundColor: Colors.indigo.shade900,
      ),
      body: Column(
        children: [
          _buildRangeBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: service.getAllTechniciansStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No technicians found"));
                }
                final technicians = snapshot.data!;
                technicians.sort((a, b) =>
                    (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: technicians.length,
                  itemBuilder: (context, index) {
                    final tech = technicians[index];
                    final String name = tech['name'] ?? 'Unknown';
                    final String uid = tech['uid'] ?? '';
                    final bool isActive = tech['isActive'] ?? true;
                    final bool isPresent =
                        (tech['status'] ?? 'absent').toString().toLowerCase() == 'present';
                    final String lastAction = tech['lastAction'] ?? 'N/A';
                    final dynamic updatedAtRaw = tech['updatedAt'];
                    DateTime? lastSeen;
                    try {
                      lastSeen = updatedAtRaw?.toDate();
                    } catch (_) {
                      lastSeen = null;
                    }
                    
                    // Comprehensive fallback lookup for building name keys
                    final String buildingName = tech['buildingName'] ?? 
                                                tech['building'] ?? 
                                                tech['locationName'] ?? 
                                                tech['siteName'] ?? 
                                                tech['assignedBuilding'] ?? 
                                                'N/A';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            _statusChip(isPresent, isActive),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text("Last activity: $lastAction",
                                style: const TextStyle(fontSize: 12)),
                            Text("Last seen: ${_formatDateTime(lastSeen)}",
                                style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Text("Building Location: $buildingName",
                                style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: uid.isEmpty
                            ? null
                            : () => _showTechnicianDetailDialog(context, service, uid, name),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTechnicianDetailDialog(
    BuildContext context,
    ComplaintService service,
    String techUid,
    String techName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(techName, style: const TextStyle(fontSize: 16))),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: "Download Productivity PDF",
              onPressed: () => _downloadProductivityPdf(context, service, techUid, techName),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 520,
          child: FutureBuilder<List<dynamic>>(
            future: Future.wait([
              service.getTechnicianTimeInOut(techUid, _rangeStart, _rangeEnd),
              service.getTechnicianProductivitySummary(techName, _rangeStart, _rangeEnd),
            ]),
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (futureSnapshot.hasError || !futureSnapshot.hasData) {
                return const Center(child: Text("Failed to load report."));
              }
              final timeInOut = futureSnapshot.data![0] as Map<String, DateTime?>;
              final productivity = futureSnapshot.data![1] as Map<String, int>;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Report cycle: ${_rangeDisplayText()}",
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                    const SizedBox(height: 12),
                    const Text("TIME IN / TIME OUT",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryTile(
                            "Time In (First Action)",
                            _formatTime(timeInOut['timeIn']),
                            Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _summaryTile(
                            "Time Out (Last Action)",
                            _formatTime(timeInOut['timeOut']),
                            Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("PRODUCTIVITY SUMMARY",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryTile(
                            "Total Handled",
                            "${productivity['total'] ?? 0}",
                            Colors.indigo.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _summaryTile(
                            "Resolved",
                            "${productivity['resolved'] ?? 0}",
                            Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _summaryTile(
                            "Standby",
                            "${productivity['standby'] ?? 0}",
                            Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _summaryTile(
                            "Pending / In Progress",
                            "${productivity['pendingOrInProgress'] ?? 0}",
                            Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text("ACTIVITY LOG",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: service.getTechnicianActivityLogs(
                        techUid,
                        startDate: _rangeStart,
                        endDate: DateTime(
                            _rangeEnd.year, _rangeEnd.month, _rangeEnd.day, 23, 59, 59),
                      ),
                      builder: (context, logSnapshot) {
                        if (logSnapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final logs = logSnapshot.data ?? [];
                        if (logs.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text("No activity logs found for this range.",
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          );
                        }
                        return Column(
                          children: logs.map((log) {
                            DateTime? ts;
                            try {
                              ts = (log['timestamp'])?.toDate();
                            } catch (_) {
                              ts = null;
                            }
                            final action = log['actionType'] ?? 'N/A';
                            final buildingName = log['buildingName'] ?? log['building'] ?? log['locationName'] ?? 'N/A';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Colors.indigo),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(action.toString(),
                                            style: const TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(_formatDateTime(ts),
                                            style: const TextStyle(
                                                fontSize: 11, color: Colors.grey)),
                                        Text(
                                          "Building: $buildingName",
                                          style: const TextStyle(
                                              fontSize: 10, color: Colors.blueGrey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE"),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}