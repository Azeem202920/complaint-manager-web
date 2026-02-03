import 'package:flutter/material.dart';
import 'dart:io';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class RegisterComplaintScreen extends StatefulWidget {
  final String customerPhone;
  final String customerName;

  const RegisterComplaintScreen({
    super.key,
    required this.customerPhone,
    required this.customerName,
  });

  @override
  State<RegisterComplaintScreen> createState() => _RegisterComplaintScreenState();
}

class _RegisterComplaintScreenState extends State<RegisterComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final ComplaintService _complaintService = ComplaintService();
  
  String _flatNumber = '';
  String _buildingName = '';
  String _complaintType = '';
  String _description = '';
  
  final List<String> _buildingOptions = [
    'Building A', 'Building B', 'Building C', 'Building D', 'Building E',
  ];
  
  final List<String> _complaintOptions = [
    'AC not cooling', 'Water leakage', 'Electrical issue', 'Plumbing problem',
    'Carpentry work', 'Painting required', 'Cleaning needed', 'Other',
  ];
  
  bool _isSubmitting = false;

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;
    
    _formKey.currentState!.save();
    setState(() => _isSubmitting = true);
    
    try {
      String complaintId = 'COMP${DateTime.now().millisecondsSinceEpoch}';
      
      Complaint complaint = Complaint(
        id: complaintId,
        customerPhone: widget.customerPhone,
        customerName: widget.customerName,
        address: '$_buildingName, Flat $_flatNumber',
        problemDescription: _description.isNotEmpty ? _description : _complaintType,
        category: _complaintType,
        createdAt: DateTime.now(),
        status: 'Pending',
        priority: 'Medium',
        flatNumber: _flatNumber,
        buildingName: _buildingName,
        complaintType: _complaintType,
        description: _description,
        imageUrls: [],
      );
      
      await _complaintService.addComplaintWithId(complaint);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint registered successfully!'), backgroundColor: Colors.green),
      );
      
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Complaint'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text('Name: ${widget.customerName}'),
                      Text('Phone: ${widget.customerPhone}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Flat Number*', prefixIcon: Icon(Icons.home), border: OutlineInputBorder()),
                validator: (value) => (value == null || value.isEmpty) ? 'Please enter flat number' : null,
                onSaved: (value) => _flatNumber = value ?? '',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Building Name*', prefixIcon: Icon(Icons.apartment), border: OutlineInputBorder()),
                value: _buildingName.isEmpty ? null : _buildingName,
                items: _buildingOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (value) => setState(() => _buildingName = value!),
                validator: (value) => (value == null) ? 'Select building' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Complaint Type*', prefixIcon: Icon(Icons.report_problem), border: OutlineInputBorder()),
                value: _complaintType.isEmpty ? null : _complaintType,
                items: _complaintOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (value) => setState(() => _complaintType = value!),
                validator: (value) => (value == null) ? 'Select type' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description (Optional)', prefixIcon: Icon(Icons.description), border: OutlineInputBorder()),
                maxLines: 3,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComplaint,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(18), backgroundColor: Colors.blue),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Submit Complaint', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}