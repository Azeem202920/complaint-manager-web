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
  
  // Customer Credentials Map
  final Map<String, String> _customerCredentials = const {
    "Customer One": "98765",
    "Customer Two": "43688",
    "Customer Three": "28607",
    "Customer Four": "15805",
    "Customer Five": "20637",
    "Customer Six": "10946",
    "Customer Seven": "25963",
    "Customer Eight": "87539",
    "Customer Nine": "36806",
    "Tanveer": "4066",
    "Azeem": "6693",
    "Sir": "3067",
    "Rana Sb": "9999",
    "Moeen Sb": "8899",
  };

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Logged out successfully")),
    );
  }

  // Customer Login Dialog using Username and Password
  void _showCustomerLoginDialog(BuildContext context) {
    final uController = TextEditingController();
    final pController = TextEditingController();

    void submit() async {
      String username = uController.text.trim();
      String password = pController.text.trim();
      if (_customerCredentials.containsKey(username) && _customerCredentials[username] == password) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', username);
        await prefs.setString('customer_phone', password); 
        
        if (!context.mounted) return;
        Navigator.pop(context);
        
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RegisterComplaintScreen(
            phoneNumber: password,
            customerName: username,
          )
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Username or Password"), backgroundColor: Colors.red),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Customer Login"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: uController,
              autofocus: true,
              decoration: const InputDecoration(hintText: "Username", border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Password", border: OutlineInputBorder()),
              onSubmitted: (_) => submit(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: submit, child: const Text("Login")),
        ],
      ),
    );
  }

  Future<void> _handleTechnicianAccess(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getString('tech_last_login');
    final currentUser = prefs.getString('user_name');
    
    if (lastLogin != null && currentUser != null && currentUser != "Admin") {
      final difference = DateTime.now().difference(DateTime.parse(lastLogin));
      if (difference.inHours < 1) {
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TechnicianScreen()));
        return;
      }
    }
    if (!context.mounted) return;
    _showTechLoginDialog(context);
  }

  Future<void> _handleAdminAccess(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getString('admin_last_login');
    final currentUser = prefs.getString('user_name');
    
    if (lastLogin != null && currentUser == "Admin") {
      final difference = DateTime.now().difference(DateTime.parse(lastLogin));
      if (difference.inHours < 48) {
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
        return;
      }
    }
    if (!context.mounted) return;
    _showAdminPinDialog(context);
  }

  void _showTechLoginDialog(BuildContext context) {
    final uContent = TextEditingController();
    final pContent = TextEditingController();

    void attemptLogin() async {
      String enteredName = uContent.text.trim();
      String enteredPassword = pContent.text.trim();

      if (enteredName.isEmpty || enteredPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill in both fields"), backgroundColor: Colors.red),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final complaintService = Provider.of<ComplaintService>(context, listen: false);
        
        // Authenticate via Firebase Auth & verify Firestore presence/status
        await complaintService.loginTechnician(enteredName, enteredPassword);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('admin_last_login'); 
        await prefs.setString('tech_last_login', DateTime.now().toIso8601String());
        await prefs.setString('user_name', enteredName); 
        
        if (!context.mounted) return;
        Navigator.pop(context); // Pop loading dialog
        Navigator.pop(context); // Pop login dialog
        
        Navigator.push(context, MaterialPageRoute(builder: (context) => const TechnicianScreen()));
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
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
              decoration: const InputDecoration(hintText: "Name or Email", border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pContent, 
              obscureText: true, 
              decoration: const InputDecoration(hintText: "Password / PIN", border: OutlineInputBorder()),
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
        await prefs.remove('tech_last_login'); 
        await prefs.setString('admin_last_login', DateTime.now().toIso8601String());
        await prefs.setString('user_name', "Admin"); 
        
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
        backgroundColor: Colors.orange.shade800,
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
                _buildSmallBtn(context, "Register", Colors.blue, () => _showCustomerLoginDialog(context)),
                _buildSmallBtn(context, "Technician", Colors.orange, () => _handleTechnicianAccess(context)),
                _buildSmallBtn(context, "Settings", Colors.redAccent, () => _handleAdminAccess(context)),
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