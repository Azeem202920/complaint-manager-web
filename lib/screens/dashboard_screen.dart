import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Required for DocumentSnapshot
import '../services/complaint_service.dart';
import '../models/complaint.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<ComplaintService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Main Dashboard")),
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
              children: [
                // Row 1: Complaints Summary
                _buildStatsGrid(total, pending, inProgress, resolved),
                const SizedBox(height: 20),
                // Row 2: Technician Status
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
    // Access the service
    final service = Provider.of<ComplaintService>(context, listen: false);

    return StreamBuilder<DocumentSnapshot>(
      stream: service.getChillerStatusStream(),
      builder: (context, snapshot) {
        // Handle loading/empty states
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: ListTile(title: Text("Loading sensor data...")));
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Card(child: ListTile(title: Text("No sensor data found")));
        }

        // Extract data
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

  Widget _buildTechnicianStatus() {
    return const Card(
      child: ListTile(
        title: Text("Technician: Ali"),
        subtitle: Text("Status: In Progress"),
        trailing: Text("2 min ago"),
      ),
    );
  }
}