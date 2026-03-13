import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:csv/csv.dart';

// Standard Flutter way to check for web without crashing mobile
import 'package:flutter/foundation.dart' show kIsWeb;

// This is the trick: We only import html on web. 
// On mobile, this variable will just be null and ignored.
import 'dart:html' as html if (dart.library.io) 'package:flutter/material.dart'; 

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Filter States
  String selectedStatus = "All";
  String selectedBuilding = "All";
  String selectedTimeFrame = "All";
  String selectedViewType = "Active"; 
  DateTime? customDate;

  final List<String> _complaintTypes = [
    "Water leakage", "Low cooling", "Smell coming from AC", 
    "Sound coming from AC", "Cleaning/Service", "New rent out", 
    "Low air speed", "Low fan speed", "AC fan not working", "Others"
  ];

  final List<String> _buildings = [
    "All", "Expo Tower", "Mazaya", "Yasmeen Tower", "Gate Tower 1", "Gate Tower 2", "Galleria Mall", 
    "Al Khor Tower C", "Al Tameer", "Rital & Rinad", "Tallah Mall",
    "Al Khor Mall", "Jodi 1", "Jodi 2", "Jodi 3", "Falcon Jodi 5",
    "Naseem", "Nada building", "Hala Building", "Ajman Club",
    "Salah Ud Din", "Sara Plaza 3", "Jurf 2", "Flower Shop",
    "Amina Hospital", "Villas", "Sharjah", "Others"
  ];

  final List<String> _statusOptions = [
    "All", "Pending", "In Progress", "Standby", "Resolved", "Closed by Customer"
  ];

  String _formatDate(DateTime? date) => 
      date != null ? DateFormat('yyyy-MM-dd HH:mm').format(date) : "N/A";

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  // --- Export Logic ---
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

      // Logic for "Other" Building and Complaint Type in Export
      String displayBuilding = (c.buildingName == "Others" || !_buildings.contains(c.buildingName)) ? c.buildingName : c.buildingName;
      String displayType = (c.complaintType == "Others" || !_complaintTypes.contains(c.complaintType)) ? "${c.description} (Other)" : c.complaintType;

      rows.add([
        c.id.substring(0, (c.id.length > 8 ? 8 : c.id.length)),
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
        c.materialsUsed ?? 'N/A',
        c.finalRemarks.replaceAll('\n', ' ')
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    
    // SAFE WEB DOWNLOAD BLOCK
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

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Master Admin Dashboard"),
        backgroundColor: Colors.red.shade900,
        actions: [
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
    for (var s in _statusOptions) {
      map[s] = all.where((c) => c.status == s && c.isDeleted != true).length;
    }
    map["StatusAll"] = all.where((c) => c.isDeleted != true).length;
    map["ActiveView"] = all.where((c) => c.isDeleted != true).length;
    map["DeletedView"] = all.where((c) => c.isDeleted == true).length;
    map["AllView"] = all.length;
    return map;
  }

  Widget _buildFilterBar(Map<String, int> counts) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _buildFilterRow("Status", _statusOptions, counts),
          _buildFilterRow("Building", _buildings, counts),
          _buildFilterRow("Record Type", ["All", "Active", "Deleted"], counts),
          _buildFilterRow("Time", ["All", "Today", "Yesterday", "Select Date"], counts),
        ],
      ),
    );
  }

  Widget _buildFilterRow(String label, List<String> opts, Map<String, int> counts) {
    return SizedBox(
      height: 40,
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
                            (label == "Building" && selectedBuilding == opt) ||
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
                    if (label == "Building") selectedBuilding = opt;
                    if (label == "Record Type") selectedViewType = opt;
                    if (label == "Time") selectedTimeFrame = opt;
                  });
                }
              },
            ),
          );
        },
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

        // Display Logic for "Others"
        String displayBuilding = c.buildingName;
        String displayComplaint = (c.complaintType == "Others" || !_complaintTypes.contains(c.complaintType)) 
            ? "${c.description} (Other)" 
            : c.complaintType;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: ListTile(
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
        );
      },
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

    bool isCustomerClosed = c.status == "Closed by Customer";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Audit: ${c.id.substring(0, c.id.length > 8 ? 8 : c.id.length)}"),
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
                  _auditHeader("TIMELINE"),
                  _auditRow("Registered", _formatDate(c.createdAt), c.customerName),
                  if(c.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text("📝 ${c.description}", style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
                    ),
                  
                  _auditRow("Started", _formatDate(c.startTime), c.technicianName ?? "N/A"),
                  _auditRow("Standby", _formatDate(c.standbyTime), c.standbyBy ?? "N/A"),
                  if(c.standbyReason.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 8),
                      child: Text("⏳ Reason: ${c.standbyReason}", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange.shade900)),
                    ),
                  
                  _auditRow(isCustomerClosed ? "Closed by User" : "Resolved", _formatDate(c.completedAt), isCustomerClosed ? c.customerName : (c.closedBy ?? "N/A")),
                  
                  if (!isCustomerClosed && (c.serviceReportNumber != null || c.materialsUsed != null)) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if(c.serviceReportNumber != null) Text("📄 Report #: ${c.serviceReportNumber}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                          if(c.materialsUsed != null) Text("🛠 Materials: ${c.materialsUsed}", style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 15),
                  _remarksBox("Final Remarks", c.finalRemarks, isCustomerClosed ? Colors.red : Colors.green),
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
                  await service.updateComplaint(c.copyWith(
                    status: currentStatus, 
                    buildingName: finalBuilding, 
                    flatNumber: flatCtrl.text,
                    complaintType: currentType, 
                    description: descCtrl.text,
                    serviceReportNumber: reportNoCtrl.text,
                    materialsUsed: materialsCtrl.text,
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

  void _showDeleteConfirm(BuildContext context, ComplaintService service, Complaint c) {
    final delRemarks = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Delete Complaint?"),
      content: TextField(controller: delRemarks, decoration: const InputDecoration(labelText: "Reason for deletion")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
          onPressed: () async {
            await service.updateComplaint(c.copyWith(isDeleted: true, deleteRemarks: delRemarks.text));
            Navigator.pop(context); Navigator.pop(context);
          }, child: const Text("CONFIRM DELETE", style: TextStyle(color: Colors.white)))
      ],
    ));
  }

  Widget _remarksBox(String title, String content, Color col) => Container(
    width: double.infinity, padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: col.withOpacity(0.05), border: Border(left: BorderSide(color: col, width: 4)), borderRadius: BorderRadius.circular(4)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: col)),
      Text(content.isEmpty ? "No data" : content, style: const TextStyle(fontSize: 12)),
    ]),
  );

  Widget _auditHeader(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)));

  Widget _auditRow(String label, String time, String name) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("$label:", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text("$time ($name)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    ],
  ));
}