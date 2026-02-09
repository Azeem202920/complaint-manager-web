import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_complaint_screen.dart';
import 'technician_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final String _adminPin = "6693";
  
  // Data from your Excel
  final Map<String, String> _customerDatabase = const {
    "Customer One": "98765",
    "Customer Two": "43688",
    "Customer Three": "28607",
    "Customer Four": "15805",
    "Customer Five": "20637",
    "Customer Six": "10946",
    "Customer Seven": "25963",
    "Customer Eight": "87539",
    "Customer Nine": "36806",
  };

  final Map<String, String> _technicianCredentials = const {
    "Charanjeet": "1234", "Noman": "3290", "Raju": "3556",
    "Usman": "4347", "Aftab": "2545", "Yam Bahadur": "9999",
    "Asgar": "7536", "Uzair": "7890", "Majid": "5306",
    "Sunil": "3790", "User": "11234",
  };

  /// FIX: Static logout method used by Technician and Customer screens
  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clears 24-hour session
    if (!context.mounted) return;
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  // Logic to handle 24-hour Customer Session
  Future<void> _handleCustomerAccess(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLoginStr = prefs.getString('customer_last_login');
    final savedName = prefs.getString('customer_name');
    final savedPhone = prefs.getString('customer_phone') ?? "N/A";

    if (lastLoginStr != null && savedName != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final difference = DateTime.now().difference(lastLogin);

      // Check if 24 hours have passed
      if (difference.inHours < 24) {
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RegisterComplaintScreen(
            customerName: savedName, 
            phoneNumber: savedPhone
          )
        ));
        return;
      }
    }
    // If no session or expired, show login
    _showCustomerLoginDialog(context);
  }

  void _showCustomerLoginDialog(BuildContext context) {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    final phoneController = TextEditingController();

    void submit() async {
      String enteredName = nameController.text.trim();
      String enteredPin = pinController.text.trim();
      String enteredPhone = phoneController.text.trim().isEmpty ? "N/A" : phoneController.text.trim();

      if (_customerDatabase.containsKey(enteredName) && _customerDatabase[enteredName] == enteredPin) {
        final prefs = await SharedPreferences.getInstance();
        
        // Save session data for 24 hours
        await prefs.setString('customer_last_login', DateTime.now().toIso8601String());
        await prefs.setString('customer_name', enteredName);
        await prefs.setString('customer_phone', enteredPhone);
        await prefs.setString('user_name', enteredName); // For general audit

        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => RegisterComplaintScreen(
            customerName: enteredName, 
            phoneNumber: enteredPhone
          )
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Name or PIN"), backgroundColor: Colors.red),
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
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Customer Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: pinController, obscureText: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "PIN", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone (Optional)", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: submit, child: const Text("Login")),
        ],
      ),
    );
  }

  void _showTechLoginDialog(BuildContext context) {
    final uContent = TextEditingController();
    final pContent = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tech Login"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: uContent, decoration: const InputDecoration(hintText: "Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: pContent, obscureText: true, decoration: const InputDecoration(hintText: "PIN", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
             if (_technicianCredentials.containsKey(uContent.text.trim()) && 
                 _technicianCredentials[uContent.text.trim()] == pContent.text.trim()) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('tech_last_login', DateTime.now().toIso8601String());
                await prefs.setString('user_name', uContent.text.trim());
                if (!context.mounted) return;
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TechnicianScreen()));
             } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Tech Credentials")));
             }
          }, child: const Text("Login")),
        ],
      ),
    );
  }

  void _showAdminPinDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Admin PIN"),
        content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(hintText: "Enter PIN", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            if (controller.text == _adminPin) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('admin_last_login', DateTime.now().toIso8601String());
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminScreen()));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect Admin PIN")));
            }
          }, child: const Text("Unlock")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Maintenance App"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apartment, size: 80, color: Colors.blue),
            const SizedBox(height: 40),
            Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: [
                _buildSmallBtn(context, "Register", Colors.blue, () => _handleCustomerAccess(context)),
                _buildSmallBtn(context, "Technician", Colors.orange, () => _showTechLoginDialog(context)),
                _buildSmallBtn(context, "Admin", Colors.redAccent, () => _showAdminPinDialog(context)),
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
        backgroundColor: color, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(120, 48),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}