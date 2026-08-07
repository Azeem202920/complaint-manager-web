import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'home_screen.dart'; 

class RegisterComplaintScreen extends StatefulWidget {
  final String phoneNumber;
  final String customerName; // Received from Login
  const RegisterComplaintScreen({super.key, required this.phoneNumber, required this.customerName});
  
  @override
  State<RegisterComplaintScreen> createState() => _RegisterComplaintScreenState();
}

class _RegisterComplaintScreenState extends State<RegisterComplaintScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  String _flat = '';
  String? _selectedBuilding;
  String? _selectedType;
  String _desc = '';
  
  final TextEditingController _manualBuildingController = TextEditingController();
  final TextEditingController _manualTypeController = TextEditingController();
  
  bool _isOtherBuilding = false;
  bool _isOtherType = false;
  bool _loading = false;
  
  final List<String> _complaintTypes = ["Not Mentioned", "Water leakage", "Low cooling", "Smell coming from AC", "Sound coming from AC", "Cleaning/Service", "New rent out", "Low air speed", "Low fan speed", "AC fan not working", "No Cooling", "No Power/Electricity", "Others"];
  final List<String> _buildings = ["Expo Tower", "Gate Tower 1", "Gate Tower 2", "Al Khor Tower C", "Rital & Rinad",  "Jodi 1", "Jodi 2", "Jodi 3", "Falcon Jodi 5", "Naseem", "Hala Building", "Nada building", "Al Tameer",  "Tallah Mall", "Al Khor Mall", "Mazaya", "Yasmeen Tower", "Ajman Club", "Salah Ud Din", "Sara Plaza 3", "Jurf 2", "Flower Shop", "Amina Hospital", "Villas", "Sharjah", "Rashdiya", "Galleria Mall", "N/A", "Others"];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualBuildingController.dispose();
    _manualTypeController.dispose();
    super.dispose();
  }

  // Dialog with Remarks TextField as requested
  void _showCustomerCloseDialog(Complaint c) {
    if (c.status == "Resolved" || c.status == "Closed by Customer") return;
    final TextEditingController remarksController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Complaint"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("If your issue is solved, please provide closing remarks:"),
            const SizedBox(height: 15),
            TextField(
              controller: remarksController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Enter your closing remarks here...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter remarks before closing")),
                );
                return;
              }
              
              final service = Provider.of<ComplaintService>(context, listen: false);
              
              // Fixed method call passing required arguments securely
              await service.updateLifecycleStatus(
                c.id,
                "Closed by Customer",
              );
              
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Complaint closed successfully.")),
              );
            },
            child: const Text("CLOSE COMPLAINT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    String finalBuilding = _isOtherBuilding ? _manualBuildingController.text : (_selectedBuilding ?? '');
    String finalType = _isOtherType ? _manualTypeController.text : (_selectedType ?? '');
    
    setState(() => _loading = true);
    try {
      final service = Provider.of<ComplaintService>(context, listen: false);
      final c = Complaint(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        customerPhone: widget.phoneNumber.trim(),
        customerName: "${widget.customerName} (${widget.phoneNumber})", 
        address: "$finalBuilding, $_flat",
        description: _desc, 
        category: finalType,
        createdAt: DateTime.now(),
        status: 'Pending',
        priority: 'Medium',
        flatNumber: _flat,
        buildingName: finalBuilding,
        complaintType: finalType,
        standbyReason: '', 
        finalRemarks: '',  
        technicianName: 'Unassigned',
        isDeleted: false,
        imageUrls: [],
      );
      
      await service.addComplaintWithId(c);
      _formKey.currentState!.reset();
      _manualBuildingController.clear();
      _manualTypeController.clear();
      setState(() { 
        _selectedBuilding = null; 
        _selectedType = null; 
        _isOtherBuilding = false; 
        _isOtherType = false; 
      });
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complaint Registered!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome: ${widget.customerName}"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => HomeScreen.logout(context), 
            tooltip: "Logout",
          )
        ],
        bottom: TabBar(
          controller: _tabController, 
          indicatorColor: Colors.white,
          tabs: const [Tab(text: "New Request"), Tab(text: "My Status")]
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRegistrationForm(), _buildStatusList()],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedBuilding,
            decoration: const InputDecoration(labelText: "Select Building", border: OutlineInputBorder()),
            items: _buildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (val) => setState(() { _selectedBuilding = val; _isOtherBuilding = (val == "Others"); }),
            validator: (v) => v == null ? "Required" : null,
          ),
          if (_isOtherBuilding) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextFormField(
              controller: _manualBuildingController, 
              decoration: const InputDecoration(labelText: "Enter Building Name/No", border: OutlineInputBorder()),
              validator: (v) => (_isOtherBuilding && (v == null || v.isEmpty)) ? "Please enter building name" : null,
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            decoration: const InputDecoration(labelText: "Area/Flat", border: OutlineInputBorder()), 
            onSaved: (v) => _flat = v ?? '',
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: "What is the issue?", border: OutlineInputBorder()),
            items: _complaintTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() { _selectedType = val; _isOtherType = (val == "Others"); }),
            validator: (v) => v == null ? "Required" : null,
          ),
          if (_isOtherType) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextFormField(
              controller: _manualTypeController, 
              decoration: const InputDecoration(labelText: "Describe issue", border: OutlineInputBorder()),
              validator: (v) => (_isOtherType && (v == null || v.isEmpty)) ? "Please describe the issue" : null,
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            decoration: const InputDecoration(labelText: "Additional Details (Optional)", border: OutlineInputBorder()), 
            maxLines: 2,
            onSaved: (v) => _desc = v ?? '',
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _loading ? null : _submit, 
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
            ),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT COMPLAINT")
          ),
        ],
      ),
    );
  }

  Widget _buildStatusList() {
    final complaintService = Provider.of<ComplaintService>(context);
    return StreamBuilder<List<Complaint>>(
      stream: complaintService.getComplaintsByPhone(widget.phoneNumber),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final complaints = (snapshot.data ?? []).where((c) => !c.isDeleted && DateTime.now().difference(c.createdAt).inDays < 3).toList();
        
        if (complaints.isEmpty) return const Center(child: Text("No active complaints."));
        
        return ListView.builder(
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final c = complaints[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    title: Text("${c.complaintType} - ${c.buildingName}"),
                    subtitle: Text("Flat: ${c.flatNumber} | Status: ${c.status}"),
                    trailing: _getStatusChip(c.status),
                  ),
                  if (c.status != "Resolved" && c.status != "Closed by Customer")
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showCustomerCloseDialog(c),
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                            label: const Text("CLOSE COMPLAINT", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _getStatusChip(String status) {
    Color color = status == 'Pending' ? Colors.orange : (status == 'Resolved' || status == 'Closed by Customer' ? Colors.green : Colors.blue);
    return Chip(label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: color);
  }
}