import 'config_screen.dart';
import 'dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
// PDF & Printing packages imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
 
import 'dart:html' as html if (dart.library.io) 'package:flutter/material.dart';
 
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}
 
class _AdminScreenState extends State<AdminScreen> {
  String selectedStatus = "All";
  String selectedBuilding = "All";
  String selectedTimeFrame = "All";
  String selectedViewType = "Active"; 
  DateTime? customDate;
  List<String> _complaintTypes = [
    "Water leakage", "Low cooling", "Smell coming from AC", 
    "Sound coming from AC", "Cleaning/Service", "New rent out", 
    "Low air speed", "Low fan speed", "AC fan not working", "Others"
  ];
  List<String> _buildings = [
    "All", "Expo Tower", "Gate Tower 1", "Gate Tower 2", "Al Khor Tower C",
    "Rital & Rinad",  "Jodi 1", "Jodi 2", "Jodi 3", "Falcon Jodi 5", "Naseem",
    "Hala Building", "Nada building", "Al Tameer",  "Tallah Mall", "Al Khor Mall",
    "Mazaya", "Yasmeen Tower", "Ajman Club", "Salah Ud Din", "Sara Plaza 3", "Jurf 2",
    "Flower Shop", "Amina Hospital", "Villas", "Sharjah", "Rashdiya", "Galleria Mall",
    "N/A", "Others"
  ];
  final List<String> _statusOptions = [
    "All", "Pending", "In Progress", "Standby", "Resolved", "Closed by Customer"
  ];
  String _formatDate(DateTime? date) => 
      date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : "N/A";
  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
      
  void _showDashboardPinDialog(BuildContext context) {
    final controller = TextEditingController();
    void submit() {
      if (controller.text == "6693") {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN")));
      }
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Dashboard Access"),
        content: TextField(controller: controller, obscureText: true, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: submit, child: const Text("Enter")),
        ],
      ),
    );
  }
  void _showExportRangeDialog(List<Complaint> allComplaints) async {
    DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: "Select Date Range for CSV Export",
    );
    if (range != null) {
      _downloadFilteredReport(allComplaints, range);
    }
  }
  void _downloadFilteredReport(List<Complaint> allComplaints, DateTimeRange range) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CSV Export is currently only supported on Web version."))
      );
      return;
    }
    final exportData = allComplaints.where((c) {
      bool dateMatch = c.createdAt.isAfter(range.start) && 
                       c.createdAt.isBefore(range.end.add(const Duration(days: 1)));
      
      bool viewMatch = true;
      if (selectedViewType == "Active") viewMatch = (c.isDeleted != true);
      if (selectedViewType == "Deleted") viewMatch = (c.isDeleted == true);
      
      return dateMatch && viewMatch;
    }).toList();
    List<List<dynamic>> rows = [];
    rows.add([
      "ID", "Building", "Flat", "Type", "Status", 
      "Registered_By", "Reg_Time",
      "Started_By", "Start_Time",
      "Standby_By", "Standby_Time", "Standby_Remarks", 
      "Closed_By", "Close_Time", "Serial_No", "Materials", "Closing_Remarks"
    ]);
    for (var c in exportData) {
      bool isCustomerClosed = c.status == "Closed by Customer";
      String closerName = isCustomerClosed ? (c.customerName) : (c.closedBy ?? 'N/A');
      String serialNo = isCustomerClosed ? 'N/A' : (c.serviceReportNumber ?? 'N/A');
      String displayStatus = c.isDeleted == true ? "DELETED (${c.status})" : c.status;
      String displayBuilding = c.buildingName;
      String displayType = (c.complaintType == "Others" || !_complaintTypes.contains(c.complaintType)) ? "${c.description} (Other)" : c.complaintType;
      rows.add([
        c.id,
        displayBuilding,
        c.flatNumber,
        displayType,
        displayStatus,
        c.customerName,
        _formatDate(c.createdAt),
        c.technicianName ?? 'N/A',
        _formatDate(c.startTime),
        c.standbyBy ?? 'N/A',
        _formatDate(c.standbyTime),
        c.standbyReason.replaceAll('\n', ' '),
        closerName,
        _formatDate(c.completedAt),
        serialNo,
        c.materialsUsed,
        c.finalRemarks.replaceAll('\n', ' ')
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    
    try {
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Report_${DateFormat('dd_MM_yy').format(range.start)}.csv")
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint("Download failed or not supported on this platform: $e");
    }
  }
  void _showMediaDialog(BuildContext context, Complaint c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Images & Signatures (${c.id})"),
        content: SizedBox(
          width: 500,
          height: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Before Work Picture:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                c.beforeImageUrl != null && c.beforeImageUrl!.isNotEmpty
                    ? Image.network(c.beforeImageUrl!, height: 150, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Text("Failed to load image"))
                    : const Text("No image captured", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                const Divider(height: 20),
                const Text("Standby Picture:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                c.standbyImageUrl != null && c.standbyImageUrl!.isNotEmpty
                    ? Image.network(c.standbyImageUrl!, height: 150, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Text("Failed to load image"))
                    : const Text("No standby image captured", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                const Divider(height: 20),
                const Text("After Work Picture:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                c.afterImageUrl != null && c.afterImageUrl!.isNotEmpty
                    ? Image.network(c.afterImageUrl!, height: 150, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Text("Failed to load image"))
                    : const Text("No image captured", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                const Divider(height: 20),
                const Text("Technician Signature:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                c.technicianSignatureUrl != null && c.technicianSignatureUrl!.isNotEmpty
                    ? Image.network(c.technicianSignatureUrl!, height: 100, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Text("Failed to load signature"))
                    : const Text("No technician signature", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                const Divider(height: 20),
                const Text("Customer Signature:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                c.customerSignatureUrl != null && c.customerSignatureUrl!.isNotEmpty
                    ? Image.network(c.customerSignatureUrl!, height: 100, fit: BoxFit.contain, errorBuilder: (_,__,___) => const Text("Failed to load signature"))
                    : const Text("No customer signature", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))
        ],
      ),
    );
  }
  Future<void> _generateMasterServiceReportPdf(BuildContext context, ComplaintService service, Complaint c) async {
    List<Complaint> flatHistory = [];
    try {
      final allHistory = await service.getAdminFullHistory().first;
      flatHistory = allHistory.where((item) => 
        item.buildingName.trim().toLowerCase() == c.buildingName.trim().toLowerCase() && 
        item.flatNumber.trim().toLowerCase() == c.flatNumber.trim().toLowerCase()
      ).toList();
    } catch (_) {
      flatHistory = [c];
    }
    
    pw.ImageProvider? beforeImg;
    pw.ImageProvider? standbyImg;
    pw.ImageProvider? afterImg;
    pw.ImageProvider? techSigImg;
    pw.ImageProvider? custSigImg;
    try {
      if (c.beforeImageUrl != null && c.beforeImageUrl!.isNotEmpty) {
        beforeImg = await networkImage(c.beforeImageUrl!);
      }
    } catch (_) {}
    try {
      if (c.standbyImageUrl != null && c.standbyImageUrl!.isNotEmpty) {
        standbyImg = await networkImage(c.standbyImageUrl!);
      }
    } catch (_) {}
    try {
      if (c.afterImageUrl != null && c.afterImageUrl!.isNotEmpty) {
        afterImg = await networkImage(c.afterImageUrl!);
      }
    } catch (_) {}
    try {
      if (c.technicianSignatureUrl != null && c.technicianSignatureUrl!.isNotEmpty) {
        techSigImg = await networkImage(c.technicianSignatureUrl!);
      }
    } catch (_) {}
    try {
      if (c.customerSignatureUrl != null && c.customerSignatureUrl!.isNotEmpty) {
        custSigImg = await networkImage(c.customerSignatureUrl!);
      }
    } catch (_) {}
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("MASTER SERVICE REPORT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                    pw.SizedBox(height: 4),
                    pw.Text("Complaint ID: ${c.id}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Status: ${c.status}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.red900),
            pw.SizedBox(height: 10),
            pw.Text("COMPLAINT INFORMATION", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text("Building: ${c.buildingName}", style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(child: pw.Text("Flat Number: ${c.flatNumber}", style: const pw.TextStyle(fontSize: 10))),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text("Complaint Type: ${c.complaintType}", style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(child: pw.Text("Registered By: ${c.customerName}", style: const pw.TextStyle(fontSize: 10))),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text("Registration Time: ${_formatDate(c.createdAt)}", style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(child: pw.Text("Service Report #: ${c.serviceReportNumber ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10))),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text("Description / Remarks: ${c.description.isNotEmpty ? c.description : 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
                  if (c.materialsUsed.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text("Materials Used: ${c.materialsUsed}", style: const pw.TextStyle(fontSize: 10)),
                  ],
                  if (c.finalRemarks.isNotEmpty) ...[
                    pw.SizedBox(height: 6),
                    pw.Text("Closing Remarks: ${c.finalRemarks}", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Text("WORK IMAGES", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text("Before Picture", style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    beforeImg != null 
                        ? pw.Container(width: 120, height: 100, child: pw.Image(beforeImg))
                        : pw.Container(width: 120, height: 100, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Text("N/A", style: const pw.TextStyle(fontSize: 8))),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text("Standby Picture", style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    standbyImg != null 
                        ? pw.Container(width: 120, height: 100, child: pw.Image(standbyImg))
                        : pw.Container(width: 120, height: 100, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Text("N/A", style: const pw.TextStyle(fontSize: 8))),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text("After Picture", style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    afterImg != null 
                        ? pw.Container(width: 120, height: 100, child: pw.Image(afterImg))
                        : pw.Container(width: 120, height: 100, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Text("N/A", style: const pw.TextStyle(fontSize: 8))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Text("SIGNATURES", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    techSigImg != null 
                        ? pw.Container(width: 200, height: 60, child: pw.Image(techSigImg))
                        : pw.Container(width: 200, height: 60, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Text("No Signature", style: const pw.TextStyle(fontSize: 8))),
                    pw.SizedBox(height: 4),
                    pw.Text("Technician Signature", style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  children: [
                    custSigImg != null 
                        ? pw.Container(width: 200, height: 60, child: pw.Image(custSigImg))
                        : pw.Container(width: 200, height: 60, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)), child: pw.Text("No Signature", style: const pw.TextStyle(fontSize: 8))),
                    pw.SizedBox(height: 4),
                    pw.Text("Customer Signature", style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
            pw.Text("TIMELINE & STATUS HISTORY LOGS", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            c.timelineLogs.isEmpty
                ? pw.Text("No timeline logs recorded.", style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))
                : pw.Table.fromTextArray(
                    headers: ["Timestamp", "Status", "User / Tech", "Remarks"],
                    data: c.timelineLogs.map((log) {
                      String formattedTime = log['timestamp'] != null 
                          ? _formatDate(DateTime.tryParse(log['timestamp']) ?? DateTime.now()) 
                          : 'N/A';
                      return [
                        formattedTime,
                        log['status'] ?? 'N/A',
                        log['userName'] ?? 'N/A',
                        log['remarks'] ?? 'N/A',
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.all(6),
                  ),
            pw.SizedBox(height: 15),
            pw.Text("FLAT HISTORY (${c.buildingName} - Flat ${c.flatNumber})", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.SizedBox(height: 6),
            flatHistory.isEmpty
                ? pw.Text("No other records found for this flat.", style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))
                : pw.Table.fromTextArray(
                    headers: ["Date", "Complaint Type", "Status", "Technician", "Remarks"],
                    data: flatHistory.map((item) {
                      return [
                        _formatDate(item.createdAt),
                        item.complaintType,
                        item.status,
                        item.technicianName ?? 'N/A',
                        item.finalRemarks.isNotEmpty ? item.finalRemarks : (item.description.isNotEmpty ? item.description : 'N/A'),
                      ];
                    }).toList(),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.all(6),
                  ),
          ];
        },
      ),
    );
    
    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Master_Service_Report_${c.id}.pdf');
  }
  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Master Admin Dashboard"),
        backgroundColor: Colors.red.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard),
            tooltip: 'Dashboard',
            onPressed: () => _showDashboardPinDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ConfigurationScreen(
                initialBuildings: _buildings,
                initialTypes: _complaintTypes,
                onSave: (newBuildings, newTypes) async {
                  await service.updateConfigList("buildings", newBuildings);
                  await service.updateConfigList("types", newTypes);
                  setState(() {
                    _buildings = newBuildings;
                    _complaintTypes = newTypes;
                  });
                  Navigator.pop(context);
                },
              )));
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () => setState(() {
              selectedStatus = "All"; selectedBuilding = "All"; selectedTimeFrame = "All";
              selectedViewType = "Active"; customDate = null;
            }),
          )
        ],
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: service.getAdminFullHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text("No data found"));
          
          final all = snapshot.data!;
          Map<String, int> counts = _calculateLiveCounts(all);
          return Column(
            children: [
              _buildFilterBar(counts),
              _buildActionRow(all),
              const Divider(height: 1),
              Expanded(child: _buildFilteredList(all, service)),
            ],
          );
        },
      ),
    );
  }
  Map<String, int> _calculateLiveCounts(List<Complaint> all) {
    Map<String, int> map = {};
    
    final baseFiltered = all.where((c) {
      bool matchViewType = true;
      if (selectedViewType == "Active") matchViewType = (c.isDeleted != true);
      if (selectedViewType == "Deleted") matchViewType = (c.isDeleted == true);
      bool matchBuilding = false;
      if (selectedBuilding == "All") {
        matchBuilding = true;
      } else if (selectedBuilding == "Others") {
        matchBuilding = !_buildings.contains(c.buildingName.trim());
      } else {
        matchBuilding = c.buildingName.trim() == selectedBuilding;
      }
      bool matchTime = true;
      if (selectedTimeFrame == "Today") matchTime = _isSameDay(c.createdAt, DateTime.now());
      if (selectedTimeFrame == "Yesterday") matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
      if (selectedTimeFrame == "Select Date" && customDate != null) matchTime = _isSameDay(c.createdAt, customDate!);
      return matchViewType && matchBuilding && matchTime;
    }).toList();
    for (var s in _statusOptions) {
      map[s] = baseFiltered.where((c) => c.status == s).length;
    }
    map["StatusAll"] = baseFiltered.length;
    map["ActiveView"] = all.where((c) => c.isDeleted != true).length;
    map["DeletedView"] = all.where((c) => c.isDeleted == true).length;
    map["AllView"] = all.length;
    return map;
  }
  Widget _buildFilterBar(Map<String, int> counts) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterRow("Status", _statusOptions, counts),
          const SizedBox(height: 4),
          _buildBuildingDropdownRow(),
          const SizedBox(height: 4),
          _buildFilterRow("Record Type", ["All", "Active", "Deleted"], counts),
          _buildFilterRow("Time", ["All", "Today", "Yesterday", "Select Date"], counts),
        ],
      ),
    );
  }

  Widget _buildBuildingDropdownRow() {
    String safeValue = _buildings.contains(selectedBuilding) ? selectedBuilding : "All";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        children: [
          const SizedBox(
            width: 75,
            child: Text("Building:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey.shade50,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: safeValue,
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                  items: _buildings.map((b) {
                    return DropdownMenuItem<String>(
                      value: b,
                      child: Text(b, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedBuilding = val;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(String label, List<String> opts, Map<String, int> counts) {
    return SizedBox(
      height: 45,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: opts.length,
          itemBuilder: (context, i) {
            String opt = opts[i];
            String displayLabel = opt;
            
            if (label == "Status") {
              int n = (opt == "All") ? (counts["StatusAll"] ?? 0) : (counts[opt] ?? 0);
              displayLabel = "$opt $n";
            } else if (label == "Record Type") {
              int n = (opt == "All") ? (counts["AllView"] ?? 0) : (opt == "Active" ? (counts["ActiveView"] ?? 0) : (counts["DeletedView"] ?? 0));
              displayLabel = "$opt $n";
            }
            bool isSelected = (label == "Status" && selectedStatus == opt) ||
                              (label == "Record Type" && selectedViewType == opt) ||
                              (label == "Time" && selectedTimeFrame == opt);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ChoiceChip(
                label: Text(opt == "Select Date" && customDate != null ? DateFormat('dd/MM').format(customDate!) : displayLabel, style: const TextStyle(fontSize: 11)),
                selected: isSelected,
                selectedColor: Colors.red.shade900,
                labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 11),
                onSelected: (val) async {
                  if (!val) return;
                  if (opt == "Select Date") {
                    DateTime? d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2025), lastDate: DateTime.now());
                    if (d != null) setState(() { selectedTimeFrame = "Select Date"; customDate = d; });
                  } else {
                    setState(() {
                      if (label == "Status") selectedStatus = opt;
                      if (label == "Record Type") selectedViewType = opt;
                      if (label == "Time") selectedTimeFrame = opt;
                    });
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
  Widget _buildActionRow(List<Complaint> all) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text("Count: ${all.length}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showExportRangeDialog(all),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text("Export by Date"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }
  Widget _buildFilteredList(List<Complaint> all, ComplaintService service) {
    final filtered = all.where((c) {
      bool matchViewType = true;
      if (selectedViewType == "Active") matchViewType = (c.isDeleted != true);
      if (selectedViewType == "Deleted") matchViewType = (c.isDeleted == true);
      bool matchStatus = selectedStatus == "All" || c.status.trim().toLowerCase() == selectedStatus.toLowerCase();
      bool matchBuilding = false;
      if (selectedBuilding == "All") {
        matchBuilding = true;
      } else if (selectedBuilding == "Others") {
        matchBuilding = !_buildings.contains(c.buildingName.trim());
      } else {
        matchBuilding = c.buildingName.trim() == selectedBuilding;
      }
      bool matchTime = true;
      if (selectedTimeFrame == "Today") matchTime = _isSameDay(c.createdAt, DateTime.now());
      if (selectedTimeFrame == "Yesterday") matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
      if (selectedTimeFrame == "Select Date" && customDate != null) matchTime = _isSameDay(c.createdAt, customDate!);
      return matchViewType && matchStatus && matchBuilding && matchTime;
    }).toList();
    return ListView.builder(
      itemCount: filtered.length,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (context, i) {
        final c = filtered[i];
        bool isLocked = c.status == "Resolved" || c.status == "Closed by Customer";
        bool isStandby = c.status == "Standby";
        bool isDeleted = c.isDeleted == true;
        String displayBuilding = c.buildingName;
        String displayComplaint = (c.complaintType == "Others" || !_complaintTypes.contains(c.complaintType))
            ? "${c.description} (Other)" 
            : c.complaintType;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    "$displayBuilding - Flat ${c.flatNumber}${isDeleted ? ' (DELETED)' : ''}", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDeleted ? Colors.red.shade900 : Colors.black
                    )
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Issue: $displayComplaint"),
                      const SizedBox(height: 2),
                      Text("ID: ${c.id}", style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blueGrey)),
                      if (isStandby) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50, 
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade200)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("REASON: ${c.standbyReason}", 
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown)),
                              const SizedBox(height: 4),
                              Text("Technician: ${c.standbyBy ?? 'N/A'}",
                                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange.shade900)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(DateFormat('dd MMM, hh:mm a').format(c.createdAt), 
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDeleted 
                        ? Colors.red.shade50 
                        : (isLocked ? Colors.grey.shade200 : (isStandby ? Colors.orange.shade100 : Colors.blue.shade100)),
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(isDeleted ? "DELETED" : c.status, style: TextStyle(
                      color: isDeleted 
                        ? Colors.red.shade900 
                        : (isLocked ? Colors.grey.shade700 : (isStandby ? Colors.orange.shade900 : Colors.blue.shade900)),
                      fontWeight: FontWeight.bold,
                      fontSize: 11
                    )),
                  ),
                  onTap: () => _showAuditEditDialog(context, service, c),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.image, size: 14, color: Colors.indigo),
                          label: const Text("See Images", style: TextStyle(fontSize: 11, color: Colors.indigo)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.indigo.shade700),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showMediaDialog(context, c),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.history_edu, size: 14, color: Colors.teal),
                          label: const Text("Flat History", style: TextStyle(fontSize: 11, color: Colors.teal)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.teal.shade700),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showFlatHistoryDialog(context, service, c.buildingName, c.flatNumber),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 14, color: Colors.white),
                          label: const Text("Master Report", style: TextStyle(fontSize: 11, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _generateMasterServiceReportPdf(context, service, c),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showFlatHistoryDialog(BuildContext context, ComplaintService service, String building, String flatNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Flat History ($building - Flat $flatNumber)"),
        content: SizedBox(
          width: 500,
          height: 400,
          child: StreamBuilder<List<Complaint>>(
            stream: service.getAdminFullHistory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No previous complaints found for this flat."));
              }
              
              final historyList = snapshot.data!.where((c) => 
                c.buildingName.trim().toLowerCase() == building.trim().toLowerCase() && 
                c.flatNumber.trim().toLowerCase() == flatNumber.trim().toLowerCase()
              ).toList();
              if (historyList.isEmpty) {
                return const Center(child: Text("No previous complaints found for this flat."));
              }
              return ListView.builder(
                itemCount: historyList.length,
                itemBuilder: (context, index) {
                  final pastComplaint = historyList[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text("${pastComplaint.complaintType} - ${pastComplaint.status}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text(
                        "Date: ${_formatDate(pastComplaint.createdAt)}\nTech: ${pastComplaint.technicianName ?? 'N/A'}\nRemarks: ${pastComplaint.finalRemarks.isNotEmpty ? pastComplaint.finalRemarks : 'None'}",
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  );
                },
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
  void _showTimelineHistoryDialog(BuildContext context, Complaint c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Timeline History (${c.id})"),
        content: SizedBox(
          width: 450,
          height: 350,
          child: c.timelineLogs.isEmpty
              ? const Center(
                  child: Text(
                    "No historical logs recorded yet.\n(Logs will appear here for new status changes & multiple technician starts).",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: c.timelineLogs.length,
                  itemBuilder: (context, index) {
                    final log = c.timelineLogs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 1,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.access_time_filled, size: 20, color: Colors.indigo),
                        title: Text(
                          "${log['status'] ?? 'Update'} - By: ${log['userName'] ?? 'N/A'}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        subtitle: Text(
                          "Time: ${log['timestamp'] != null ? _formatDate(DateTime.parse(log['timestamp'])) : 'N/A'}\nRemarks: ${log['remarks'] ?? 'None'}",
                          style: const TextStyle(fontSize: 11),
                        ),
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
  void _showAuditEditDialog(BuildContext context, ComplaintService service, Complaint c) {
    final flatCtrl = TextEditingController(text: c.flatNumber);
    final descCtrl = TextEditingController(text: c.description);
    final reportNoCtrl = TextEditingController(text: c.serviceReportNumber);
    final materialsCtrl = TextEditingController(text: c.materialsUsed);
    
    bool exists = _buildings.contains(c.buildingName.trim());
    String currentBuilding = exists ? c.buildingName.trim() : "Others";
    
    String currentStatus = _statusOptions.contains(c.status) ? c.status : "Pending";
    String currentType = _complaintTypes.contains(c.complaintType) ? c.complaintType : "Others";
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text("Audit: ${c.id}", style: const TextStyle(fontSize: 16)),
              ),
              if(c.isDeleted == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                  child: const Text("DELETED", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _auditHeader("COMPLAINT OVERVIEW"),
                  _auditRow("Registered", _formatDate(c.createdAt), c.customerName),
                  if(c.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text("📝 ${c.description}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                    ),
                 
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.history, size: 18),
                      label: Text("View Complete Status History (${c.timelineLogs.length} entries)"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showTimelineHistoryDialog(context, c),
                    ),
                  ),
                  if (c.isDeleted == true) ...[
                    const SizedBox(height: 10),
                    _remarksBox("Deletion Reason", c.deleteRemarks ?? "No reason provided", Colors.red),
                  ],
                  if (c.isDeleted != true) ...[
                    const Divider(height: 30),
                    _auditHeader("ADMIN OVERRIDE"),
                    DropdownButtonFormField<String>(
                      value: currentStatus,
                      items: _statusOptions.where((e) => e != "All").map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setDialogState(() => currentStatus = v!),
                      decoration: const InputDecoration(labelText: "Change Status", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: reportNoCtrl, decoration: const InputDecoration(labelText: "Report #", border: OutlineInputBorder()))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: materialsCtrl, decoration: const InputDecoration(labelText: "Materials", border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: currentBuilding,
                      items: _buildings.where((e) => e != "All").map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setDialogState(() => currentBuilding = v!),
                      decoration: InputDecoration(
                        labelText: "Building", 
                        border: const OutlineInputBorder(),
                        helperText: currentBuilding == "Others" ? "Database Name: ${c.buildingName}" : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: flatCtrl, decoration: const InputDecoration(labelText: "Flat Number", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: currentType,
                      items: _complaintTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setDialogState(() => currentType = v!),
                      decoration: const InputDecoration(labelText: "Complaint Type", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Edit Description", border: OutlineInputBorder())),
                  ]
                ],
              ),
            ),
          ),
          actions: [
            if (c.isDeleted == true)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                onPressed: () async {
                  await service.updateComplaint(c.copyWith(isDeleted: false, deleteRemarks: ""));
                  Navigator.pop(context);
                }, 
                icon: const Icon(Icons.restore),
                label: const Text("RESTORE"),
              ),
            if (c.isDeleted != true)
              TextButton(onPressed: () => _showDeleteConfirm(context, service, c), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
            if (c.isDeleted != true)
              ElevatedButton(
                onPressed: () async {
                  String finalBuilding = (currentBuilding == "Others") ? c.buildingName : currentBuilding;
                  List<Map<String, dynamic>> updatedLogs = List.from(c.timelineLogs);
                  if (c.status != currentStatus) {
                    updatedLogs.add({
                      'timestamp': DateTime.now().toIso8601String(),
                      'status': currentStatus,
                      'userName': 'Admin Override',
                      'remarks': 'Status changed from ${c.status} to $currentStatus'
                    });
                  }
                  await service.updateComplaint(c.copyWith(
                    buildingName: finalBuilding,
                    flatNumber: flatCtrl.text.trim(),
                    complaintType: currentType,
                    description: descCtrl.text.trim(),
                    status: currentStatus,
                    serviceReportNumber: reportNoCtrl.text.trim(),
                    materialsUsed: materialsCtrl.text.trim(),
                    timelineLogs: updatedLogs,
                  ));
                  Navigator.pop(context);
                },
                child: const Text("SAVE CHANGES"),
              )
          ],
        ),
      ),
    );
  }
  Widget _auditHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade900)),
    );
  }
  Widget _auditRow(String label, String val1, String val2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 12),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          Expanded(child: Text("$val1 ($val2)", style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
  Widget _remarksBox(String title, String content, MaterialColor color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color.shade900)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
  void _showDeleteConfirm(BuildContext context, ComplaintService service, Complaint c) {
    final deleteReasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for deleting this complaint record:"),
            const SizedBox(height: 10),
            TextField(
              controller: deleteReasonCtrl,
              decoration: const InputDecoration(labelText: "Deletion Reason", border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (deleteReasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a deletion reason")));
                return;
              }
              await service.updateComplaint(c.copyWith(
                isDeleted: true,
                deleteRemarks: deleteReasonCtrl.text.trim(),
              ));
              Navigator.pop(context); // Close delete confirm
              Navigator.pop(context); // Close audit dialog
            },
            child: const Text("DELETE RECORD"),
          ),
        ],
      ),
    );
  }
}