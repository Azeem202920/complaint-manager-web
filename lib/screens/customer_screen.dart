import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/complaint_service.dart';
import '../models/complaint.dart';

class CustomerScreen extends StatefulWidget {
  final String phoneNumber;

  const CustomerScreen({super.key, required this.phoneNumber});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  @override
  Widget build(BuildContext context) {
    final complaintService = Provider.of<ComplaintService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Complaints'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: complaintService.getComplaintsByPhone(widget.phoneNumber),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // FILTER: Hide complaints older than 3 days
          final now = DateTime.now();
          final activeComplaints = snapshot.data?.where((c) {
            final difference = now.difference(c.createdAt).inDays;
            return difference <= 3;
          }).toList() ?? [];

          if (activeComplaints.isEmpty) {
            return const Center(
              child: Text('No complaints found in the last 3 days.'),
            );
          }

          return ListView.builder(
            itemCount: activeComplaints.length,
            itemBuilder: (context, index) {
              final c = activeComplaints[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 2,
                child: ListTile(
                  leading: _getStatusIcon(c.status),
                  title: Text(c.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Submitted: ${DateFormat('dd MMM yyyy').format(c.createdAt)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showComplaintDetails(context, c),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRegistrationSheet(context),
        label: const Text('New Complaint'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // --- Registration Logic ---
  void _openRegistrationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const RegisterComplaintSheet(),
    );
  }

  // --- UI Helpers ---
  Widget _getStatusIcon(String status) {
    if (status == 'Resolved') return const Icon(Icons.check_circle, color: Colors.green);
    if (status == 'In Progress') return const Icon(Icons.pending, color: Colors.blue);
    return const Icon(Icons.report_problem, color: Colors.orange);
  }

  void _showComplaintDetails(BuildContext context, Complaint c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(c.category, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                _buildStatusChip(c.status),
              ],
            ),
            const Divider(),
            _detailRow(Icons.location_on, "Address", "${c.buildingName}, Unit ${c.flatNumber}"),
            _detailRow(Icons.description, "Issue", c.problemDescription),
            _detailRow(Icons.person, "Technician", c.technicianName ?? "Awaiting Assignment"),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value, style: const TextStyle(fontSize: 15)),
          ])),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = status == 'Resolved' ? Colors.green : (status == 'In Progress' ? Colors.blue : Colors.orange);
    return Chip(label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)), backgroundColor: color);
  }
}

// --- Registration Form Component ---
class RegisterComplaintSheet extends StatefulWidget {
  const RegisterComplaintSheet({super.key});

  @override
  State<RegisterComplaintSheet> createState() => _RegisterComplaintSheetState();
}

class _RegisterComplaintSheetState extends State<RegisterComplaintSheet> {
  final List<String> _types = ["Water leakage", "Low cooling", "Smell coming from AC", "Sound coming from AC", "Cleaning/Service", "New rent out", "Low air speed", "Low fan speed", "AC fan not working", "Others"];
  final List<String> _buildings = List.generate(26, (i) => "Building ${i + 1}")..add("Others");

  String? _selectedType;
  String? _selectedBuilding;
  bool _isOtherType = false;
  bool _isOtherBuilding = false;
  
  final _manualTypeController = TextEditingController();
  final _manualBuildingController = TextEditingController();
  final _flatController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Submit New Complaint", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Building Searchable Dropdown
            Autocomplete<String>(
              optionsBuilder: (textValue) => _buildings.where((s) => s.toLowerCase().contains(textValue.text.toLowerCase())),
              onSelected: (val) => setState(() { _selectedBuilding = val; _isOtherBuilding = (val == "Others"); }),
              fieldViewBuilder: (context, controller, focus, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focus,
                decoration: const InputDecoration(labelText: "Search Building", border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
              ),
            ),
            if (_isOtherBuilding) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(controller: _manualBuildingController, decoration: const InputDecoration(labelText: "Enter Building Name", border: OutlineInputBorder())),
            ),
            
            const SizedBox(height: 15),
            TextField(controller: _flatController, decoration: const InputDecoration(labelText: "Flat/Unit Number", border: OutlineInputBorder())),
            
            const SizedBox(height: 15),
            
            // Complaint Type Dropdown
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() { _selectedType = val; _isOtherType = (val == "Others"); }),
              decoration: const InputDecoration(labelText: "Complaint Type", border: OutlineInputBorder()),
            ),
            if (_isOtherType) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(controller: _manualTypeController, decoration: const InputDecoration(labelText: "Describe Other Issue", border: OutlineInputBorder())),
            ),
            
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                onPressed: () {
                  // Final logic to save to Provider/Service goes here
                  Navigator.pop(context);
                },
                child: const Text("Submit Complaint"),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}