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
  // Filter States
  String selectedStatus = "All";
  String selectedBuilding = "All";
  String selectedTimeFrame = "All";
  DateTime? customDate;

  final List<String> _buildings = [
    "All", "Expo Tower", "Gate Tower 1", "Gate Tower 2", "Galleria Mall",
    "Al Khor Tower C", "Al Tameer", "Rital & Rinad", "Tallah Mall",
    "Al Khor Mall", "Jodi 1", "Jodi 2", "Jodi 3", "Falcon Jodi 5",
    "Naseem", "Nada building", "Hala Building", "Ajman Club",
    "Salah Ud Din", "Sara Plaza 3", "Jurf 2", "Flower Shop",
    "Amina Hospital", "Villas", "Sharjah", "Others"
  ];

  final List<String> _statusOptions = ["All", "Pending", "In Progress", "Standby", "Resolved"];
  final List<String> _timeOptions = ["All", "Today", "Yesterday", "Select Date"];

  /// IMPROVED: Prioritizes the PIN-login name for accurate Admin Audits
  Future<String> _getTechnicianName() async {
    final prefs = await SharedPreferences.getInstance();
    // This 'user_name' was set during the PIN login in HomeScreen
    String? name = prefs.getString('user_name');
    
    if (name != null && name.isNotEmpty) return name;

    // Fallback to Firebase if SharedPreferences is empty
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
      return currentUser.displayName!;
    }

    return "Unknown Tech";
  }

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

                final allData = snapshot.data ?? [];

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

                if (filteredList.isEmpty) {
                  return const Center(child: Text("No complaints found."));
                }

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
          _buildRow("Status", _statusOptions),
          _buildRow("Building", _buildings),
          _buildRow("Time", _timeOptions),
        ],
      ),
    );
  }

  Widget _buildRow(String label, List<String> opts) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: opts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final String opt = opts[i];
          bool isSelected = false;
          if (label == "Status") isSelected = (selectedStatus == opt);
          if (label == "Building") isSelected = (selectedBuilding == opt);
          if (label == "Time") isSelected = (selectedTimeFrame == opt);

          return ChoiceChip(
            label: Text(
                opt == "Select Date" && customDate != null
                    ? DateFormat('dd/MM').format(customDate!)
                    : opt,
                style: const TextStyle(fontSize: 12)),
            selected: isSelected,
            selectedColor: Colors.blue.shade700,
            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
            onSelected: (val) async {
              if (opt == "Select Date") {
                DateTime? d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now());
                if (d != null) {
                  setState(() {
                    selectedTimeFrame = "Select Date";
                    customDate = d;
                  });
                }
              } else {
                setState(() {
                  if (label == "Status") selectedStatus = opt;
                  if (label == "Building") selectedBuilding = opt;
                  if (label == "Time") {
                    selectedTimeFrame = opt;
                    customDate = null;
                  }
                });
              }
            },
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
              borderRadius: BorderRadius.circular(4)),
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
              final userName = await _getTechnicianName();
              await service.updateLifecycleStatus(
                id: c.id,
                status: "In Progress",
                userName: userName, // Passing actual Tech name
                isStarting: true,
              );
              if (context.mounted) Navigator.pop(context);
            }),
        ListTile(
            leading: const Icon(Icons.pause, color: Colors.orange),
            title: const Text("Standby"),
            onTap: () {
              Navigator.pop(context);
              _inputStandby(context, service, c);
            }),
        ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.blue),
            title: const Text("Resolve Task"),
            onTap: () {
              Navigator.pop(context);
              _completeTask(context, service, c);
            }),
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
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () async {
                        final userName = await _getTechnicianName();
                        await service.updateLifecycleStatus(
                          id: c.id,
                          status: "Standby",
                          userName: userName, // Passing actual Tech name
                          reason: t.text,
                          isStandby: true,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("Update"))
                ]));
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
                  const SizedBox(height: 8),
                  TextField(controller: r, decoration: const InputDecoration(labelText: "Final Remarks (Mandatory)"))
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  ElevatedButton(
                      onPressed: () async {
                        if (r.text.trim().isEmpty) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Remarks are mandatory")));
                           return;
                        }
                        final userName = await _getTechnicianName();
                        await service.updateLifecycleStatus(
                          id: c.id,
                          status: "Resolved",
                          userName: userName, // Passing actual Tech name
                          reason: r.text,
                          serialNo: s.text,
                          isClosing: true,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text("Submit"))
                ]));
  }

  void _viewOnly(BuildContext context, Complaint c) {
    String content = (c.status == "Resolved")
        ? "Technician: ${c.closedBy ?? c.technicianName ?? 'N/A'}\nSerial: ${c.serviceReportNumber}\nRemarks: ${c.finalRemarks}"
        : "Closed by Customer.";

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: Text(c.status),
            content: Text(content),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))]));
  }
}