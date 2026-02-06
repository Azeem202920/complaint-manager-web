import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'home_screen.dart';

class TechnicianScreen extends StatefulWidget {
  const TechnicianScreen({super.key});

  @override
  State<TechnicianScreen> createState() => _TechnicianScreenState();
}

class _TechnicianScreenState extends State<TechnicianScreen> {
  String selectedStatus = "All";
  String selectedBuilding = "All";
  String selectedTimeFrame = "All";
  DateTime? customDate;

  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      await HomeScreen.logout(context);
    }
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Technician Portal"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
          onPressed: () => _handleLogout(context),
          tooltip: "Logout",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_off),
            onPressed: () => setState(() {
              selectedStatus = "All";
              selectedBuilding = "All";
              selectedTimeFrame = "All";
              customDate = null;
            }),
            tooltip: "Reset Filters",
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Complaint>>(
              stream: service.getAdminFullHistory(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final allData = snapshot.data ?? [];
                if (allData.isEmpty) {
                  return const Center(child: Text("No complaints found."));
                }

                final filteredList = allData.where((c) {
                  if (c.isDeleted == true) return false;
                  bool matchStatus = selectedStatus == "All" ||
                      c.status.trim().toLowerCase() == selectedStatus.toLowerCase();
                  bool matchBuilding = selectedBuilding == "All" ||
                      c.buildingName.trim() == selectedBuilding;
                  bool matchTime = true;
                  if (selectedTimeFrame == "Today") {
                    matchTime = _isSameDay(c.createdAt, DateTime.now());
                  } else if (selectedTimeFrame == "Yesterday") {
                    matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
                  } else if (selectedTimeFrame == "Select Date" && customDate != null) {
                    matchTime = _isSameDay(c.createdAt, customDate!);
                  }
                  return matchStatus && matchBuilding && matchTime;
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) => _buildCard(context, service, filteredList[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          _buildRow("Status", ["All", "Pending", "In Progress", "Standby", "Resolved"]),
          _buildRow("Building", ["All", "Building A", "Building B", "Building C"]),
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
              selectedColor: Colors.blue,
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

  Widget _buildCard(BuildContext context, ComplaintService service, Complaint c) {
    bool isLocked = c.status == "Resolved" || c.status == "Closed by Customer";
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text("${c.buildingName} - ${c.flatNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${c.complaintType}\n${DateFormat('dd MMM, hh:mm a').format(c.createdAt)}"),
        trailing: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (isLocked ? Colors.grey : Colors.blue).withOpacity(0.1),
            borderRadius: BorderRadius.circular(4)
          ),
          child: Text(c.status,
              style: TextStyle(
                  color: (isLocked ? Colors.black54 : Colors.blue),
                  fontWeight: FontWeight.bold,
                  fontSize: 10)),
        ),
        onTap: () => isLocked ? _viewOnly(context, c) : _showActions(context, service, c),
      ),
    );
  }

  void _showActions(BuildContext context, ComplaintService service, Complaint c) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.play_arrow, color: Colors.green),
          title: const Text("Start Work"),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final userName = prefs.getString('user_name') ?? "Technician";
            await service.updateComplaint(c.copyWith(
              status: "In Progress",
              startTime: DateTime.now(),
              technicianName: userName,
            ));
            Navigator.pop(context);
          }
        ),
        ListTile(
          leading: const Icon(Icons.pause, color: Colors.orange),
          title: const Text("Standby"),
          onTap: () {
            Navigator.pop(context);
            _inputStandby(context, service, c);
          }
        ),
        ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.blue),
          title: const Text("Resolve Task"),
          onTap: () {
            Navigator.pop(context);
            _completeTask(context, service, c);
          }
        ),
      ]),
    );
  }

  void _inputStandby(BuildContext context, ComplaintService service, Complaint c) {
    final t = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Move to Standby"),
        content: TextField(controller: t, decoration: const InputDecoration(hintText: "Reason for standby")),
        actions: [
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final userName = prefs.getString('user_name') ?? "Technician";
              
              // Correctly using copyWith since standbyBy exists in your model
              await service.updateComplaint(c.copyWith(
                status: "Standby",
                standbyReason: t.text,
                standbyTime: DateTime.now(),
                standbyBy: userName,
              ));

              Navigator.pop(context);
            },
            child: const Text("Update")
          )
        ]
      )
    );
  }

  void _completeTask(BuildContext context, ComplaintService service, Complaint c) {
    final s = TextEditingController();
    final r = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Final Report"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: s, decoration: const InputDecoration(labelText: "Service Report Number")),
          TextField(controller: r, decoration: const InputDecoration(labelText: "Final Remarks (Mandatory)"))
        ]),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (r.text.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              final userName = prefs.getString('user_name') ?? "Technician";
              
              // Correctly using copyWith since finalRemarks exists in your model
              await service.updateComplaint(c.copyWith(
                status: "Resolved",
                serviceReportNumber: s.text,
                completedAt: DateTime.now(),
                closedBy: userName,
                finalRemarks: r.text,
              ));

              Navigator.pop(context);
            },
            child: const Text("Submit")
          )
        ]
      )
    );
  }

  void _viewOnly(BuildContext context, Complaint c) {
    String content = (c.status == "Resolved")
        ? "Serial: ${c.serviceReportNumber}\nRemarks: ${c.finalRemarks.isNotEmpty ? c.finalRemarks : c.standbyReason}"
        : "Closed by Customer.\nNote: ${c.standbyReason.isNotEmpty ? c.standbyReason : 'N/A'}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(c.status),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))]
      )
    );
  }
}