import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_utils.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});
  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _email = '';
  String _userDocId = '';
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _futureNotifications;

  @override
  void initState() {
    super.initState();
    _initUserAndLoad();
  }

  Future<void> _initUserAndLoad() async {
    final u = _auth.currentUser;
    _email = u?.email ?? '';

    if (_email.isNotEmpty) {
      try {
        final q = await _fire
            .collection('users')
            .where('email', isEqualTo: _email)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          _userDocId = q.docs.first.id;
        }
      } catch (e) {
        debugPrint('Error buscando user docId: $e');
      }
    }

    setState(() {
      _futureNotifications = _fetchNotifications();
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchNotifications() async {
    Query<Map<String, dynamic>> query;

    if (_userDocId.isNotEmpty) {
      query = _fire
          .collection('notifications')
          .where('recipientId', isEqualTo: _userDocId);
    } else {
      query = _fire
          .collection('notifications')
          .where('recipientEmail', isEqualTo: _email);
    }

    final result = await query.get();

    final docs = result.docs.toList();

    // ordenar localmente (desc)
    docs.sort((a, b) {
      final da = _extractCreatedAt(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = _extractCreatedAt(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });

    return docs;
  }

  Future<void> _refresh() async {
    setState(() {
      _futureNotifications = _fetchNotifications();
    });
  }

  Future<void> _markRead(String id) async {
    try {
      await _fire.collection('notifications').doc(id).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      AdminUtils.showSnack(context, 'Marked read');
      _refresh();
    } catch (e) {
      AdminUtils.showSnack(context, 'Error: $e', color: Colors.redAccent);
    }
  }

  DateTime? _extractCreatedAt(Map<String, dynamic> data) {
    final c = data['createdAt'];
    if (c == null) return null;
    if (c is Timestamp) return c.toDate();
    if (c is DateTime) return c;
    try {
      return DateTime.parse(c.toString());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Notifications'),
        backgroundColor: primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _futureNotifications,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading notifications:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final title = data['title'] ?? data['type'] ?? 'Notification';
              final text = data['text'] ?? '';
              final read = (data['read'] ?? false) as bool;
              final created = _extractCreatedAt(data);

              return ListTile(
                tileColor: read ? null : Colors.green.withOpacity(0.06),
                title: Text(title.toString()),
                subtitle: Text(
                  text.toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.mark_chat_read),
                  onPressed: () => _markRead(d.id),
                ),
                onTap: () {
                  if (!read) _markRead(d.id);

                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title.toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(text.toString()),
                          const SizedBox(height: 8),
                          Text(
                            'Created: ${created != null ? created.toString() : (data['createdAt']?.toString() ?? '-') }',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
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