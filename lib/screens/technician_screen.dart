import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
    "All", "Expo Tower", "Gate Tower 1", "Gate Tower 2", "Al Khor Tower C",
    "Rital & Rinad",  "Jodi 1", "Jodi 2", "Jodi 3", "Falcon Jodi 5", "Naseem",
    "Hala Building", "Nada building", "Al Tameer",  "Tallah Mall", "Al Khor Mall",
    "Mazaya", "Yasmeen Tower", "Ajman Club", "Salah Ud Din", "Sara Plaza 3", "Jurf 2",
    "Flower Shop", "Amina Hospital", "Villas", "Sharjah", "Rashdiya", "Galleria Mall",
    "N/A", "Others"
  ];

  final List<String> _statusOptions = ["All", "Pending", "In Progress", "Standby", "Resolved"];
  final List<String> _timeOptions = ["All", "Today", "Yesterday", "Select Date"];

  Future<String> _getTechnicianName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? "Unknown Tech";
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Technician Portal"),
        backgroundColor: Colors.orange.shade800,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => HomeScreen.logout(context),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filteredList = snapshot.data!.where((c) {
                  if (c.isDeleted == true) return false;

                  bool matchStatus = selectedStatus == "All" || c.status == selectedStatus;
                  bool matchBuilding = selectedBuilding == "All" || c.buildingName == selectedBuilding;
                  
                  bool matchTime = true;
                  if (selectedTimeFrame == "Today") matchTime = _isSameDay(c.createdAt, DateTime.now());
                  if (selectedTimeFrame == "Yesterday") matchTime = _isSameDay(c.createdAt, DateTime.now().subtract(const Duration(days: 1)));
                  if (selectedTimeFrame == "Select Date" && customDate != null) matchTime = _isSameDay(c.createdAt, customDate!);

                  return matchStatus && matchBuilding && matchTime;
                }).toList();

                if (filteredList.isEmpty) return const Center(child: Text("No tasks found."));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) => _buildTaskCard(context, service, filteredList[index]),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _buildFilterRow("Status", _statusOptions),
          _buildFilterRow("Building", _buildings),
          _buildFilterRow("Time", _timeOptions),
        ],
      ),
    );
  }

  Widget _buildFilterRow(String label, List<String> opts) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: opts.length,
        itemBuilder: (context, i) {
          String opt = opts[i];
          bool isSelected = (label == "Status" && selectedStatus == opt) ||
                            (label == "Building" && selectedBuilding == opt) ||
                            (label == "Time" && selectedTimeFrame == opt);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ChoiceChip(
              label: Text(opt == "Select Date" && customDate != null ? DateFormat('dd/MM').format(customDate!) : opt, 
                          style: const TextStyle(fontSize: 11)),
              selected: isSelected,
              selectedColor: Colors.orange.shade800,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
              onSelected: (val) async {
                if (opt == "Select Date") {
                  DateTime? d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2025), lastDate: DateTime.now());
                  if (d != null) setState(() { selectedTimeFrame = "Select Date"; customDate = d; });
                } else {
                  setState(() {
                    if (label == "Status") selectedStatus = opt;
                    if (label == "Building") selectedBuilding = opt;
                    if (label == "Time") { selectedTimeFrame = opt; customDate = null; }
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, ComplaintService service, Complaint c) {
    bool isLocked = c.status == "Resolved" || c.status == "Closed by Customer";
    bool isStandby = c.status == "Standby";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ListTile(
        title: Text("${c.buildingName} - Flat ${c.flatNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Issue: ${c.complaintType}"),
            if (c.description.isNotEmpty) 
              Text("Details: ${c.description}", 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis, 
                style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12, fontStyle: FontStyle.italic)
              ),
            
            // Logic to display assigned technician name from your model
            if (c.status != "Pending" && c.status != "Resolved" && c.status != "Closed by Customer")
               Text("Tech: ${c.technicianName ?? c.standbyBy ?? 'Assigned'}", 
                 style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
            
            if (isStandby) Text("Reason: ${c.standbyReason}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(DateFormat('dd MMM, hh:mm a').format(c.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isLocked ? Colors.grey.shade200 : (isStandby ? Colors.orange.shade100 : Colors.blue.shade100),
            borderRadius: BorderRadius.circular(4)
          ),
          child: Text(c.status, style: TextStyle(
            color: isLocked ? Colors.grey.shade700 : (isStandby ? Colors.orange.shade900 : Colors.blue.shade900),
            fontWeight: FontWeight.bold, fontSize: 11
          )),
        ),
        onTap: () => isLocked ? _showDetails(context, c) : _showActionSheet(context, service, c),
      ),
    );
  }

  void _showActionSheet(BuildContext context, ComplaintService service, Complaint c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Update Status: ${c.id.substring(0,8)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Issue: ${c.complaintType}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  if (c.description.isNotEmpty)
                    Text("Customer Remarks: ${c.description}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.play_circle_fill, color: Colors.green),
              title: const Text("Start Work / In Progress"),
              onTap: () async {
                final name = await _getTechnicianName();
                await service.updateLifecycleStatus(id: c.id, status: "In Progress", userName: name, isStarting: true);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause_circle_filled, color: Colors.orange),
              title: const Text("Move to Standby"),
              onTap: () {
                Navigator.pop(context);
                _showStandbyDialog(context, service, c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.blue),
              title: const Text("Resolve / Complete Task"),
              onTap: () {
                Navigator.pop(context);
                _showResolveDialog(context, service, c);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showStandbyDialog(BuildContext context, ComplaintService service, Complaint c) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Standby Reason"),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: "e.g., Waiting for spare parts")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.isEmpty) return;
              final name = await _getTechnicianName();
              await service.updateLifecycleStatus(id: c.id, status: "Standby", userName: name, reason: reasonCtrl.text, isStandby: true);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("CONFIRM"),
          )
        ],
      ),
    );
  }

  void _showResolveDialog(BuildContext context, ComplaintService service, Complaint c) {
    final reportCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final materialsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Complete Task"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: reportCtrl, decoration: const InputDecoration(labelText: "Service Report #")),
              const SizedBox(height: 10),
              TextField(controller: materialsCtrl, decoration: const InputDecoration(labelText: "Materials Used")),
              const SizedBox(height: 10),
              TextField(controller: remarksCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Final Remarks", border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (remarksCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Remarks are required")));
                return;
              }
              final name = await _getTechnicianName();
              await service.updateLifecycleStatus(
                id: c.id, 
                status: "Resolved", 
                userName: name, 
                reason: remarksCtrl.text, 
                serialNo: reportCtrl.text,
                materials: materialsCtrl.text,
                isClosing: true
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("SUBMIT"),
          )
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, Complaint c) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Task Details: ${c.status}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Building: ${c.buildingName}"),
            Text("Flat: ${c.flatNumber}"),
            const Divider(),
            Text("Issue: ${c.complaintType}", style: const TextStyle(fontWeight: FontWeight.bold)),
            if (c.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text("Add. Details: ${c.description}", style: const TextStyle(color: Colors.blueGrey)),
            ],
            const Divider(),
            Text("Report #: ${c.serviceReportNumber ?? 'N/A'}"),
            Text("Materials: ${c.materialsUsed}"),
            Text("Final Remarks: ${c.finalRemarks}"),
            const SizedBox(height: 10),
            Text("Closed By: ${c.closedBy ?? c.customerName}", style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
      ),
    );
  }
}