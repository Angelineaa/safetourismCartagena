import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_utils.dart';

class AdminMessagesScreen extends StatefulWidget {
  const AdminMessagesScreen({super.key});
  @override
  State<AdminMessagesScreen> createState() => _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends State<AdminMessagesScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _email = '';
  String _userDocId = '';
  Future<List<QueryDocumentSnapshot>>? _futureMessages;

  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser;
    _email = u?.email ?? '';

    _loadUserAndMessages();
  }

  Future<void> _loadUserAndMessages() async {
    if (_email.isNotEmpty) {
      final q = await _fire
          .collection('users')
          .where('email', isEqualTo: _email)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        _userDocId = q.docs.first.id;
      }
    }

    setState(() {
      _futureMessages = _fetchMessages();
    });
  }

  Future<List<QueryDocumentSnapshot>> _fetchMessages() async {
    Query query;

    if (_userDocId.isNotEmpty) {
      query = _fire
          .collection('messages')
          .where('recipientId', isEqualTo: _userDocId)
          .orderBy('createdAt', descending: true);
    } else {
      query = _fire
          .collection('messages')
          .where('recipientEmail', isEqualTo: _email)
          .orderBy('createdAt', descending: true);
    }

    final res = await query.get();
    return res.docs;
  }

  Future<void> _refresh() async {
    setState(() {
      _futureMessages = _fetchMessages();
    });
  }

  Future<void> _sendReply(Map<String, dynamic> original, String text) async {
    if (text.trim().isEmpty) return;

    String recipientId = (original['senderId'] ?? '').toString();
    String recipientEmail = (original['senderEmail'] ?? '').toString();

    if (recipientId.isEmpty && recipientEmail.isNotEmpty) {
      final q = await _fire
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
    }

    final payload = {
      'senderId': _userDocId.isNotEmpty ? _userDocId : null,
      'senderEmail': _email,
      'senderName': _auth.currentUser?.displayName ?? 'Admin',
      'recipientId': recipientId.isNotEmpty ? recipientId : null,
      'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'type': 'chat',
    }..removeWhere((k, v) => v == null);

    await _fire.collection('messages').add(payload);

    AdminUtils.showSnack(context, 'Reply sent');

    _refresh();
  }

  Future<void> _markRead(String id) async {
    await _fire.collection('messages').doc(id).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });

    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Messages'),
        backgroundColor: primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _futureMessages,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('No messages'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data() as Map<String, dynamic>;

              final from = (data['senderName'] ??
                      data['senderEmail'] ??
                      'Unknown')
                  .toString();

              final text =
                  (data['text'] ?? data['title'] ?? '').toString();

              final read = (data['read'] ?? false) as bool;

              return ListTile(
                tileColor: read ? null : Colors.green.withOpacity(0.06),
                leading: CircleAvatar(
                  child: Text(
                    from.isNotEmpty ? from[0].toUpperCase() : 'A',
                  ),
                ),
                title: Text(data['title']?.toString() ?? from),
                subtitle: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.reply),
                  onPressed: () async {
                    final reply = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) {
                        final ctrl = TextEditingController();
                        return Padding(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 12,
                            bottom:
                                MediaQuery.of(context).viewInsets.bottom + 12,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'Reply',
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(
                                    context, ctrl.text.trim()),
                                child: const Text('Send'),
                              ),
                            ],
                          ),
                        );
                      },
                    );

                    if (reply != null && reply.isNotEmpty) {
                      await _sendReply(data, reply);
                    }
                  },
                ),
                onTap: () {
                  _markRead(d.id);

                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title']?.toString() ?? 'Message',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(data['text']?.toString() ?? ''),
                          const SizedBox(height: 8),
                          Text('From: $from'),
                          const SizedBox(height: 8),
                          Text(
                            'Received: ${data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate().toString() : data['createdAt']?.toString() ?? '-'}',
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