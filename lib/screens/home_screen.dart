import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/complaint_service.dart';
import 'register_complaint_screen.dart';
import 'technician_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final String _adminPin = "6693";
  final Map<String, String> _technicianCredentials = const {
    "Charanjeet": "1234", "Noman": "3290", "Raju": "3556",
    "Usman": "4347", "Aftab": "2545", "Yam Bahadur": "9999",
    "Asgar": "7536", "Uzair": "7890", "Majid": "5306",
    "Sunil": "3790", "User": "11234",
  };

  // --- LOGOUT LOGIC ---
  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Removes timestamps AND saved user_name
    
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logged out successfully")),
    );
  }

  // --- ACCESS HANDLERS ---
  Future<void> _handleTechnicianAccess(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getString('tech_last_login');
    
    if (lastLogin != null) {
      final difference = DateTime.now().difference(DateTime.parse(lastLogin));
      if (difference.inHours < 1) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TechnicianScreen()));
        return;
      }
    }
    _showTechLoginDialog(context);
  }

  Future<void> _handleAdminAccess(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getString('admin_last_login');
    
    if (lastLogin != null) {
      final difference = DateTime.now().difference(DateTime.parse(lastLogin));
      if (difference.inHours < 48) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
        return;
      }
    }
    _showAdminPinDialog(context);
  }

  // --- DIALOGS ---
  
  void _showPhoneInputDialog(BuildContext context) {
    final controller = TextEditingController();
    void submit() async {
      if (controller.text.trim().isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        // Save name as Customer for generic identification
        await prefs.setString('user_name', "Customer"); 
        
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RegisterComplaintScreen(phoneNumber: controller.text.trim())
        ));
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Customer Phone"),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: "Enter number", border: OutlineInputBorder()),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: submit, child: const Text("Continue")),
        ],
      ),
    );
  }

  void _showTechLoginDialog(BuildContext context) {
    final uContent = TextEditingController();
    final pContent = TextEditingController();

    void attemptLogin() async {
      String enteredName = uContent.text.trim(); 
      if (_technicianCredentials[enteredName] == pContent.text.trim()) {
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setString('tech_last_login', DateTime.now().toIso8601String());
        await prefs.setString('user_name', enteredName); // SAVE TECH NAME
        
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TechnicianScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Credentials"), backgroundColor: Colors.red),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tech Login"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: uContent, 
              autofocus: true, 
              decoration: const InputDecoration(hintText: "Name", border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pContent, 
              obscureText: true, 
              decoration: const InputDecoration(hintText: "PIN", border: OutlineInputBorder()),
              onSubmitted: (_) => attemptLogin(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: attemptLogin, child: const Text("Login")),
        ],
      ),
    );
  }

  void _showAdminPinDialog(BuildContext context) {
    final controller = TextEditingController();
    void submit() async {
      if (controller.text == _adminPin) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_last_login', DateTime.now().toIso8601String());
        await prefs.setString('user_name', "Admin"); // SAVE ADMIN NAME
        
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Incorrect PIN"), backgroundColor: Colors.red),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin PIN"),
        content: TextField(
          controller: controller, 
          obscureText: true, 
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter PIN", border: OutlineInputBorder()),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: submit, child: const Text("Unlock")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaintService = Provider.of<ComplaintService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Maintenance App"), 
        centerTitle: true,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment, size: 80, color: Colors.blue),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildSmallBtn(context, "Register", Colors.blue, () => _showPhoneInputDialog(context)),
                _buildSmallBtn(context, "Technician", Colors.orange, () => _handleTechnicianAccess(context)),
                _buildSmallBtn(context, "Admin", Colors.redAccent, () => _handleAdminAccess(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallBtn(BuildContext context, String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(120, 48),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}