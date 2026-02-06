import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html; 
import 'dart:convert';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // --- Filter State Variables (Same as Technician) ---
  String selectedStatus = "All";
  String selectedBuilding = "All";
  String selectedTimeFrame = "All";
  DateTime? customDate;
  bool showDeletedOnly = false;

  final List<String> _complaintTypes = ["Water leakage", "Low cooling", "Smell coming from AC", "Sound coming from AC", "Cleaning/Service", "New rent out", "Low air speed", "Low fan speed", "AC fan not working", "Others"];
  
  // Dynamic building list for filters
  final List<String> _filterBuildings = ["All", ...List.generate(26, (i) => "Building ${i + 1}"), "Others"];
  // Static building list for the Edit Dialog
  final List<String> _editBuildings = List.generate(26, (i) => "Building ${i + 1}")..add("Others");

  String _formatDate(DateTime? date) => 
      date != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(date) : "N/A";

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  void _downloadFilteredReport(List<Complaint> allComplaints) {
    // Apply filters to export data too
    final filteredData = _applyFilters(allComplaints);

    String csv = 'ID,Reg_Time,Building,Flat,Type,Customer_Remarks,'
                  'Started_By,Start_Time,'
                  'Standby_By,Standby_Time,Standby_Reason,'
                  'Closed_By,Close_Time,Final_Remarks,Serial_No,Status,Deleted,Delete_Remarks\n';
    
    for (var c in filteredData) {
      final dynamic dc = c; 
      csv += '"${c.id}",'
          '${_formatDate(c.createdAt)},'
          '"${c.buildingName}",'
          '"${c.flatNumber}",'
          '"${c.complaintType}",'
          '"${c.description.replaceAll('\n', ' ')}",'
          '"${c.technicianName ?? 'N/A'}",' 
          '${_formatDate(c.startTime)},'
          '"${dc.standbyBy ?? 'N/A'}",' 
          '${_formatDate(c.standbyTime)},'
          '"${(c.standbyReason).replaceAll('\n', ' ')}",' 
          '"${c.closedBy ?? 'N/A'}",' 
          '${_formatDate(c.completedAt)},'
          '"${(dc.finalRemarks ?? 'N/A').replaceAll('\n', ' ')}",' 
          '"${c.serviceReportNumber ?? 'N/A'}",'
          '"${c.status}",'
          '${c.isDeleted == true ? "YES" : "NO"},'
          '"${(c.deleteRemarks ?? '').replaceAll('\n', ' ')}"\n';
    }

    final bytes = utf8.encode(csv);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Audit_Report_${DateTime.now().millisecondsSinceEpoch}.csv")
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // Logic to filter the list (Shared between View and Export)
  List<Complaint> _applyFilters(List<Complaint> allData) {
    return allData.where((c) {
      // 1. Deletion Filter
      bool matchDeleted = showDeletedOnly ? (c.isDeleted == true) : (c.isDeleted != true);
      
      // 2. Status Filter
      bool matchStatus = selectedStatus == "All" ||
          c.status.trim().toLowerCase() == selectedStatus.toLowerCase();
      
      // 3. Building Filter
      bool matchBuilding = selectedBuilding == "All" ||
          c.buildingName.trim() == selectedBuilding;
      
      // 4. Time Filter
      bool matchTime = true;
      if (selectedTimeFrame == "Today") {
        matchTime = _isSameDay(c.createdAt, DateTime.now());
      } else if (selectedTimeFrame == "Yesterday") {
        matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
      } else if (selectedTimeFrame == "Select Date" && customDate != null) {
        matchTime = _isSameDay(c.createdAt, customDate!);
      }

      return matchDeleted && matchStatus && matchBuilding && matchTime;
    }).toList();
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
              selectedStatus = "All";
              selectedBuilding = "All";
              selectedTimeFrame = "All";
              customDate = null;
              showDeletedOnly = false;
            }),
            tooltip: "Reset Filters",
          )
        ],
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: service.getAdminFullHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final all = snapshot.data!;
          
          return Column(
            children: [
              _buildFilterBar(), // Same bar as Technician
              _topActionRow(all), // Deletion Toggle and Export
              const Divider(height: 1),
              Expanded(child: _buildFilteredList(all, service)),
            ],
          );
        },
      ),
    );
  }

  // --- Filter Bar UI (Same as Technician) ---
  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildRow("Status", ["All", "Pending", "In Progress", "Standby", "Resolved", "Closed by Customer"]),
          _buildRow("Building", _filterBuildings),
          _buildRow("Time", ["All", "Today", "Yesterday", "Select Date"]),
        ],
      ),
    );
  }

  Widget _buildRow(String label, List<String> opts) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: opts.length,
        itemBuilder: (context, i) {
          String opt = opts[i];
          bool isSelected = false;
          if (label == "Status") isSelected = selectedStatus == opt;
          if (label == "Building") isSelected = selectedBuilding == opt;
          if (label == "Time") isSelected = selectedTimeFrame == opt;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(opt == "Select Date" && customDate != null
                  ? DateFormat('dd/MM').format(customDate!)
                  : opt, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              selectedColor: Colors.red.shade900,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
              onSelected: (val) async {
                if (!val) return;
                if (opt == "Select Date") {
                  DateTime? d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now());
                  if (d != null) setState(() { selectedTimeFrame = "Select Date"; customDate = d; });
                } else {
                  setState(() {
                    if (label == "Status") selectedStatus = opt;
                    if (label == "Building") selectedBuilding = opt;
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

  Widget _topActionRow(List<Complaint> all) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          FilterChip(
            label: Text(showDeletedOnly ? "VIEWING: DELETED" : "VIEWING: ACTIVE"),
            selected: showDeletedOnly,
            selectedColor: Colors.red.shade100,
            onSelected: (v) => setState(() => showDeletedOnly = v),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _downloadFilteredReport(all),
            icon: const Icon(Icons.file_download),
            label: const Text("Export CSV"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  Widget _buildFilteredList(List<Complaint> all, ComplaintService service) {
    final filtered = _applyFilters(all);

    if (filtered.isEmpty) {
      return const Center(child: Text("No complaints match these filters."));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final c = filtered[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: c.isDeleted == true ? Colors.red : Colors.blue, 
              child: Icon(c.isDeleted == true ? Icons.delete : Icons.build, color: Colors.white, size: 18)
            ),
            title: Text("${c.buildingName} - Flat ${c.flatNumber}"),
            subtitle: Text("Status: ${c.status} | ${DateFormat('dd MMM').format(c.createdAt)}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showAuditEditDialog(context, service, c),
          ),
        );
      },
    );
  }

  // --- Rest of your Audit Dialog & Deletion logic remains identical ---
  // (Assuming _showAuditEditDialog, _showDeleteConfirm, etc. follow here)
  
  void _showAuditEditDialog(BuildContext context, ComplaintService service, Complaint c) {
    final flatCtrl = TextEditingController(text: c.flatNumber);
    final descCtrl = TextEditingController(text: c.description);
    String? currentBuilding = _editBuildings.contains(c.buildingName) ? c.buildingName : _editBuildings.last;
    String? currentType = _complaintTypes.contains(c.complaintType) ? c.complaintType : _complaintTypes.last;
    final dynamic dc = c;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Audit Log: ${c.id.substring(0,8)}"),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _auditHeader("TIMELINE & ACCOUNTABILITY"),
                  _auditRow("Registered By", _formatDate(c.createdAt), c.customerName),
                  _auditRow("Started By", _formatDate(c.startTime), c.technicianName ?? "N/A"),
                  _auditRow("Put on Standby", _formatDate(c.standbyTime), dc.standbyBy ?? "N/A"),
                  _auditRow("Resolved By", _formatDate(c.completedAt), c.closedBy ?? "N/A"),
                  
                  if (c.isDeleted == true) ...[
                    const SizedBox(height: 10),
                    _remarksBox("DELETION REMARKS", c.deleteRemarks ?? "No reason provided", Colors.red),
                  ],

                  const SizedBox(height: 15),
                  _remarksBox("Standby Reason", c.standbyReason, Colors.orange.shade700),
                  const SizedBox(height: 10),
                  _remarksBox("Final Closing Remarks", dc.finalRemarks ?? "N/A", Colors.green.shade700),
                  
                  if (c.isDeleted != true) ...[
                    const Divider(height: 40),
                    _auditHeader("ADMIN OVERRIDE"),
                    DropdownButtonFormField<String>(
                      value: currentBuilding,
                      decoration: const InputDecoration(labelText: "Building Name", border: OutlineInputBorder()),
                      items: _editBuildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (val) => setDialogState(() => currentBuilding = val),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: flatCtrl, decoration: const InputDecoration(labelText: "Flat Number", border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: currentType,
                      decoration: const InputDecoration(labelText: "Complaint Type", border: OutlineInputBorder()),
                      items: _complaintTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setDialogState(() => currentType = val),
                    ),
                    const SizedBox(height: 15),
                    TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
                  ]
                ],
              ),
            ),
          ),
          actions: [
            if (c.isDeleted != true) 
              TextButton(
                onPressed: () => _showDeleteConfirm(context, service, c),
                child: const Text("DELETE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
            if (c.isDeleted != true)
              ElevatedButton(
                onPressed: () async {
                  await service.updateComplaint(c.copyWith(buildingName: currentBuilding, flatNumber: flatCtrl.text, complaintType: currentType, description: descCtrl.text));
                  Navigator.pop(context);
                },
                child: const Text("SAVE CHANGES"),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, ComplaintService service, Complaint c) {
    final delRemarks = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: TextField(controller: delRemarks, decoration: const InputDecoration(labelText: "Reason for deletion", hintText: "Enter reason...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BACK")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await service.updateComplaint(c.copyWith(isDeleted: true, deleteRemarks: delRemarks.text));
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: const Text("CONFIRM DELETE", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _remarksBox(String title, String content, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: accentColor.withOpacity(0.05), border: Border(left: BorderSide(color: accentColor, width: 4)), borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor)),
        const SizedBox(height: 4),
        Text(content.isEmpty ? "No data" : content, style: const TextStyle(fontSize: 13)),
      ]),
    );
  }

  Widget _auditHeader(String title) => Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)));

  Widget _auditRow(String label, String time, String name) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text("$label:", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text("$time ($name)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]));
  }
}