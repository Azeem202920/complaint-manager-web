import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? userRole;
  
  const RegisterScreen({super.key, this.userRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String get _roleTitle {
    switch (widget.userRole) {
      case 'customer':
        return 'Customer';
      case 'technician':
        return 'Technician';
      default:
        return 'User';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      // Check if passwords match
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final user = await authService.registerUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: widget.userRole ?? 'customer',
        );

        if (user != null) {
          // Registration successful, navigate to login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(userRole: widget.userRole),
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Registration failed. Please try again.';
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Registration failed: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_roleTitle Registration'),
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
              const SizedBox(height: 20),
              
              // Icon
              Icon(
                _getRoleIcon(),
                size: 80,
                color: _getRoleColor(),
              ),
              
              const SizedBox(height: 10),
              
              Text(
                'Create $_roleTitle Account',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              Text(
                'Fill in your details to create an account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 30),
              
              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  if (value.length < 3) {
                    return 'Name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Email Field
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
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
              
              // Phone Field
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (value.length < 10) {
                    return 'Please enter a valid phone number';
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
              // Confirm Password Field
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: _obscureConfirmPassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              
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
              
              // Register Button
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
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
                        'Create Account',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
              
              const SizedBox(height: 20),
              
              // Already have account link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginScreen(userRole: widget.userRole),
                        ),
                      );
                    },
                    child: const Text('Login Now'),
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
      default:
        return Icons.person_add;
    }
  }

  Color _getRoleColor() {
    switch (widget.userRole) {
      case 'customer':
        return Colors.blue;
      case 'technician':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }
}