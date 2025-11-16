import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();

  bool _loading = true;
  String? _userDocId;
  String? _providerDocId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final email = user.email ?? '';

      // Buscar en "users"
      final userQuery =
          await _fire.collection('users').where('email', isEqualTo: email).limit(1).get();
      if (userQuery.docs.isNotEmpty) {
        final doc = userQuery.docs.first;
        _userDocId = doc.id;
        final data = doc.data();
        _nameCtrl.text = (data['name'] ?? '').toString();
        _phoneCtrl.text = (data['phone'] ?? data['contact'] ?? '').toString();
        _emailCtrl.text = (data['email'] ?? email).toString();
        _birthCtrl.text = (data['birth'] ?? '').toString();
      }

      // Buscar en "providers"
      final providerQuery =
          await _fire.collection('providers').where('email', isEqualTo: email).limit(1).get();
      if (providerQuery.docs.isNotEmpty) {
        final doc = providerQuery.docs.first;
        _providerDocId = doc.id;
        final data = doc.data();
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = (data['name'] ?? '').toString();
        if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = (data['phone'] ?? '').toString();
        if (_birthCtrl.text.isEmpty) _birthCtrl.text = (data['birth'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('Error loading provider profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final birth = _birthCtrl.text.trim();

      final dataToUpdate = {
        'name': name,
        'phone': phone,
        'email': email,
        'birth': birth,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Actualizar en users
      if (_userDocId != null) {
        await _fire.collection('users').doc(_userDocId).set(dataToUpdate, SetOptions(merge: true));
      }

      // Actualizar en providers
      if (_providerDocId != null) {
        await _fire.collection('providers').doc(_providerDocId).set(dataToUpdate, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Perfil actualizado correctamente')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al guardar cambios: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectBirthDate() async {
    final initialDate = DateTime.tryParse(_birthCtrl.text) ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) {
      _birthCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _birthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del Proveedor', style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _birthCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: _selectBirthDate,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text('Guardar cambios'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}