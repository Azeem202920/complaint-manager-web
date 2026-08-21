import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/complaint_service.dart';
import '../models/complaint.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Method to populate the technicians collection into Firestore
  Future<void> _seedTechniciansDatabase(BuildContext context) async {
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      
      final Map<String, Map<String, dynamic>> techniciansData = {
        "190051": {"name": "Charanjeet", "pin": "1234", "status": "present", "isActive": true},
        "190052": {"name": "Noman", "pin": "3290", "status": "present", "isActive": true},
        "190053": {"name": "Raju", "pin": "3556", "status": "present", "isActive": true},
        "190054": {"name": "Rishav", "pin": "4347", "status": "present", "isActive": true},
        "190055": {"name": "Aftab", "pin": "2545", "status": "present", "isActive": true},
        "190056": {"name": "Yam Bahadur", "pin": "9999", "status": "present", "isActive": true},
        "190057": {"name": "Asgar", "pin": "7536", "status": "present", "isActive": true},
        "190058": {"name": "Uzair", "pin": "7890", "status": "present", "isActive": true},
        "190059": {"name": "Majid", "pin": "5306", "status": "present", "isActive": true},
        "190060": {"name": "Sunil", "pin": "3790", "status": "present", "isActive": true},
        "190061": {"name": "User", "pin": "1123", "status": "present", "isActive": true},
        "190062": {"name": "Azeem", "pin": "6693", "status": "present", "isActive": true},
        "190063": {"name": "Sir", "pin": "3067", "status": "present", "isActive": true},
        "190064": {"name": "Tanveer", "pin": "4066", "status": "present", "isActive": true},
        "190065": {"name": "Rana Sb", "pin": "9999", "status": "present", "isActive": true},
        "190067": {"name": "Moeen Sb", "pin": "8899", "status": "present", "isActive": true},
      };

      for (var entry in techniciansData.entries) {
        String techId = entry.key;
        await db.collection('technicians').doc(techId).set({
          'technicianId': techId,
          'name': entry.value['name'],
          'pin': entry.value['pin'],
          'status': entry.value['status'],
          'isActive': entry.value['isActive'],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Technicians collection seeded successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error seeding technicians: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Main Dashboard"),
        actions: [
          // Icon button added to write/seed technicians into Firestore database
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: "Seed Technicians to DB",
            onPressed: () => _seedTechniciansDatabase(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: service.getAllComplaints(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final complaints = snapshot.data ?? [];

          // Calculate stats from real data
          int total = complaints.length;
          int pending = complaints.where((c) => c.status == "Pending").length;
          int inProgress = complaints.where((c) => c.status == "In Progress").length;
          int resolved = complaints.where((c) => c.status == "Resolved").length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Complaints Summary
                _buildStatsGrid(total, pending, inProgress, resolved),
                const SizedBox(height: 20),
                // Row 2: Technician Status & Activity Stream
                const Text("Technician Live Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildTechnicianStatus(),
                const SizedBox(height: 20),
                // Row 3: Sensors (Chiller/Pumps)
                _buildSensorStatus(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsGrid(int total, int pending, int inProgress, int resolved) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _statCard("Total", "$total", Colors.blue),
        _statCard("Pending", "$pending", Colors.orange),
        _statCard("Progress", "$inProgress", Colors.purple),
        _statCard("Resolved", "$resolved", Colors.green),
      ],
    );
  }

  Widget _statCard(String title, String count, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildSensorStatus(BuildContext context) {
    final service = Provider.of<ComplaintService>(context, listen: false);

    return StreamBuilder<DocumentSnapshot>(
      stream: service.getChillerStatusStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: ListTile(title: Text("Loading sensor data...")));
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Card(child: ListTile(title: Text("No sensor data found")));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        double currentTemp = (data['temp'] ?? 0.0).toDouble();
        bool isHighTemp = currentTemp > 30.0;

        return Card(
          child: ListTile(
            title: const Text("Amina Chiller Temp"),
            subtitle: Text("Status: ${isHighTemp ? 'Alert' : 'Working'}"),
            trailing: Text(
              "${currentTemp.toStringAsFixed(1)}°C",
              style: TextStyle(
                color: isHighTemp ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        );
      },
    );
  }

  // Stream-based widget to display recent technician activity logs from Firestore
  Widget _buildTechnicianStatus() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('technician_activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(child: ListTile(title: Text("No technician activity logged yet.")));
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String techName = data['technicianName'] ?? 'Unknown';
            String action = data['actionType'] ?? 'action';
            Timestamp? time = data['timestamp'] as Timestamp?;
            String timeFormatted = time != null ? time.toDate().toLocal().toString().split('.')[0] : 'Just now';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(techName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Action: $action"),
                trailing: Text(timeFormatted, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }
}