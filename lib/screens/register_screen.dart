import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controladores
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController(); // <- nuevo
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nationalityController = TextEditingController();
  String? userType;
  DateTime? birthDate;
  bool _loading = false;

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (userType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user type')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2) Preparar datos comunes
      final birthDateString = birthDate != null ? DateFormat('yyyy-MM-dd').format(birthDate!) : '';
      int age = 0;
      if (birthDate != null) {
        age = DateTime.now().year - birthDate!.year;
        if (DateTime.now().month < birthDate!.month ||
            (DateTime.now().month == birthDate!.month && DateTime.now().day < birthDate!.day)) {
          age--;
        }
      }

      final userIdField = idController.text.trim();
      final userData = {
        "id": userIdField,
        "name": nameController.text.trim(),
        "birthDate": birthDateString,
        "age": age,
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(), // <- agregado
        "nationality": nationalityController.text.trim(),
        "userType": userType,
        "createdAt": FieldValue.serverTimestamp(),
      };

      // 3) Guardar en collection 'users' usando como ID el campo id (según tu diseño)
      await _firestore.collection('users').doc(userIdField).set(userData);

      // 4) Guardar en colección específica (tourists/providers/ambassadors/admins) usando el mismo id
      final collectionName = userType!.toLowerCase(); // esperamos 'tourists','providers','ambassadors','admins'
      await _firestore.collection(collectionName).doc(userIdField).set({
        "id": userIdField,
        "name": nameController.text.trim(),
        "email": emailController.text.trim(),
        "phone": phoneController.text.trim(), // <- propagate phone
        "nationality": nationalityController.text.trim(),
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 5) Si ambassador, crear doc adicional con uid del auth (opcional) también con phone
      if (collectionName == 'ambassadors') {
        await _firestore.collection('ambassadors').doc(userCredential.user!.uid).set({
          'idAmbassador': userCredential.user!.uid,
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'photoUrl': '',
          'languages': [],
          'experience': '',
          'availability': 'Available',
          'rating': 0.0,
          'pricePerHour': '0 USD',
          'description': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User registered successfully!')),
      );

      // Redirigir según tipo (usa las rutas que tengas en main.dart)
      if (collectionName == 'tourists') {
        Navigator.pushReplacementNamed(context, '/touristHome');
      } else if (collectionName == 'providers') {
        Navigator.pushReplacementNamed(context, '/providerHome');
      } else if (collectionName == 'ambassadors') {
        Navigator.pushReplacementNamed(context, '/ambassadorHome');
      } else if (collectionName == 'admins') {
        Navigator.pushReplacementNamed(context, '/adminHome');
      } else {
        // admins o fallback
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Registration error';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auth error: $msg')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    idController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nationalityController.dispose();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // logo y títulos
                Column(
                  children: [
                    Image.asset('assets/icono.png', height: 90),
                    const SizedBox(height: 10),
                    const Text("Safe Tourism Cartagena", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text("Create your account", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(controller: nameController, label: 'Full Name', icon: Icons.person),
                          _buildTextField(controller: idController, label: 'ID Number', icon: Icons.badge),
                          GestureDetector(
                            onTap: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => birthDate = picked);
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: birthDate == null ? 'Birth Date' : DateFormat('yyyy-MM-dd').format(birthDate!),
                                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                                ),
                                validator: (v) => birthDate == null ? 'Select birth date' : null,
                              ),
                            ),
                          ),
                          _buildTextField(controller: nationalityController, label: 'Nationality', icon: Icons.flag),

                          // Nuevo: Phone number
                          _buildTextField(
                            controller: phoneController,
                            label: 'Phone Number (e.g. +57 300 1234567)',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                          ),

                          DropdownButtonFormField<String>(
                            value: userType,
                            decoration: const InputDecoration(labelText: 'User Type', prefixIcon: Icon(Icons.group)),
                            items: const [
                              DropdownMenuItem(value: 'tourists', child: Text('Tourist')),
                              DropdownMenuItem(value: 'providers', child: Text('Provider')),
                              DropdownMenuItem(value: 'ambassadors', child: Text('Ambassador')),
                              DropdownMenuItem(value: 'admins', child: Text('Admin')),
                            ],
                            onChanged: (v) => setState(() => userType = v),
                            validator: (v) => v == null ? 'Select user type' : null,
                          ),
                          _buildTextField(controller: emailController, label: 'Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                          _buildTextField(controller: passwordController, label: 'Password', icon: Icons.lock, isPassword: true),
                          _buildTextField(controller: confirmPasswordController, label: 'Confirm Password', icon: Icons.lock_outline, isPassword: true),
                          const SizedBox(height: 18),
                          _loading
                              ? const CircularProgressIndicator()
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7D00), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 6),
                                  onPressed: _registerUser,
                                  child: const Text("Register", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                          const SizedBox(height: 12),
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Already have an account? Log in", style: TextStyle(color: Color(0xFF00695C)))),
                        ],
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: const Color(0xFF007274)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
        validator: (v) => v == null || v.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }
}