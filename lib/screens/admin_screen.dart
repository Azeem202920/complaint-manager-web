import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html; 
import 'dart:convert';
import 'package:csv/csv.dart'; // Standardized CSV handling

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
    "All", "Expo Tower", "Gate Tower 1", "Gate Tower 2", "Galleria Mall", 
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
    // Filter data based on the dates AND the currently selected View Type (Active/Deleted)
    final exportData = allComplaints.where((c) {
      bool dateMatch = c.createdAt.isAfter(range.start) && 
                       c.createdAt.isBefore(range.end.add(const Duration(days: 1)));
      
      bool viewMatch = true;
      if (selectedViewType == "Active") viewMatch = (c.isDeleted != true);
      if (selectedViewType == "Deleted") viewMatch = (c.isDeleted == true);
      
      return dateMatch && viewMatch;
    }).toList();

    List<List<dynamic>> rows = [];
    
    // Header Row
    rows.add([
      "ID", "Building", "Flat", "Type", "Status", 
      "Registered_By", "Reg_Time", 
      "Started_By", "Start_Time", 
      "Standby_By", "Standby_Time", "Standby_Remarks", 
      "Closed_By", "Close_Time", "Serial_No", "Closing_Remarks"
    ]);

    for (var c in exportData) {
      bool isCustomerClosed = c.status == "Closed by Customer";
      String closerName = isCustomerClosed ? (c.customerName) : (c.closedBy ?? 'N/A');
      String serialNo = isCustomerClosed ? 'N/A' : (c.serviceReportNumber ?? 'N/A');
      
      // The Status Fix: If deleted, prefix the status so it's not confused with live Pending
      String displayStatus = c.isDeleted == true ? "DELETED (${c.status})" : c.status;

      rows.add([
        c.id.substring(0, 8),
        c.buildingName,
        c.flatNumber,
        c.complaintType,
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
        c.finalRemarks.replaceAll('\n', ' ')
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csvData);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Detailed_Report_${DateFormat('dd_MM_yy').format(range.start)}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          
          // Calculate counts for buttons
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
    // Counts for Status (Only Active ones)
    for (var s in _statusOptions) {
      map[s] = all.where((c) => c.status == s && c.isDeleted != true).length;
    }
    map["StatusAll"] = all.where((c) => c.isDeleted != true).length;

    // Counts for View Types
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
          
          // Label formatting with counts
          String displayLabel = opt;
          if (label == "Status") {
            int n = (opt == "All") ? (counts["StatusAll"] ?? 0) : (counts[opt] ?? 0);
            displayLabel = "$opt $n";
          } else if (label == "Record Type") {
            int n = (opt == "All") ? (counts["AllView"] ?? 0) : (opt == "Active" ? counts["ActiveView"]! : counts["DeletedView"]!);
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

      bool matchStatus = selectedStatus == "All" || c.status.toLowerCase() == selectedStatus.toLowerCase();
      bool matchBuilding = selectedBuilding == "All" || c.buildingName == selectedBuilding;
      bool matchTime = true;
      if (selectedTimeFrame == "Today") matchTime = _isSameDay(c.createdAt, DateTime.now());
      if (selectedTimeFrame == "Yesterday") matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
      if (selectedTimeFrame == "Select Date" && customDate != null) matchTime = _isSameDay(c.createdAt, customDate!);

      return matchViewType && matchStatus && matchBuilding && matchTime;
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final c = filtered[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: c.isDeleted == true ? Colors.grey : Colors.blue, 
              child: Icon(c.isDeleted == true ? Icons.delete_forever : Icons.build, color: Colors.white, size: 16)
            ),
            title: Text("${c.buildingName} - ${c.flatNumber}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text("Status: ${c.status} | ${c.complaintType}${c.isDeleted == true ? ' (DELETED)' : ''}"),
            onTap: () => _showAuditEditDialog(context, service, c),
          ),
        );
      },
    );
  }

  void _showAuditEditDialog(BuildContext context, ComplaintService service, Complaint c) {
    final flatCtrl = TextEditingController(text: c.flatNumber);
    final descCtrl = TextEditingController(text: c.description);
    String? currentBuilding = _buildings.contains(c.buildingName) ? c.buildingName : "Others";
    String? currentStatus = _statusOptions.contains(c.status) ? c.status : "Pending";
    String? currentType = _complaintTypes.contains(c.complaintType) ? c.complaintType : "Others";

    bool isCustomerClosed = c.status == "Closed by Customer";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Audit: ${c.id.substring(0,8)}"),
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
                  _auditRow("Started", _formatDate(c.startTime), c.technicianName ?? "N/A"),
                  _auditRow("Standby", _formatDate(c.standbyTime), c.standbyBy ?? "N/A"),
                  _auditRow(
                    isCustomerClosed ? "Closed by User" : "Resolved", 
                    _formatDate(c.completedAt), 
                    isCustomerClosed ? c.customerName : (c.closedBy ?? "N/A")
                  ),
                  const SizedBox(height: 10),
                  _remarksBox("User Description", c.description, Colors.blue),
                  const SizedBox(height: 10),
                  if (c.isDeleted == true)
                    _remarksBox("Deletion Reason", c.deleteRemarks ?? "No reason provided", Colors.red),
                  const SizedBox(height: 10),
                  _remarksBox("Standby Reason", c.standbyReason, Colors.orange),
                  const SizedBox(height: 10),
                  _remarksBox(
                    isCustomerClosed ? "Customer Closing Note" : "Final Remarks", 
                    c.finalRemarks, 
                    isCustomerClosed ? Colors.red : Colors.green
                  ),
                  if (c.isDeleted != true) ...[
                    const Divider(height: 30),
                    _auditHeader("ADMIN OVERRIDE"),
                    DropdownButtonFormField<String>(
                      value: currentStatus,
                      items: _statusOptions.where((e) => e != "All").map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setDialogState(() => currentStatus = v),
                      decoration: const InputDecoration(labelText: "Change Status", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: currentBuilding,
                      items: _buildings.where((e) => e != "All").map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setDialogState(() => currentBuilding = v),
                      decoration: const InputDecoration(labelText: "Building", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: flatCtrl, decoration: const InputDecoration(labelText: "Flat Number", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: currentType,
                      items: _complaintTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setDialogState(() => currentType = v),
                      decoration: const InputDecoration(labelText: "Complaint Type", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl, 
                      maxLines: 2, 
                      decoration: const InputDecoration(labelText: "Edit Description", border: OutlineInputBorder())
                    ),
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complaint Restored")));
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
                  String finalStatus = currentStatus ?? c.status;
                  Complaint updated = c.copyWith(
                    status: finalStatus, 
                    buildingName: currentBuilding, 
                    flatNumber: flatCtrl.text,
                    complaintType: currentType,
                    description: descCtrl.text,
                  );

                  if (finalStatus != c.status) {
                    if (finalStatus == "In Progress") {
                      updated = updated.copyWith(startTime: DateTime.now(), technicianName: "Admin Override");
                    } else if (finalStatus == "Standby") {
                      updated = updated.copyWith(standbyTime: DateTime.now(), standbyBy: "Admin", standbyReason: "Moved to Standby by Admin");
                    } else if (finalStatus == "Resolved") {
                      updated = updated.copyWith(completedAt: DateTime.now(), closedBy: "Admin", finalRemarks: "Resolved by Admin override", serviceReportNumber: "ADMIN-FIX");
                    }
                  }

                  await service.updateComplaint(updated);
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