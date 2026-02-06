import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';

class RegisterComplaintScreen extends StatefulWidget {
  final String phoneNumber;
  const RegisterComplaintScreen({super.key, required this.phoneNumber});

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

  final List<String> _complaintTypes = ["Water leakage", "Low cooling", "Smell coming from AC", "Sound coming from AC", "Cleaning/Service", "New rent out", "Low air speed", "Low fan speed", "AC fan not working", "Others"];
  final List<String> _buildings = List.generate(26, (i) => "Building ${i + 1}")..add("Others");

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // DIALOG: Allows customer to close their own complaint
  void _showCustomerCloseDialog(BuildContext context, ComplaintService service, Complaint c) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Close Complaint?"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Reason (e.g., Problem solved)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // FIX: Save customer note in standbyReason instead of description
              service.updateComplaint(c.copyWith(
                status: "Closed by Customer",
                standbyReason: controller.text, 
              ));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complaint Closed")));
            },
            child: const Text("CONFIRM CLOSE", style: TextStyle(color: Colors.white)),
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
        customerName: "Customer",
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
        technicianName: 'Unassigned',
        isDeleted: false,
        imageUrls: [],
      );
      
      await service.addComplaintWithId(c);
      _formKey.currentState!.reset();
      _manualBuildingController.clear();
      _manualTypeController.clear();
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
        title: Text("Portal: ${widget.phoneNumber}"),
        bottom: TabBar(
          controller: _tabController, 
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
            decoration: const InputDecoration(labelText: "Building", border: OutlineInputBorder()),
            items: _buildings.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (val) => setState(() { _selectedBuilding = val; _isOtherBuilding = (val == "Others"); }),
            validator: (v) => v == null ? "Required" : null,
          ),
          if (_isOtherBuilding) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextFormField(
              controller: _manualBuildingController, 
              decoration: const InputDecoration(labelText: "Enter Building Name/No", border: OutlineInputBorder())
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            decoration: const InputDecoration(labelText: "Flat Number", border: OutlineInputBorder()), 
            onSaved: (v) => _flat = v ?? '',
            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: "Issue", border: OutlineInputBorder()),
            items: _complaintTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() { _selectedType = val; _isOtherType = (val == "Others"); }),
            validator: (v) => v == null ? "Required" : null,
          ),
          if (_isOtherType) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextFormField(
              controller: _manualTypeController, 
              decoration: const InputDecoration(labelText: "Describe issue", border: OutlineInputBorder())
            ),
          ),
          const SizedBox(height: 15),
          TextFormField(
            decoration: const InputDecoration(labelText: "Remarks", border: OutlineInputBorder()), 
            maxLines: 2,
            onSaved: (v) => _desc = v ?? '',
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _loading ? null : _submit, 
            child: _loading ? const CircularProgressIndicator() : const Text("SUBMIT")
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
        
        final allComplaints = snapshot.data ?? [];
        final complaints = allComplaints.where((c) => c.isDeleted == false).toList();

        if (complaints.isEmpty) return const Center(child: Text("No active complaints."));

        return ListView.builder(
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final c = complaints[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                title: Text(c.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Status: ${c.status}"),
                    // If Resolved, show tech note. If Closed by Customer, show customer note.
                    if (c.standbyReason.isNotEmpty)
                      Text(
                        c.status == "Closed by Customer" 
                          ? "Your Note: ${c.standbyReason}" 
                          : "Tech Remarks: ${c.standbyReason}", 
                        style: TextStyle(
                          color: c.status == "Closed by Customer" ? Colors.blueGrey : Colors.green, 
                          fontSize: 12,
                          fontStyle: FontStyle.italic
                        )
                      ),
                  ],
                ),
                trailing: Wrap(
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _getStatusChip(c.status),
                    if (c.status != 'Resolved' && c.status != 'Closed by Customer')
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: "Close Request",
                        onPressed: () => _showCustomerCloseDialog(context, complaintService, c),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _getStatusChip(String status) {
    Color color = Colors.blue;
    if (status == 'Pending') color = Colors.orange;
    if (status == 'Completed' || status == 'Resolved') color = Colors.green;
    if (status == 'Closed by Customer') color = Colors.grey;
    
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10)), 
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  void dispose() { 
    _tabController.dispose(); 
    _manualBuildingController.dispose(); 
    _manualTypeController.dispose(); 
    super.dispose(); 
  }
}