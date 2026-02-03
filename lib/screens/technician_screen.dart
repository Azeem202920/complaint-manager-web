import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class TechnicianScreen extends StatefulWidget {
  const TechnicianScreen({super.key});

  @override
  State<TechnicianScreen> createState() => _TechnicianScreenState();
}

class _TechnicianScreenState extends State<TechnicianScreen> {
  @override
  Widget build(BuildContext context) {
    final complaintService = Provider.of<ComplaintService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Portal'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: complaintService.getComplaints(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final complaints = snapshot.data ?? [];

          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints assigned.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              return Card(
                child: ListTile(
                  title: Text('${complaint.category} - ${complaint.buildingName}'),
                  subtitle: Text('Status: ${complaint.status}\nFlat: ${complaint.flatNumber}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String newStatus) async {
                      final updated = complaint.copyWith(
                        status: newStatus,
                        technicianName: 'Tech John',
                        updatedAt: DateTime.now(),
                      );
                      await complaintService.updateComplaint(updated);
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(value: 'In Progress', child: Text('Start Work')),
                      const PopupMenuItem(value: 'Resolved', child: Text('Mark Resolved')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}