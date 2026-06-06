import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'region_select_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'sizing_hub_page.dart';
import 'support_page.dart';
import 'settings_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

void main() {
  runApp(const MyApp());
}

String? _readStoredToken(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key)?.trim();
  if (raw == null || raw.isEmpty || raw == 'null') return null;
  return raw.startsWith('Bearer ') ? raw.substring(7).trim() : raw;
}

bool _isValidJwtFormat(String? token) {
  if (token == null || token.isEmpty) return false;
  final parts = token.split('.');
  return parts.length == 3 && parts.every((p) => p.isNotEmpty);
}

bool _isJwtExpired(String? token) {
  if (!_isValidJwtFormat(token)) return true;
  try {
    final parts = token!.split('.');
    final payload = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload['exp'];
    if (exp == null) return false;
    final expSec = exp is int ? exp : (exp as num).toInt();
    // Refresh 5 minutes before server expiry
    return DateTime.now().millisecondsSinceEpoch >= (expSec - 300) * 1000;
  } catch (_) {
    return true;
  }
}

String? _extractAccessToken(Map<String, dynamic> data) {
  final token = data['accessToken'] ?? data['access_token'] ?? data['token'];
  if (token is String && token.isNotEmpty) return token.trim();
  return null;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Susin App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          primary: const Color(0xFFB71C1C),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = _readStoredToken(prefs, 'access_token');
    if (token == null || !_isValidJwtFormat(token) || _isJwtExpired(token)) {
      await prefs.remove('access_token');
      await prefs.remove('doc_access_token');
    }
    setState(() {
      _isLoggedIn = _readStoredToken(prefs, 'access_token') != null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _isLoggedIn ? const MainNavigation() : const LoginPage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;
  bool _isEmployee = false;
  bool _acceptedTerms = false;
  String? _error;
  bool _obscurePassword = true;
  TapGestureRecognizer? _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        final uri = Uri.parse('https://www.susingroup.com/TermsAndConditions');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _termsRecognizer?.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController(text: _emailController.text);
    bool isSubmitting = false;
    String? dialogError;
    String? dialogSuccess;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              title: Text(
                "Reset Password",
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF1E293B)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Enter your registered email address and we'll send you a secure temporary password.",
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailResetController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: const Color(0xFF1E293B)),
                    decoration: InputDecoration(
                      hintText: "Email Address",
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFB71C1C))),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8), size: 18),
                    ),
                  ),
                  if (dialogError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  if (dialogSuccess != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(dialogSuccess!, style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                  child: Text("CANCEL", style: GoogleFonts.inter(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting || dialogSuccess != null
                      ? null
                      : () async {
                          if (emailResetController.text.trim().isEmpty) {
                            setDialogState(() => dialogError = "Please enter your email.");
                            return;
                          }
                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });
                          try {
                            final res = await http.post(
                              Uri.parse('https://centralusers.susingroup.com/backend-php/api/auth/forgot_password.php'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({'email': emailResetController.text.trim()}),
                            ).timeout(const Duration(seconds: 15));
                            final data = json.decode(res.body);
                            if (res.statusCode == 200 || res.statusCode == 201) {
                              setDialogState(() {
                                dialogSuccess = "Temporary password sent! Check your inbox.";
                                isSubmitting = false;
                              });
                              Future.delayed(const Duration(seconds: 2), () {
                                Navigator.of(ctx).pop();
                              });
                            } else {
                              setDialogState(() {
                                dialogError = data['message'] ?? data['error'] ?? "Failed to send reset code.";
                                isSubmitting = false;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              dialogError = "Connection error. Try again.";
                              isSubmitting = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SEND", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _login() async {
    if (!_acceptedTerms) {
      setState(() => _error = "Please accept the Terms and Conditions for access.");
      return;
    }
    setState(() {
      _isLoggingIn = true;
      _error = null;
    });
    try {
      // 1. Login to Central Server (Primary)
      final response = await http.post(
        Uri.parse('https://centralusers.susingroup.com/backend-php/api/auth/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': _emailController.text,
          'password': _passwordController.text,
          'type': _isEmployee ? 'employee' : 'customer',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      final accessToken = _extractAccessToken(Map<String, dynamic>.from(data));
      final loginOk = response.statusCode == 200 &&
          accessToken != null &&
          _isValidJwtFormat(accessToken);

      if (loginOk) {
        // Admin Approval Check
        if (data['user'] != null && data['user']['status'] != null && data['user']['status'].toString().toLowerCase() == 'pending') {
          setState(() {
            _isLoggingIn = false;
            _error = "Access Denied: Your account is pending admin approval.";
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('user_email', _emailController.text.trim());
        
        // Save user details for Profile Page
        if (data['user'] != null) {
          await prefs.setString('user_name', data['user']['name'] ?? "User");
          await prefs.setString('user_dept', data['user']['department'] ?? "Employee");
          await prefs.setString('user_region', data['user']['region'] ?? "");
          await prefs.setString('login_type', _isEmployee ? 'employee' : 'customer');
        }

        // 2. Document Portal auth — SSO exchange, then local login fallback
        await prefs.remove('doc_access_token');
        final ssoOk = await _exchangeDocToken(accessToken);
        if (!ssoOk) {
          try {
            final docResponse = await http.post(
              Uri.parse('https://doc.susingroup.com/api/auth/login.php'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'email': _emailController.text,
                'password': _passwordController.text,
              }),
            ).timeout(const Duration(seconds: 10));
            if (docResponse.statusCode == 200) {
              final docData = json.decode(docResponse.body);
              final docToken =
                  docData['token'] ?? docData['accessToken'] ?? docData['access_token'];
              if (docToken != null) {
                await prefs.setString('doc_access_token', docToken);
              }
            }
          } catch (_) {}
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      } else {
        setState(() {
          _isLoggingIn = false;
          _error = "Login Failed (${response.statusCode}): ${data['message'] ?? 'Invalid Credentials'}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
          _error = e.toString().contains('TimeoutException')
              ? 'Connection timed out. Please check your internet and try again.'
              : 'Network Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container to ensure centering and proper fit
                Container(
                  height: MediaQuery.of(context).size.height * 0.15,
                  constraints: const BoxConstraints(minHeight: 100, maxHeight: 180),
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/susin-logo-hkea57kH.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB71C1C).withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.business_rounded,
                        size: 80,
                        color: Color(0xFFB71C1C),
                      ),
                    ),
                  ),
                 ),
                const SizedBox(height: 20),
                Text(
                  "SUSIN GROUP",
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFB71C1C),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                _buildInput(
                  _emailController,
                  "Email Address",
                  Icons.email_outlined,
                ),
                const SizedBox(height: 20),
                _buildInput(
                  _passwordController,
                  "Password",
                  Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: Text(
                      "Forgot Password?",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB71C1C),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _acceptedTerms,
                      activeColor: const Color(0xFFB71C1C),
                      onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: "I accept the ",
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
                          children: [
                            TextSpan(
                              text: "Terms and Conditions",
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                                color: Color(0xFFB71C1C),
                              ),
                              recognizer: _termsRecognizer,
                            ),
                            const TextSpan(text: " for access."),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoggingIn
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SIGN IN",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "New customer? ",
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      child: Text(
                        "Register here",
                        style: GoogleFonts.inter(
                          color: const Color(0xFFB71C1C),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Privacy Policy link — required by Play Store
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://www.susingroup.com/privacy');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    "Privacy Policy",
                    style: GoogleFonts.inter(
                      color: const Color(0xFFB71C1C),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5),
        ),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isRegistering = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://centralusers.susingroup.com/backend-php/api/auth/register.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'company_name': _companyController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
          'type': 'customer',
        }),
      ).timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      try {
        if (response.body.isNotEmpty) {
          data = json.decode(response.body) as Map<String, dynamic>;
        } else {
          throw const FormatException("Empty server response");
        }
      } catch (_) {
        throw FormatException("Server returned an invalid response (HTTP ${response.statusCode}). Please verify if register.php is uploaded and database connectivity is correct.");
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessDialog();
        }
      } else {
        setState(() {
          _error = data['message'] ?? data['error'] ?? 'Registration failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        String msg = e.toString();
        if (msg.contains('FormatException:')) {
          _error = msg.substring(msg.indexOf('FormatException:') + 16).trim();
        } else {
          _error = "Connection error: $msg";
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (ctx, a1, a2, child) {
        return Transform.scale(
          scale: a1.value,
          child: Opacity(
            opacity: a1.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              title: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 72,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Registration Successful!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Thank you for registering. Your account is now pending administrator approval.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                Center(
                  child: SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        // After registration, show login page; user will be blocked until admin approval
                        await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Sleek, modern background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Block
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Customer Registration",
                          style: GoogleFonts.plusJakartaSans( // Premium modern font
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB71C1C),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Create your account to request portal access",
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Form Container (Elegant White Card)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInput(
                          _nameController,
                          "Full Name",
                          Icons.person_outline_rounded,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                            LengthLimitingTextInputFormatter(50),
                          ],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Please enter your name";
                            if (val.trim().length < 2) return "Name must be at least 2 characters long";
                            if (!RegExp(r"^[a-zA-Z\s]+$").hasMatch(val)) {
                              return "Name must contain only letters and spaces";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInput(
                          _emailController,
                          "Email Address",
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Please enter your email";
                            final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!regex.hasMatch(val)) return "Please enter a valid email address";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInput(
                          _companyController,
                          "Company Name",
                          Icons.business_rounded,
                          validator: (val) => val == null || val.isEmpty ? "Please enter your company name" : null,
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInput(
                          _phoneController,
                          "Phone Number",
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Please enter your phone number";
                            if (val.length != 10) return "Phone number must be exactly 10 digits";
                            if (!RegExp(r"^\d{10}$").hasMatch(val)) {
                              return "Phone number must be numeric only";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInput(
                          _passwordController,
                          "Password",
                          Icons.lock_outline_rounded,
                          obscure: true,
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Please enter a password";
                            if (val.length < 8) return "Password must be at least 8 characters long";
                            if (!RegExp(r'[A-Z]').hasMatch(val)) {
                              return "Password must contain at least one uppercase letter";
                            }
                            if (!RegExp(r'[a-z]').hasMatch(val)) {
                              return "Password must contain at least one lowercase letter";
                            }
                            if (!RegExp(r'[0-9]').hasMatch(val)) {
                              return "Password must contain at least one number";
                            }
                            if (!RegExp(r'[!@#\$&*~%]').hasMatch(val)) {
                              return "Password must contain at least one special character (!@#\$&*~%)";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInput(
                          _confirmPasswordController,
                          "Confirm Password",
                          Icons.lock_outline_rounded,
                          obscure: true,
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Please confirm your password";
                            if (val != _passwordController.text) return "Passwords do not match";
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isRegistering ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isRegistering
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    "REGISTER",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.all(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _checkGuestStatus();
  }

  Future<void> _checkGuestStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGuest = prefs.getString('login_type') == 'google';
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = _isGuest
        ? [
            HomePage(onNavigate: (i) => setState(() => _selectedIndex = i)),
            const SizingHubPage(),
            const DocumentsPage(),
            const ProfilePage(),
          ]
        : [
            HomePage(onNavigate: (i) => setState(() => _selectedIndex = i)),
            const OrdersPage(),
            const SizingHubPage(),
            const DocumentsPage(),
            const ProfilePage(),
          ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          selectedItemColor: const Color(0xFFB71C1C),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          items: _isGuest
            ? const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.straighten_rounded), label: 'Sizing'),
                BottomNavigationBarItem(icon: Icon(Icons.folder_copy_rounded), label: 'Documents'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ]
            : const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_rounded), label: 'Orders'),
                BottomNavigationBarItem(icon: Icon(Icons.straighten_rounded), label: 'Sizing'),
                BottomNavigationBarItem(icon: Icon(Icons.folder_copy_rounded), label: 'Documents'),
                BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
              ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  const HomePage({super.key, this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = "User";
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "User";
      _isGuest = prefs.getString('login_type') == 'google';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        titleSpacing: 24,
        title: Row(
          children: [
            Image.asset(
              'assets/susin-logo-hkea57kH.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Welcome",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  "Susin Group of Industries",
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.black87),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (_) => false,
                  );
                }
              },
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top 2 banners covering 1/4 of the dashboard (flex: 3 of 8)
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onNavigate != null) {
                            widget.onNavigate!(_isGuest ? 0 : 1);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB71C1C), Color(0xFFE57373)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB71C1C).withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "SUSIN GROUP",
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  fontSize: 8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Manage your Orders & Files",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onNavigate != null) {
                            widget.onNavigate!(_isGuest ? 2 : 3);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB71C1C), Color(0xFFE57373)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB71C1C).withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "SUSIN GROUP",
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
                                  fontSize: 8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Explore our Products",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "Services",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              // Remaining 4 service containers covering the remaining dashboard (flex: 5 of 8)
              Builder(
                builder: (context) {
                  final List<Widget> serviceCards = [
                    if (!_isGuest)
                      _buildAppCard("Orders", "Track progress", Icons.receipt_long_rounded, const Color(0xFFB71C1C), 1),
                    _buildAppCard("Documents", _isGuest ? "Catalogs" : "GAD & Datasheet", Icons.folder_open_rounded, const Color(0xFFB71C1C), _isGuest ? 2 : 3),
                    _buildAppCard("Sizing Tool", "PDS & HD", Icons.settings_suggest_rounded, const Color(0xFFB71C1C), _isGuest ? 1 : 2),
                    _buildAppCard("Support", "Help & tickets", Icons.support_agent_rounded, const Color(0xFFB71C1C), _isGuest ? 3 : 4),
                  ];

                  return Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: serviceCards[0]),
                              const SizedBox(width: 16),
                              Expanded(child: serviceCards[1]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: serviceCards[2]),
                              const SizedBox(width: 16),
                              if (serviceCards.length > 3)
                                Expanded(child: serviceCards[3])
                              else
                                const Expanded(child: SizedBox.shrink()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(String title, String subtitle, IconData icon, Color color, int index) {
    return GestureDetector(
      onTap: () {
        if (title == "Support") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportHubPage()),
          );
        } else {
          if (widget.onNavigate != null) {
            widget.onNavigate!(index);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFBEBE9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFFB71C1C), size: 28),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  List<dynamic> _orders = [];
  bool _isLoading = false;
  String _searchQuery = "";
  String? _errorMessage;

  // Advanced Filters
  String _selectedLocation = "ALL";
  String _selectedStatus = "ALL";
  String _selectedType = "ALL TYPES";
  String _selectedRegion = "All Regions";
  String _selectedGroup = "All Product Groups";
  String _selectedRisk = "All Risks";

  DateTime? _soDateFrom;
  DateTime? _soDateTo;
  DateTime? _eddDateFrom;
  DateTime? _eddDateTo;

  Timer? _debounce;
  String? _assignedRegion;

  bool get _isRegionRestricted {
    if (_assignedRegion == null) return false;
    final r = _assignedRegion!.trim().toLowerCase();
    return r.isNotEmpty && r != 'all' && r != 'all regions';
  }

  @override
  void initState() {
    super.initState();
    _loadUserRegion();
  }

  Future<void> _loadUserRegion() async {
    final prefs = await SharedPreferences.getInstance();
    final userRegion = prefs.getString('user_region');
    if (userRegion != null && userRegion.isNotEmpty) {
      if (mounted) {
        setState(() {
          _assignedRegion = userRegion;
          _selectedRegion = _isRegionRestricted ? userRegion : "All Regions";
        });
      }
    }
    _fetchOrders();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      String url =
          'https://gm.susingroup.com/backend-php/api/orders/index.php?limit=100';
      if (_searchQuery.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(_searchQuery)}';
      }
      if (_selectedLocation != "ALL") {
        url += '&location=${Uri.encodeComponent(_selectedLocation)}';
      }
      if (_selectedStatus != "ALL") {
        url += '&status=${Uri.encodeComponent(_selectedStatus.toLowerCase())}';
      }
      if (_selectedType != "ALL TYPES") {
        url += '&type=${Uri.encodeComponent(_selectedType)}';
      }
      if (_selectedRegion != "All Regions" && _selectedRegion.toLowerCase() != "all") {
        url += '&region=${Uri.encodeComponent(_selectedRegion)}';
      }

      if (_soDateFrom != null) {
        url += '&so_date_from=${DateFormat('yyyy-MM-dd').format(_soDateFrom!)}';
      }
      if (_soDateTo != null) {
        url += '&so_date_to=${DateFormat('yyyy-MM-dd').format(_soDateTo!)}';
      }

      final response = await http
          .get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _orders = data['orders'] ?? [];
            _isLoading = false;
            
            // Sync live user region from backend response (only update if API returns it)
            final apiRegion = data['userRegion'];
            if (apiRegion != null && apiRegion.toString().trim().isNotEmpty) {
              final newRegion = apiRegion.toString().trim();
              _assignedRegion = newRegion;
              _selectedRegion = _isRegionRestricted ? newRegion : "All Regions";
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString('user_region', newRegion);
              });
            }
            // If API doesn't return userRegion, keep the locally saved region (don't remove it)
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Server Error: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Connection Error: $e";
        });
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = query;
      _fetchOrders();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedLocation = "ALL";
      _selectedStatus = "ALL";
      _selectedType = "ALL TYPES";
      _selectedRegion = _isRegionRestricted ? _assignedRegion! : "All Regions";
      _selectedGroup = "All Product Groups";
      _selectedRisk = "All Risks";
      _soDateFrom = null;
      _soDateTo = null;
      _eddDateFrom = null;
      _eddDateTo = null;
      _searchQuery = "";
      _errorMessage = null;
    });
    _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildOrderFilters(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: _fetchOrders,
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            )
                          : _orders.isEmpty
                          ? const Center(child: Text("No orders found"))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              itemCount: _orders.length,
                              itemBuilder: (context, i) {
                                return _buildOrderCard(_orders[i]);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Search SO / Customer / PO / WO...",
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: Colors.grey,
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade100),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: Colors.grey.shade100),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _companyFilterItem("ALL"),
                      _companyFilterItem("STPL"),
                      _companyFilterItem("SIIPL"),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Total Orders: ",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      "${_orders.length}",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (!_isRegionRestricted)
                  _dropdownChip(
                    "Region",
                    _selectedRegion,
                    [
                      "All Regions",
                      "DNA Team",
                      "Special Project Team",
                      "MRO Team",
                      "Qatar Team",
                      "Malaysia",
                      "UAE",
                      "Germany",
                      "Singapore",
                      "Korea"
                    ],
                    (val) {
                      setState(() => _selectedRegion = val);
                      _fetchOrders();
                    },
                  ),
                _dropdownChip(
                  "Status",
                  _selectedStatus,
                  ["ALL", "PENDING", "COMPLETED", "WIP", "DISPATCHED"],
                  (val) {
                    setState(() => _selectedStatus = val);
                    _fetchOrders();
                  },
                ),
                _dropdownChip(
                  "Type",
                  _selectedType,
                  ["ALL TYPES", "DOMESTIC", "EXPORT"],
                  (val) {
                    setState(() => _selectedType = val);
                    _fetchOrders();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyFilterItem(String label) {
    bool isSelected = _selectedLocation == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLocation = label);
        _fetchOrders();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.grey.shade100) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.red : Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _dropdownChip(
    String label,
    String currentVal,
    List<String> options,
    Function(String) onSelected,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (o) => PopupMenuItem(
              value: o,
              child: Text(o, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Text(
              currentVal == "ALL" || currentVal.startsWith("All")
                  ? label
                  : currentVal,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateFilterItem(
    String label,
    DateTime? from,
    DateTime? to,
    Function(DateTime?, DateTime?) onPicked,
  ) {
    final df = DateFormat('dd-MM-yyyy');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          GestureDetector(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (range != null) onPicked(range.start, range.end);
            },
            child: Text(
              from != null
                  ? "${df.format(from)} - ${df.format(to!)}"
                  : "dd-mm-yyyy - dd-mm-yyyy",
              style: const TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic o) {
    final orderNo = (o['salesOrderNo'] ?? o['sales_order_no'] ?? "N/A")
        .toString();
    final poNo = (o['customerPoNo'] ?? o['customer_po_no'] ?? "N/A").toString();
    final woNo = (o['workOrderNo'] ?? o['work_order_no'] ?? "N/A").toString();
    final custName =
        (o['customerName'] ?? o['customer_name'] ?? "Unknown Customer")
            .toString();
    final prodName =
        (o['productName'] ?? o['product_name'] ?? "Product Info Not Available")
            .toString();
    final value = (o['orderValue'] ?? o['order_value'] ?? "0").toString();
    final qty = (o['quantity'] ?? o['quantity'] ?? "0").toString();
    final soDate = o['salesOrderDate'] ?? o['sales_order_date'] ?? "N/A";
    final eddDate =
        o['expectedDeliveryDate'] ?? o['expected_delivery_date'] ?? "N/A";
    final leadTime = (o['leadTime'] ?? "24").toString();
    final riskPercent = (o['riskPercent'] ?? "70").toString();
    final designer =
        (o['designEngineer'] ??
                o['design_engineer'] ??
                o['engineerName'] ??
                o['assignee'] ??
                "")
            .toString();
    final location = (o['location'] ?? o['company'] ?? "STPL")
        .toString()
        .toUpperCase();

    String status = (o['status'] ?? "PENDING").toString().toUpperCase();

    // Dynamic Sub-Status Detection
    String subStatus = _getLiveStage(o);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailsPage(order: o)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SO/$orderNo",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "PO: $poNo",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "WO: $woNo",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          location,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      _dateLabel("SO DATE", soDate),
                      const SizedBox(width: 15),
                      _dateLabel("EDD", eddDate),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$leadTime DAYS LEAD TIME",
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Divider(height: 40, color: Color(0xFFF9F9F9)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              custName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prodName,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _miniInfoItem("QTY", "$qty Units"),
                          const SizedBox(height: 12),
                          _miniInfoItem("VALUE", "₹$value"),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF9F9F9)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "EXPECTED DELIVERY",
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              eddDate,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$riskPercent% RISK",
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subStatus,
                        style: const TextStyle(
                          color: Color(0xFFB71C1C),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF9F9F9)),
          ],
        ),
      ),
    );
  }

  String _getLiveStage(dynamic o) {
    const stageKeys = [
      'planningOrder',
      'gadSubmission',
      'customerGadApproval',
      'manufacturingDrawingBom',
      'automationDrawing',
      'erpBomActuator',
      'erpBomAutomation',
      'storesStockVerification',
      'rawMaterialPurchase',
      'cylinderPurchase',
      'springPurchase',
      'boughtOutPartsPurchase',
      'automationPartsPurchase',
      'productionMachining',
      'assemblyActuator',
      'painting',
      'finalAssembly',
      'quality',
      'dispatch',
    ];

    String? latestActiveOngoingStage;
    String? firstPendingStage;

    for (var key in stageKeys) {
      final stage = o[key];
      if (stage != null && stage is Map) {
        final status = (stage['status'] ?? 'PENDING').toString().toUpperCase();
        if (status == 'COMPLETED' || status == 'NA' || status == 'DISPATCHED' || status == 'SHIPPED') {
          continue;
        }
        if (status == 'WIP' || status == 'REVIEW' || status == 'PARTIAL') {
          latestActiveOngoingStage = key;
        } else if (firstPendingStage == null) {
          firstPendingStage = key;
        }
      }
    }

    final activeStageKey = latestActiveOngoingStage ?? firstPendingStage;
    if (activeStageKey != null) {
      return activeStageKey.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase();
    }
    return "DISPATCHED";
  }

  Widget _dateLabel(String label, String date) {
    return Row(
      children: [
        const Icon(Icons.calendar_today, size: 10, color: Color(0xFFB71C1C)),
        const SizedBox(width: 4),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFFB71C1C),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          date,
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFFB71C1C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _miniInfoItem(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class OrderDetailsPage extends StatelessWidget {
  final dynamic order;
  const OrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    const stageKeys = [
      'planningOrder',
      'gadSubmission',
      'customerGadApproval',
      'manufacturingDrawingBom',
      'automationDrawing',
      'erpBomActuator',
      'erpBomAutomation',
      'storesStockVerification',
      'rawMaterialPurchase',
      'cylinderPurchase',
      'springPurchase',
      'boughtOutPartsPurchase',
      'automationPartsPurchase',
      'productionMachining',
      'assemblyActuator',
      'painting',
      'finalAssembly',
      'quality',
      'dispatch',
    ];
    final stages = stageKeys.map((key) {
      final stage = order[key];
      return {
        'name': key.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase(),
        'status': stage != null ? (stage['status'] ?? 'PENDING') : 'PENDING',
      };
    }).where((s) => s['status'] != 'NA').toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Production Timeline",
          style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ORDER: SO/${order['salesOrderNo'] ?? '-'}",
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "CURRENT PROGRESS",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 40),
            ...stages.asMap().entries.map((e) => _buildStageItem(e.value, e.key == stages.length - 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceDetailCard() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _detailItem(
                "CUSTOMER PO",
                order['customerPoNo'] ?? order['customer_po_no'] ?? "N/A",
              ),
              _detailItem(
                "WORK ORDER",
                order['workOrderNo'] ?? order['work_order_no'] ?? "N/A",
              ),
              _detailItem(
                "LOCATION",
                (order['location'] ?? order['company'] ?? "STPL").toString(),
                isChip: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _detailItem(
            "PRODUCT",
            order['productName'] ?? order['product_name'] ?? "N/A",
            isFullWidth: true,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  "QUANTITY",
                  "${order['quantity'] ?? 0} units",
                ),
              ),
              Expanded(
                child: _detailItem(
                  "ORDER VALUE (INR)",
                  "₹${order['orderValue'] ?? order['order_value'] ?? 0}",
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  "ORDER VALUE (CURRENCY)",
                  "${order['orderValueCurrency'] ?? 0} ${order['currency'] ?? 'USD'}",
                ),
              ),
              Expanded(
                child: _detailItem(
                  "ORDER DATE",
                  order['salesOrderDate'] ?? order['sales_order_date'] ?? "N/A",
                ),
              ),
              Expanded(
                child: _detailItem(
                  "EXPECTED DELIVERY",
                  order['expectedDeliveryDate'] ??
                      order['expected_delivery_date'] ??
                      "N/A",
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _detailItem(
            "PENDING WEEKS",
            (order['pendingWeeks'] ?? "3").toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreDetailsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  "SALES ORDER DATE",
                  order['salesOrderDate'] ?? order['sales_order_date'] ?? "N/A",
                ),
              ),
              Expanded(
                child: _detailItem(
                  "CUSTOMER PO DATE",
                  order['customerPoDate'] ?? order['customer_po_date'] ?? "N/A",
                ),
              ),
              Expanded(
                child: _detailItem("ORDER TYPE", order['orderType'] ?? "-"),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  "PRODUCT CLASS",
                  order['productClass'] ?? "-",
                ),
              ),
              Expanded(
                child: _detailItem("CURRENCY", order['currency'] ?? "USD"),
              ),
              Expanded(child: _detailItem("STPL WO", order['stplWo'] ?? "-")),
            ],
          ),
          const SizedBox(height: 24),
          _detailItem(
            "PRODUCT DESCRIPTION",
            order['productDescription'] ?? "-",
            isFullWidth: true,
          ),
          const SizedBox(height: 24),
          _detailItem(
            "TECHNICAL DETAILS",
            order['technicalDetails'] ?? "-",
            isFullWidth: true,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _detailItem("REMARKS", order['remarks'] ?? "-")),
              Expanded(
                child: _detailItem("SOLUTION", order['solution'] ?? "-"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(
    String label,
    String val, {
    bool isChip = false,
    bool isFullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        if (isChip)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFB71C1C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              val,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB71C1C),
              ),
            ),
          )
        else
          SizedBox(
            width: isFullWidth ? null : 100,
            child: Text(
              val,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: Colors.black87,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildStageItem(Map<String, dynamic> stage, [bool isLast = false]) {
    bool isCompleted =
        stage['status'] == 'COMPLETED' || stage['status'] == 'DISPATCHED';
    bool isWIP = stage['status'] == 'WIP';
    bool isNA = stage['status'] == 'NA';
    bool isPending = stage['status'] == 'PENDING';

    Color statusColor = Colors.grey.shade400;
    IconData? iconData;

    if (isCompleted) {
      statusColor = Colors.green;
      iconData = Icons.check;
    } else if (isWIP) {
      statusColor = const Color(0xFFB71C1C);
      iconData = Icons.bolt_rounded;
    } else if (isNA) {
      statusColor = Colors.orange;
      iconData = Icons.remove;
    } else if (isPending) {
      statusColor = const Color(0xFFB71C1C).withOpacity(0.6);
      iconData = Icons.schedule_rounded;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: (isCompleted || isWIP || isNA || isPending) ? statusColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isCompleted || isWIP || isNA || isPending) ? Colors.white : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: iconData != null
                  ? Icon(iconData, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2, 
                height: 40, 
                color: isCompleted ? Colors.green.withOpacity(0.5) : Colors.grey.shade200
              ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stage['name'],
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: (isCompleted || isWIP) ? Colors.black87 : (isNA ? Colors.black54 : (isPending ? const Color(0xFFB71C1C) : Colors.grey)),
                ),
              ),
              Text(
                stage['status'],
                style: TextStyle(
                  fontSize: 9,
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = "Loading...";
  String _dept = "Employee";

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? "User";
      _dept = prefs.getString('user_dept') ?? "Employee";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFFB71C1C),
                child: Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _name.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _dept.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              _profileAction(Icons.settings_outlined, "Settings", () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                );
              }),
              _profileAction(Icons.help_outline_rounded, "Support", () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SupportHubPage()),
                );
              }),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('access_token');
                    await prefs.remove('doc_access_token');
                    await prefs.remove('user_email');
                    await prefs.remove('user_name');
                    await prefs.remove('user_dept');
                    await prefs.remove('user_region');
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFF5F5F5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "SIGN OUT",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileAction(IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black54, size: 20),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Exchange Central Users JWT for a Document Portal JWT (SSO).
Future<bool> _exchangeDocToken(String centralToken) async {
  final token = centralToken.trim();
  if (!_isValidJwtFormat(token)) return false;
  try {
    final res = await http.post(
      Uri.parse('https://doc.susingroup.com/api/auth/central_sso.php'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'accessToken': token}),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final docToken = data['token'] ?? data['accessToken'] ?? data['access_token'];
      if (docToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('doc_access_token', docToken);
        return true;
      }
    }
    // SSO exchange failed silently — fallback to local login handled by caller
  } catch (_) {
    // Network error — fallback to local login handled by caller
  }
  return false;
}

/// GET helper for doc.susingroup.com — uses doc token, refreshes via SSO on 401.
Future<http.Response?> docApiGet(String url) async {
  final prefs = await SharedPreferences.getInstance();
  var docToken = _readStoredToken(prefs, 'doc_access_token');
  final centralToken = _readStoredToken(prefs, 'access_token');

  Future<http.Response> request(String token) => http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

  if (docToken != null && docToken.isNotEmpty) {
    final res = await request(docToken);
    if (res.statusCode == 200) return res;
    if (res.statusCode == 401) {
      await prefs.remove('doc_access_token');
      docToken = null;
    }
  }

  if (centralToken != null && centralToken.isNotEmpty) {
    if (docToken == null) {
      final exchanged = await _exchangeDocToken(centralToken);
      if (exchanged) {
        docToken = prefs.getString('doc_access_token');
        if (docToken != null && docToken.isNotEmpty) {
          final res = await request(docToken);
          if (res.statusCode == 200) return res;
        }
      }
    }
    final res = await request(centralToken);
    if (res.statusCode == 200) return res;
  }

  return null;
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _catalogTabController;
  
  List<dynamic> _files = [];
  bool _isLoading = true;
  bool _isGuest = false;
  String? _authError;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<String> _fileTypes = ['All', 'GAD', 'STEP'];
  String _selectedType = 'All';

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 2, vsync: this);
    _catalogTabController = TabController(length: 5, vsync: this);
    _initDocuments();
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _catalogTabController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initDocuments() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGuest = prefs.getString('login_type') == 'google';
    });
    
    // For guests, skip remote file fetching since they only see local catalogs
    if (_isGuest) {
      setState(() => _isLoading = false);
      return;
    }

    final central = _readStoredToken(prefs, 'access_token');
    if (central == null || _isJwtExpired(central)) {
      await _forceReLogin();
      return;
    }
    await _fetchFiles();
  }

  Future<void> _forceReLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('doc_access_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _fetchFiles({String? searchQuery, String? typeFilter}) async {
    setState(() {
      _isLoading = true;
      if (searchQuery != null) _searchQuery = searchQuery;
      if (typeFilter != null) _selectedType = typeFilter;
    });
    try {
      String url = 'https://doc.susingroup.com/api/files/index.php?status=approved';
      if (_searchQuery.isNotEmpty) url += '&search=${Uri.encodeComponent(_searchQuery)}';
      if (_selectedType != 'All') url += '&file_type=${_selectedType.toLowerCase()}';

      final res = await docApiGet(url);
      if (res != null && res.statusCode == 200) {
        setState(() {
          _files = json.decode(res.body);
          _authError = null;
        });
      } else {
        setState(() => _authError = "Access denied. Please login again.");
      }
    } catch (e) {
      setState(() => _authError = "Connection Error");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Documents & Catalog", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: _isGuest ? null : TabBar(
          controller: _mainTabController,
          labelColor: const Color(0xFFB71C1C),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFB71C1C),
          tabs: const [
            Tab(text: "Files"),
            Tab(text: "Catalog"),
          ],
        ),
      ),
      body: _isGuest ? _buildCatalogTab() : TabBarView(
        controller: _mainTabController,
        children: [
          _buildFilesTab(),
          _buildCatalogTab(),
        ],
      ),
    );
  }

  Widget _buildFilesTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (v) {
              if (_debounce?.isActive ?? false) _debounce!.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () => _fetchFiles(searchQuery: v));
            },
            decoration: InputDecoration(
              hintText: "Search files...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _fileTypes.length,
            itemBuilder: (context, idx) {
              final type = _fileTypes[idx];
              final isSelected = _selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    type,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFB71C1C),
                  backgroundColor: const Color(0xFFF1F5F9),
                  checkmarkColor: Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide.none,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _fetchFiles(typeFilter: type);
                    }
                  },
                ),
              );
            },
          ),
        ),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _files.length,
                itemBuilder: (context, i) => _buildFileCard(_files[i]),
              ),
        ),
      ],
    );
  }

  Widget _buildCatalogTab() {
    return Column(
      children: [
        Container(
          color: Colors.grey.shade50,
          child: TabBar(
            controller: _catalogTabController,
            isScrollable: true,
            labelColor: const Color(0xFFB71C1C),
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "MECHANICAL"),
              Tab(text: "PNEUMATIC"),
              Tab(text: "ELECTRICAL"),
              Tab(text: "HYDRAULIC"),
              Tab(text: "ACCESSORIES"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _catalogTabController,
            children: [
              _buildCatalogGrid('Mechanical'),
              _buildCatalogGrid('Pneumatic'),
              _buildCatalogGrid('Electrical'),
              _buildCatalogGrid('Hydraulic'),
              _buildCatalogGrid('Accessories'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCatalogGrid(String category) {
    // Exact filenames from assets/Catalog/
    final Map<String, List<Map<String, String>>> catalogItems = {
      'Mechanical': [
        {'title': 'ITG SERIES CATALOG', 'path': 'assets/Catalog/ITG SERIES CATALOG-2025-DXrS_anS.pdf'},
        {'title': 'MAW SERIES CATALOG', 'path': 'assets/Catalog/MAW SERIES CATALOG-2025-D8k_GVin.pdf'},
        {'title': 'MAB SERIES CATALOG', 'path': 'assets/Catalog/MAB Series R01-DWClHMcb.pdf'},
      ],
      'Pneumatic': [
        {'title': 'PDS Actuator (Rotary)', 'path': 'assets/Catalog/1.PDS-vS1yEdug.pdf'},
        {'title': 'HD Actuator (Rotary)', 'path': 'assets/Catalog/2.HDA-Cby5k7aP.pdf'},
        {'title': 'PLDS Actuator (Linear)', 'path': 'assets/Catalog/PLDS - V2 1-DCLlukxd.pdf'},
        {'title': 'MHD Actuator (Linear)', 'path': 'assets/Catalog/3.MHDA-Ib5FnXxx.pdf'},
      ],
      'Electrical': [
        {'title': 'ITQ Heavy Duty Series', 'path': 'assets/Catalog/2.ITQ Heavy Duty Series-BqbHsGsy.pdf'},
        {'title': 'IQL Series', 'path': 'assets/Catalog/3.IQL Series-CA2Z8vSR.pdf'},
        {'title': 'ITM Series', 'path': 'assets/Catalog/4.ITM Series-FoRbtdwD.pdf'},
        {'title': 'QS Series', 'path': 'assets/Catalog/qs-C5TgHBc5.pdf'},
        {'title': 'ITL Series', 'path': 'assets/Catalog/itl-C0PgIrfi.pdf'},
        {'title': 'ITQ Micro Series', 'path': 'assets/Catalog/1.ITQ Micro Series-Owoyk-KL.pdf'},
      ],
      'Hydraulic': [
        {'title': 'HLP SERIES', 'path': 'assets/Catalog/Electro Hydraulik Actuator-vHE8plN5.pdf'},
        {'title': 'KTC HYDRAULIC', 'path': 'assets/Catalog/ktc heh-B9EzIkyN.pdf'},
        {'title': 'KTC ELECTRICAL', 'path': 'assets/Catalog/ktc2-DujpRtI8.pdf'},
      ],
      'Accessories': [
        {'title': 'ITS SERIES', 'path': 'assets/Catalog/its accessories-CCvqZ1yN.pdf'},
      ],
    };

    final items = catalogItems[category] ?? [];

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Catalog Cover Placeholder
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, size: 40, color: const Color(0xFFB71C1C).withOpacity(0.2)),
                        const SizedBox(height: 8),
                        Text(
                          category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TECHNICAL CATALOG",
                      style: TextStyle(
                        color: Color(0xFFB71C1C),
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: Text(
                        items[i]['title']!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => _launchURL(items[i]['path']),
                          child: Text(
                            "View",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _downloadFile(items[i]['path'], items[i]['title']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1C1E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.download_rounded, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  "Download",
                                  style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File path is empty")),
        );
      }
      return;
    }

    // --- HANDLE LOCAL ASSETS (Catalog) ---
    if (filePath.startsWith('assets/')) {
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Opening Catalog..."), duration: Duration(seconds: 1)),
          );
        }
        
        final byteData = await DefaultAssetBundle.of(context).load(filePath);
        final bytes = byteData.buffer.asUint8List();
        
        // Save to temp folder with proper .pdf extension
        final tempDir = await getTemporaryDirectory();
        String fileName = filePath.split('/').last;
        if (!fileName.toLowerCase().endsWith('.pdf')) fileName += ".pdf";
        
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(bytes, flush: true);
        
        // Open the file with explicit PDF type
        await OpenFilex.open(tempFile.path, type: "application/pdf");
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error opening: $e")),
          );
        }
      }
      return;
    }

    // --- HANDLE REMOTE FILES ---
    String cleanPath = filePath.trim();
    if (cleanPath.startsWith('../')) cleanPath = cleanPath.substring(3);
    if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
    
    String urlString = cleanPath.startsWith('http')
        ? cleanPath
        : "https://doc.susingroup.com/api/$cleanPath";

    final prefs = await SharedPreferences.getInstance();
    final token = _readStoredToken(prefs, 'doc_access_token');

    if (urlString.contains("doc.susingroup.com") && token != null && token.isNotEmpty) {
      urlString += (urlString.contains('?') ? '&' : '?') + "token=$token";
    }

    final encodedUrl = urlString.replaceAll(' ', '%20');
    final url = Uri.parse(encodedUrl);

    try {
      bool launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (!launched) {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open: $encodedUrl")),
        );
      }
    } catch (e) {
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: ${e2.toString()}")),
          );
        }
      }
    }
  }

  Future<void> _downloadFile(String? filePath, String fileName) async {
    if (filePath == null || filePath.isEmpty) return;

    try {
      Uint8List bytes;
      String cleanFileName = fileName.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      if (!cleanFileName.toLowerCase().endsWith('.pdf')) cleanFileName += ".pdf";

      // --- 1. FETCH BYTES ---
      if (filePath.startsWith('assets/')) {
        final data = await DefaultAssetBundle.of(context).load(filePath);
        bytes = data.buffer.asUint8List();
      } else {
        String cleanPath = filePath.trim();
        if (cleanPath.startsWith('../')) cleanPath = cleanPath.substring(3);
        if (cleanPath.startsWith('/')) cleanPath = cleanPath.substring(1);
        
        String urlString = cleanPath.startsWith('http')
            ? cleanPath
            : "https://doc.susingroup.com/api/$cleanPath";

        final prefs = await SharedPreferences.getInstance();
        final docToken = _readStoredToken(prefs, 'doc_access_token');
        final centralToken = _readStoredToken(prefs, 'access_token');
        
        http.Response? response;
        final headers = {'Accept': 'application/pdf, application/octet-stream'};

        if (docToken != null) {
          response = await http.get(
            Uri.parse(urlString.contains('?') ? "$urlString&token=$docToken" : "$urlString?token=$docToken"),
            headers: {...headers, 'Authorization': 'Bearer $docToken'},
          ).timeout(const Duration(seconds: 45));
        }

        if (response == null || response.statusCode != 200) {
          if (centralToken != null) {
            response = await http.get(
              Uri.parse(urlString.contains('?') ? "$urlString&token=$centralToken" : "$urlString?token=$centralToken"),
              headers: {...headers, 'Authorization': 'Bearer $centralToken'},
            ).timeout(const Duration(seconds: 45));
          }
        }

        if (response != null && response.statusCode == 200) {
          bytes = response.bodyBytes;
          if (bytes.length < 500) throw "Invalid file content.";
        } else {
          throw "Download failed (${response?.statusCode ?? 'Unknown'})";
        }
      }

      // --- 2. SAVE & WRITE BYTES (Crucial Step) ---
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$cleanFileName');
        await file.writeAsBytes(bytes, flush: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("File saved. Opening...")),
          );
        }
        await OpenFilex.open(file.path);
      } else {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Save PDF',
          fileName: cleanFileName,
        );

        if (result != null) {
          // We MUST write the bytes to the selected path on Android
          final file = File(result);
          await file.writeAsBytes(bytes, flush: true);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("File saved successfully!")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Widget _buildFileCard(dynamic file) {
    String type = (file['file_type'] ?? "FILE").toString().toUpperCase();
    String title = (file['title'] ?? "N/A").toString();
    String fileName = (file['file_name'] ?? "").toString();
    String? filePath = file['file_path'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _launchURL(filePath),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB71C1C).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFB71C1C), size: 20),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined,
                          size: 20, color: Colors.grey),
                      onPressed: () => _launchURL(filePath),
                      tooltip: "View",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
