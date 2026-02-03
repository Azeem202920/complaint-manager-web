import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/complaint_service.dart';
import '../models/complaint.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final complaintService = Provider.of<ComplaintService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () => complaintService.testFirestoreConnection(),
            tooltip: 'Test Connection',
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            onPressed: () => complaintService.checkDatabaseExists(),
            tooltip: 'Check DB',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.engineering, size: 80, color: Colors.blue),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 60),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.person),
                label: const Text('Customer Portal', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.pushNamed(context, '/customer'),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 60),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.build),
                label: const Text('Technician Portal', style: TextStyle(fontSize: 18)),
                onPressed: () => Navigator.pushNamed(context, '/technician'),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const Text('Live Status Overview', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: StreamBuilder<List<Complaint>>(
                  stream: complaintService.getAllComplaints(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final c = snapshot.data![index];
                        return ListTile(
                          title: Text(c.category),
                          subtitle: Text('Status: ${c.status}'),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}