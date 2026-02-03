import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:complaint_manager/firebase_options.dart';

import 'screens/home_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/technician_screen.dart';
import 'screens/register_complaint_screen.dart';
import 'services/complaint_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ComplaintService()),
      ],
      child: MaterialApp(
        title: 'Complaint Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          // FIX: Use CardThemeData instead of CardTheme
          cardTheme: const CardThemeData(elevation: 2),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const HomeScreen(),
        routes: {
          '/customer': (context) => const CustomerScreen(phoneNumber: '+1234567890'),
          '/technician': (context) => const TechnicianScreen(),
          '/register-complaint': (context) => const RegisterComplaintScreen(
                customerPhone: '+1234567890',
                customerName: 'Demo Customer',
              ),
        },
      ),
    );
  }
}