import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? userRole; // 'customer', 'technician', or 'admin'
  
  const LoginScreen({super.key, this.userRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  String get _roleTitle {
    switch (widget.userRole) {
      case 'customer':
        return 'Customer';
      case 'technician':
        return 'Technician';
      case 'admin':
        return 'Admin';
      default:
        return 'User';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (user != null) {
          // Check if user role matches the selected role
          if (widget.userRole != null && user.role != widget.userRole) {
            setState(() {
              _errorMessage = 'Please login as ${widget.userRole}';
              _isLoading = false;
            });
            return;
          }

          // Navigate to appropriate dashboard based on role
          _navigateToDashboard(user.role);
        } else {
          setState(() {
            _errorMessage = 'Invalid email or password';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Login failed. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToDashboard(String role) {
    // For now, navigate to HomeScreen
    // We'll update this later with proper dashboards
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_roleTitle Login'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Logo/Icon
              Icon(
                _getRoleIcon(),
                size: 80,
                color: _getRoleColor(),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'Welcome Back, $_roleTitle!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              Text(
                'Please login to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Password Field
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 10),
              
              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('Forgot Password?'),
                ),
              ),
              
              // Error Message
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Login Button
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getRoleColor(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
              
              const SizedBox(height: 20),
              
              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RegisterScreen(
                            userRole: widget.userRole,
                          ),
                        ),
                      );
                    },
                    child: const Text('Register Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRoleIcon() {
    switch (widget.userRole) {
      case 'customer':
        return Icons.person;
      case 'technician':
        return Icons.handyman;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.login;
    }
  }

  Color _getRoleColor() {
    switch (widget.userRole) {
      case 'customer':
        return Colors.blue;
      case 'technician':
        return Colors.green;
      case 'admin':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}