// lib/authentication/register_page.dart

import 'package:bingo/authentication/auth_service.dart';
import 'package:bingo/authentication/login_page.dart';
import 'package:bingo/dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String username = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurple],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
            child: loading
                ? const CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          'Join the Game!',
                          style: GoogleFonts.luckiestGuy(
                            textStyle: const TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        const Icon(
                          Icons.bento,
                          color: Colors.tealAccent,
                          size: 100,
                        ),
                        const SizedBox(height: 32.0),
                        _buildTextField(
                          label: 'Username',
                          icon: Icons.person_outline,
                          obscureText: false,
                          onChanged: (val) =>
                              setState(() => username = val.trim()),
                        ),
                        const SizedBox(height: 24.0),
                        _buildTextField(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          obscureText: false,
                          onChanged: (val) =>
                              setState(() => email = val.trim()),
                        ),
                        const SizedBox(height: 24.0),
                        _buildTextField(
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: true,
                          onChanged: (val) =>
                              setState(() => password = val.trim()),
                        ),
                        const SizedBox(height: 32.0),
                        _buildFuturisticButton(
                          text: 'Register',
                          onPressed: _register,
                        ),
                        const SizedBox(height: 16.0),
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              error,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 14.0),
                            ),
                          ),
                        const SizedBox(height: 24.0),
                        _buildFooterText(
                          context: context,
                          text: "Already have an account?",
                          actionText: 'Login here',
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => loading = true);
      try {
        User? user = await _authService.registerWithEmailAndPassword(
          email,
          password,
          username,
        );

        if (user != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      } catch (e) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required bool obscureText,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.tealAccent),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.tealAccent),
        filled: true,
        fillColor: Colors.grey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
        ),
      ),
      obscureText: obscureText,
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Enter $label';
        }
        if (label == 'Email' && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) {
          return 'Enter a valid email';
        }
        if (label == 'Password' && val.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      onChanged: (val) {
        onChanged(val); // Only pass non-null values
      },
    );
  }

  Widget _buildFuturisticButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.tealAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 10,
          shadowColor: Colors.tealAccent.withOpacity(0.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.roboto(
            textStyle: const TextStyle(color: Colors.black, fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterText({
    required BuildContext context,
    required String text,
    required String actionText,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
          TextButton(
            onPressed: onPressed,
            child: Text(
              actionText,
              style: const TextStyle(color: Colors.tealAccent, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
