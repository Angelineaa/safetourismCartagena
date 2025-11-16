import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  bool _loading = true;
  final _name = TextEditingController();
  final _nationality = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  DateTime? _birthDate;

  String? _userDocId;    // docId en 'users' (si quieres usarlo)
  String? _touristDocId; // docId en 'tourists' (ahora plural)

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _nationality.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No user logged in")));
        }
        setState(() => _loading = false);
        return;
      }
      final email = user.email!;

      // 1) Intentar cargar doc en 'tourists' por email (PRIORIDAD)
      try {
        final tSnap = await _fire.collection('tourists').where('email', isEqualTo: email).limit(1).get();
        if (tSnap.docs.isNotEmpty) {
          final doc = tSnap.docs.first;
          _touristDocId = doc.id;
          final data = doc.data();
          _photoUrlCtrl.text = (data['photoUrl'] ?? data['photo'] ?? '').toString();
          _name.text = (data['name'] ?? '').toString();
          _nationality.text = (data['nationality'] ?? '').toString();
          final birth = data['birthDate'] ?? data['birth_date'] ?? data['birthday'];
          if (birth != null) {
            try {
              if (birth is String) _birthDate = DateFormat('yyyy-MM-dd').parse(birth);
              else if (birth is Timestamp) _birthDate = birth.toDate();
              else if (birth is DateTime) _birthDate = birth;
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Error loading tourists doc: $e');
        // seguimos con users como fallback
      }

      // 2) Fallback: cargar doc en 'users' por email (solo si no hay tourist o para completar)
      try {
        final uSnap = await _fire.collection('users').where('email', isEqualTo: email).limit(1).get();
        if (uSnap.docs.isNotEmpty) {
          final doc = uSnap.docs.first;
          _userDocId = doc.id;
          final data = doc.data();
          // Solo rellenar campos vacíos (priorizamos datos de 'tourists')
          if (_name.text.isEmpty) _name.text = (data['name'] ?? '').toString();
          if (_nationality.text.isEmpty) _nationality.text = (data['nationality'] ?? '').toString();
          if (_photoUrlCtrl.text.isEmpty) _photoUrlCtrl.text = (data['photoUrl'] ?? data['photo'] ?? '').toString();
          final birth = data['birthDate'] ?? data['birth_date'] ?? data['birthday'];
          if (_birthDate == null && birth != null) {
            try {
              if (birth is String) _birthDate = DateFormat('yyyy-MM-dd').parse(birth);
              else if (birth is Timestamp) _birthDate = birth.toDate();
              else if (birth is DateTime) _birthDate = birth;
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('Error loading users doc: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading profile: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in")));
      return;
    }
    final email = user.email!;

    setState(() => _loading = true);
    try {
      final birthStr = _birthDate != null ? DateFormat('yyyy-MM-dd').format(_birthDate!) : null;

      // DATOS que guardaremos en collection 'tourists' (plural)
      final touristData = <String, dynamic>{
        'email': email,
        'name': _name.text.trim(),
        'nationality': _nationality.text.trim(),
        if (birthStr != null) 'birthDate': birthStr,
        if (_photoUrlCtrl.text.trim().isNotEmpty) 'photoUrl': _photoUrlCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

      // Si ya tenemos docId lo actualizamos (merge) PARA EVITAR DUPLICADOS
      if (_touristDocId != null) {
        await _fire.collection('tourists').doc(_touristDocId).set(touristData, SetOptions(merge: true));
      } else {
        // intentar buscar por email otra vez (evita crear duplicado si entre tiempo otro proceso creó el doc)
        final existing = await _fire.collection('tourists').where('email', isEqualTo: email).limit(1).get();
        if (existing.docs.isNotEmpty) {
          _touristDocId = existing.docs.first.id;
          await _fire.collection('tourists').doc(_touristDocId).set(touristData, SetOptions(merge: true));
        } else {
          // Crear nuevo documento en 'tourists' (no crea otra colección)
          final newRef = await _fire.collection('tourists').add(touristData);
          _touristDocId = newRef.id;
        }
      }

      // OPCIONAL: si quieres sincronizar también con 'users' descomenta este bloque.
      // Lo dejé comentado para respetar tu petición (guardar en 'tourists' solamente).
      /*
      if (_userDocId != null) {
        await _fire.collection('users').doc(_userDocId).set({
          'name': _name.text.trim(),
          'nationality': _nationality.text.trim(),
          if (birthStr != null) 'birthDate': birthStr,
          'photoUrl': _photoUrlCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      */

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated successfully")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_photoUrlCtrl.text.trim().isNotEmpty)
                    CircleAvatar(radius: 48, backgroundImage: NetworkImage(_photoUrlCtrl.text.trim()))
                  else
                    const Icon(Icons.person_pin_circle, color: Color(0xFF007274), size: 90),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nationality,
                    decoration: const InputDecoration(labelText: "Nationality", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _photoUrlCtrl,
                    decoration: const InputDecoration(
                      labelText: "Photo URL (image link)",
                      hintText: "https://...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.photo),
                    ),
                    keyboardType: TextInputType.url,
                    onEditingComplete: () {
                      setState(() {}); // actualizar preview
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _birthDate ?? DateTime(2000),
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _birthDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: "Birth Date", border: OutlineInputBorder()),
                      child: Text(_birthDate != null ? DateFormat('yyyy-MM-dd').format(_birthDate!) : "Select a date"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.save),
                    label: const Text("Save Changes"),
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
    );
  }
}