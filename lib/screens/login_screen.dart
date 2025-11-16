import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Ajusta los imports según tu estructura: ejemplo si están en screens/ usa 'screens/...'
import 'home_tourist_screen.dart';
import 'proveedores/proveedor_home.dart';
import 'ambassador_screen.dart';
import 'register_screen.dart'; // <- Asegúrate que esta ruta sea la correcta (o 'screens/register_screen.dart')

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = false;

    Future<void> _showBlockedDialog() async {
    // Muestra diálogo informando en inglés
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Account blocked'),
        content: const Text(
          'Your account has been blocked. Please contact adminsafetourism@gmail.com for more information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // 1) Autenticar en Firebase Auth
      final cred = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2) Intentar obtener documento en Firestore por email
      final userEmail = emailController.text.trim();
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      // Si encontramos doc en users, comprobamos blocked
      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        final userData = userDoc.data();

        // comprobar blocked (bool o string)
        final blockedVal = userData['blocked'];
        final bool isBlocked = (blockedVal == true) ||
            (blockedVal is String && blockedVal.toString().toLowerCase() == 'true');

        if (isBlocked) {
          // cerrar sesión para evitar sesión activa
          await _auth.signOut();

          // mostrar diálogo en inglés
          await _showBlockedDialog();

          // además, mostrar snackbar breve
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account blocked. Contact sefetourism@gmail.com.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }

          return; // no continuar con redirección
        }

        // Si no está bloqueado, redirigir según campo userType / role
        final userTypeRaw = (userData['userType'] ?? userData['role'] ?? userData['type'] ?? '').toString().toLowerCase();

        if (userTypeRaw == 'tourists' || userTypeRaw == 'tourist' || userTypeRaw == 'user') {
          Navigator.pushReplacementNamed(context, '/touristHome');
          return;
        }

        if (userTypeRaw == 'providers' || userTypeRaw == 'provider' || userTypeRaw == 'vendor') {
          Navigator.pushReplacementNamed(context, '/providerHome');
          return;
        }

        if (userTypeRaw == 'ambassadors' || userTypeRaw == 'ambassador') {
          Navigator.pushReplacementNamed(context, '/ambassadorHome');
          return;
        }

        if (userTypeRaw == 'admins' || userTypeRaw == 'admin') {
          Navigator.pushReplacementNamed(context, '/adminHome');
          return;
        }

        // Fallback: tipo desconocido
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User type "$userTypeRaw" not implemented.')),
          );
        }
      } else {
        // Si no existe doc en users, intenta usar el uid para buscar en colecciones por si guardaste distinto.
        final uid = cred.user?.uid ?? '';
        if (uid.isNotEmpty) {
          final fallback = await _firestore.collection('tourists').doc(uid).get();
          if (fallback.exists) {
            Navigator.pushReplacementNamed(context, '/touristHome');
            return;
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not found in Firestore')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Error: ${e.message}';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [
        Color(0xFF007274),
        Color(0xFF6CCCE4),
        Color(0xFF9DC4B5),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Hero(tag: "logo", child: Image.asset('assets/icono.png', height: 100)),
                  const SizedBox(height: 16),
                  const Text("Safe Tourism Cartagena", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text("Welcome back! Please log in", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(controller: emailController, label: 'Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 16),
                            _buildTextField(controller: passwordController, label: 'Password', icon: Icons.lock, isPassword: true),
                            const SizedBox(height: 24),
                            _loading ? const CircularProgressIndicator() : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7D00),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 6,
                              ),
                              onPressed: _loginUser,
                              child: const Text('Login', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 18),
                            TextButton(onPressed: () {}, child: const Text("Forgot your password?", style: TextStyle(color: Color.fromARGB(255, 1, 41, 44), fontWeight: FontWeight.w600))),
                            const SizedBox(height: 12),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Text("Don't have an account? "),
                              GestureDetector(
                                onTap: () {
                                  // Usa ruta nombrada para abrir registro
                                  Navigator.pushNamed(context, '/register');
                                },
                                child: const Text("Sign Up", style: TextStyle(color: Color.fromARGB(255, 1, 41, 44), fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text("Your safety, our priority ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 5, 48, 57))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF007274)),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF007274), width: 2), borderRadius: BorderRadius.circular(15)),
      ),
      validator: (v) => v!.isEmpty ? 'Please enter $label' : null,
    );
  }
}

