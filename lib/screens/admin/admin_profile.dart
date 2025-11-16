import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_utils.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _photo = TextEditingController();
  final _email = TextEditingController();

  String? _docId;
  bool _loading = true;
  bool _isLoading = false; // Guard against concurrent loads

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Guard against concurrent loads
    if (_isLoading) return;
    _isLoading = true;
    
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      _isLoading = false;
      return;
    }
    
    if (mounted) setState(() => _loading = true);
    
    _email.text = user.email ?? '';
    
    try {
      // buscar en collection 'admins' por uid primero (más rápido)
      final adminDoc = await _fire.collection('admins').doc(user.uid).get();
      if (adminDoc.exists && mounted) {
        _docId = adminDoc.id;
        final data = adminDoc.data() as Map<String, dynamic>;
        _name.text = (data['name'] ?? '').toString();
        _phone.text = (data['phone'] ?? '').toString();
        _photo.text = (data['photoUrl'] ?? '').toString();
      } else if (mounted) {
        // buscar en 'users' por uid
        final userDoc = await _fire.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          _docId = userDoc.id;
          final data = userDoc.data() as Map<String, dynamic>;
          _name.text = (data['name'] ?? '').toString();
          _phone.text = (data['phone'] ?? data['contact'] ?? '').toString();
          _photo.text = (data['photoUrl'] ?? '').toString();
        }
      }
    } catch (e) {
      debugPrint('Error loading admin profile: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
      _isLoading = false;
    }
  }

  Future<void> _save() async {
    setState(()=> _loading = true);
    try {
      if (_docId != null) {
        await _fire.collection('users').doc(_docId).set({
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'photoUrl': _photo.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      // guardar también en 'admins' collection
      await _fire.collection('admins').doc(_auth.currentUser?.uid ?? _email.text).set({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'photoUrl': _photo.text.trim(),
        'email': _email.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AdminUtils.showSnack(context, 'Profile saved', color: Colors.green);
    } catch (e) {
      AdminUtils.showSnack(context, 'Error saving: $e', color: Colors.redAccent);
    } finally {
      setState(()=> _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _photo.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Profile'), backgroundColor: primary),
      body: _loading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (_photo.text.trim().isNotEmpty)
            CircleAvatar(radius: 48, backgroundImage: NetworkImage(_photo.text.trim()))
          else
            const Icon(Icons.person, size: 90, color: Color(0xFF007274)),
          const SizedBox(height:12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(controller: _photo, decoration: const InputDecoration(labelText: 'Photo URL', border: OutlineInputBorder())),
          const SizedBox(height:12),
          TextField(controller: _email, readOnly: true, decoration: const InputDecoration(labelText: 'Email (readonly)', border: OutlineInputBorder())),
          const SizedBox(height:20),
          ElevatedButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save'), style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(double.infinity,48))),
        ]),
      ),
    );
  }
}