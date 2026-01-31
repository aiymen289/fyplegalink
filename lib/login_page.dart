import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import 'global_widgets.dart';
import 'home_client.dart';
import 'lawyer_home_wrapper.dart';
import 'home_admin.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _formKey = GlobalKey<FormState>();

  // Text keys for translation
  static const Map<String, String> _texts = {
    'app_name': 'Legal Connect',
    'login_title': 'Login to continue',
    'email_label': 'Email',
    'email_hint': 'Enter your email',
    'password_label': 'Password',
    'password_hint': 'Enter your password',
    'login_button': 'Login',
    'back_to_role': 'Back to Role Selection',
    'email_required': 'Please enter your email',
    'email_invalid': 'Please enter a valid email',
    'password_required': 'Please enter your password',
    'password_short': 'Password must be at least 6 characters',
    'user_not_found': 'No user found with this email.',
    'wrong_password': 'Incorrect password.',
    'invalid_email': 'Invalid email address.',
    'user_disabled': 'This account has been disabled.',
    'login_failed': 'Login failed. Please try again.',
    'role_not_found': 'User role not found. Please contact support.',
    'checking_role_error': 'Error checking user role',
    'pending_approval': 'Your account is pending admin approval.',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<LanguageProvider>(context, listen: false);
      provider.registerTexts(_texts);
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Sign in with Firebase
        final userCredential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = userCredential.user;
        if (user != null) {
          // Check user role and redirect accordingly
          await _redirectBasedOnRole(user.uid);
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });

        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = languageProvider.translate('user_not_found',
                defaultValue: 'No user found with this email.');
            break;
          case 'wrong-password':
            message = languageProvider.translate('wrong_password',
                defaultValue: 'Incorrect password.');
            break;
          case 'invalid-email':
            message = languageProvider.translate('invalid_email',
                defaultValue: 'Invalid email address.');
            break;
          case 'user-disabled':
            message = languageProvider.translate('user_disabled',
                defaultValue: 'This account has been disabled.');
            break;
          default:
            message = languageProvider.translate('login_failed',
                defaultValue: 'Login failed. Please try again.');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _redirectBasedOnRole(String userId) async {
    try {
      // First check if user is a client
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(userId)
          .get();

      if (clientDoc.exists) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ClientHome(),
            ),
          );
        }
        return;
      }

      // Check if user is a lawyer
      final lawyerDoc = await FirebaseFirestore.instance
          .collection('lawyers')
          .doc(userId)
          .get();

      if (lawyerDoc.exists) {
        final isApproved = lawyerDoc.data()?['isApproved'] ?? false;

        if (mounted) {
          if (isApproved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LawyerHomeWrapper(),
              ),
            );
          } else {
            final languageProvider =
                Provider.of<LanguageProvider>(context, listen: false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(languageProvider.translate('pending_approval',
                    defaultValue: 'Your account is pending admin approval.')),
                backgroundColor: Colors.orange,
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
        }
        return;
      }

      // Check if user is an admin
      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(userId)
          .get();

      if (adminDoc.exists) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminHome(),
            ),
          );
        }
        return;
      }

      // If no role found
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.translate('role_not_found',
                defaultValue: 'User role not found. Please contact support.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${languageProvider.translate('checking_role_error', defaultValue: 'Error checking user role')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade700, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Language Switch in AppBar style
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: Icon(
                        languageProvider.isUrdu
                            ? Icons.arrow_forward
                            : Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // Title
                    Expanded(
                      child: Center(
                        child: TranslatableText(
                          textKey: 'app_name',
                          englishText: _texts['app_name']!,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Language Switch
                    const GlobalLanguageSwitch(),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Logo/Header
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.gavel,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TranslatableText(
                        textKey: 'app_name',
                        englishText: _texts['app_name']!,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      TranslatableText(
                        textKey: 'login_title',
                        englishText: _texts['login_title']!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Login Form
                      Form(
                        key: _formKey,
                        child: Card(
                          elevation: 10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                              children: [
                                // Email Field
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: languageProvider.translate(
                                        'email_label',
                                        defaultValue: _texts['email_label']!),
                                    hintText: languageProvider.translate(
                                        'email_hint',
                                        defaultValue: 'Enter your email'),
                                    prefixIcon: const Icon(Icons.email),
                                    border: const OutlineInputBorder(),
                                    labelStyle: TextStyle(
                                      color: languageProvider.isUrdu
                                          ? Colors.teal
                                          : null,
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  textDirection: languageProvider.isUrdu
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return languageProvider.translate(
                                          'email_required',
                                          defaultValue:
                                              _texts['email_required']!);
                                    }
                                    if (!value.contains('@')) {
                                      return languageProvider.translate(
                                          'email_invalid',
                                          defaultValue:
                                              _texts['email_invalid']!);
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: languageProvider.translate(
                                        'password_label',
                                        defaultValue:
                                            _texts['password_label']!),
                                    hintText: languageProvider.translate(
                                        'password_hint',
                                        defaultValue: 'Enter your password'),
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: const OutlineInputBorder(),
                                    labelStyle: TextStyle(
                                      color: languageProvider.isUrdu
                                          ? Colors.teal
                                          : null,
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  textDirection: languageProvider.isUrdu
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return languageProvider.translate(
                                          'password_required',
                                          defaultValue:
                                              _texts['password_required']!);
                                    }
                                    if (value.length < 6) {
                                      return languageProvider.translate(
                                          'password_short',
                                          defaultValue:
                                              _texts['password_short']!);
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 30),
                                // Login Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : TranslatableText(
                                            textKey: 'login_button',
                                            englishText:
                                                _texts['login_button']!,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Back Button
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: TranslatableText(
                                    textKey: 'back_to_role',
                                    englishText: _texts['back_to_role']!,
                                    style: const TextStyle(
                                      color: Colors.teal,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
