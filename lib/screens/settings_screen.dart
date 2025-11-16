import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  bool _loading = true;
  bool _notifications = true;
  bool _publicProfile = true;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _fire
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('prefs')
        .get();
    if (snap.exists) {
      final d = snap.data()!;
      _notifications = d['notifications'] ?? true;
      _language = d['language'] ?? 'English';
      _publicProfile = d['publicProfile'] ?? true;
    }
    setState(() => _loading = false);
  }

  Future<void> _saveSettings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _fire
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('prefs')
        .set({
      'notifications': _notifications,
      'language': _language,
      'publicProfile': _publicProfile,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Settings saved")));
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "Are you sure you want to permanently delete your account? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _fire.collection('users').doc(user.uid).delete();
      await user.delete();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/start', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Push Notifications"),
                    subtitle: const Text(
                        "Receive alerts about reservations and messages."),
                    value: _notifications,
                    onChanged: (v) => setState(() => _notifications = v),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("Language"),
                    subtitle: Text(_language),
                    trailing: DropdownButton<String>(
                      value: _language,
                      items: const [
                        DropdownMenuItem(value: "English", child: Text("English")),
                        DropdownMenuItem(value: "Español", child: Text("Español")),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _language = v);
                          _saveSettings();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(v == "Español"
                                  ? "Idioma cambiado a Español"
                                  : "Language switched to English")));
                        }
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: const Text("Public Profile"),
                    subtitle:
                        const Text("Allow others to view your profile information."),
                    value: _publicProfile,
                    onChanged: (v) => setState(() => _publicProfile = v),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete Account"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
    );
  }
}