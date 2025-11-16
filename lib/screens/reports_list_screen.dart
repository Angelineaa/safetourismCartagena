import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String currentUserEmail = '';
  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final u = _auth.currentUser;
    currentUserEmail = u?.email ?? '';
    try {
      final q = await _fire.collection('users').where('email', isEqualTo: currentUserEmail).limit(1).get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        final t = (d['userType'] ?? '').toString().toLowerCase();
        _isAdmin = t == 'admins' || t == 'admin';
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text(_isAdmin ? 'Reportes (Admin)' : 'Mis reportes'), backgroundColor: primary),
      body: StreamBuilder<QuerySnapshot>(
        stream: _isAdmin
            ? _fire.collection('reports').orderBy('date', descending: true).snapshots()
            : _fire.collection('reports').where('userEmail', isEqualTo: currentUserEmail).orderBy('date', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No hay reportes.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final status = d['status'] ?? 'Desconocido';
              final title = d['incidentType'] ?? 'Reporte';
              final date = d['date'];
              String dateStr = 'Sin fecha';
              try {
                if (date is Timestamp) dateStr = date.toDate().toString();
                else if (date is String) dateStr = date;
              } catch (_) {}

              return ListTile(
                tileColor: Colors.white,
                // No mostramos la imagen completa; si hay evidenceUrl mostramos avatar genérico
                leading: CircleAvatar(child: Text((d['userEmail'] ?? 'U').toString()[0].toUpperCase())),
                title: Text(title),
                subtitle: Text('${d['location'] ?? ''}\n$dateStr'),
                isThreeLine: true,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
                onTap: () {
                  // enviamos el QueryDocumentSnapshot como argumento (reportDoc)
                  Navigator.pushNamed(
                    context,
                    '/reportDetail',
                    arguments: {'reportDoc': docs[i], 'isAdmin': _isAdmin},
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}