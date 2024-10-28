// lib/authentication/login_page.dart

import 'package:bingo/authentication/auth_service.dart';
import 'package:bingo/authentication/register_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                          'Welcome Back!',
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
                          label: 'Email or Username',
                          icon: Icons.person,
                          obscureText: false,
                          onChanged: (val) =>
                              setState(() => email = val.trim()),
                        ),
                        const SizedBox(height: 24.0),
                        _buildTextField(
                          label: 'Password',
                          icon: Icons.lock,
                          obscureText: true,
                          onChanged: (val) =>
                              setState(() => password = val.trim()),
                        ),
                        const SizedBox(height: 32.0),
                        _buildFuturisticButton(
                          text: 'Login',
                          onPressed: _signIn,
                        ),
                        const SizedBox(height: 16.0),
                        _buildForgotPasswordText(),
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
                          text: "Don't have an account?",
                          actionText: 'Register here',
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const RegisterPage()),
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

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => loading = true);
      try {
        // Ensure the email and password are not null
        String? emailValue = email.isNotEmpty ? email : null;
        String? passwordValue = password.isNotEmpty ? password : null;

        if (emailValue != null && passwordValue != null) {
          User? user = await _authService.signInWithEmailOrUsernameAndPassword(
            emailValue,
            passwordValue,
          );

          if (user != null) {
            // Navigate to the dashboard and clear the back stack
            Navigator.pushNamedAndRemoveUntil(
                context, '/dashboard', (route) => false);
          }
        } else {
          setState(() {
            error = 'Email or password cannot be null';
          });
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
      validator: (val) => val != null && val.isEmpty
          ? 'Enter $label'
          : null, // Make sure val is not null
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

  Widget _buildForgotPasswordText() {
    return TextButton(
      onPressed: _showForgotPasswordDialog,
      child: const Text(
        'Forgot Password?',
        style: TextStyle(color: Colors.tealAccent, fontSize: 16),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String resetEmail = '';
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            onChanged: (val) => resetEmail = val.trim(),
            decoration: const InputDecoration(
              hintText: 'Enter your registered email',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
              ),
              onPressed: () async {
                try {
                  await _authService.resetPassword(resetEmail);
                  Navigator.pop(context);
                  _showSnackBar('Password reset link sent!', Colors.green);
                } catch (e) {
                  Navigator.pop(context);
                  _showSnackBar(e.toString(), Colors.red);
                }
              },
              child: const Text('Send Reset Link'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
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
