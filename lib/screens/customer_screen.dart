import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class CustomerScreen extends StatefulWidget {
  final String phoneNumber;
  const CustomerScreen({super.key, required this.phoneNumber});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late Stream<List<Complaint>> _complaintsStream;

  @override
  void initState() {
    super.initState();
    final complaintService = Provider.of<ComplaintService>(context, listen: false);
    _complaintsStream = complaintService.getComplaintsByPhone(widget.phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Complaints')),
      body: StreamBuilder<List<Complaint>>(
        stream: _complaintsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final complaints = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: complaints.isEmpty
                    ? const Center(child: Text('No complaints filed yet.'))
                    : ListView.builder(
                        itemCount: complaints.length,
                        itemBuilder: (context, index) {
                          final c = complaints[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            child: ListTile(
                              title: Text(c.category),
                              subtitle: Text('Status: ${c.status}'),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: () => Navigator.pushNamed(context, '/register-complaint'),
                  child: const Text('Register New Complaint'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}