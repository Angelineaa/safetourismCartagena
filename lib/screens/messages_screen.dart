import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String userDocId = ''; // document id en collection 'users'
  String userEmail = '';
  String userName = '';
  bool _initializing = true; // true hasta que intentemos obtener userDocId

  @override
  void initState() {
    super.initState();
    _initCurrentUserDocId();
  }

  Future<void> _initCurrentUserDocId() async {
    setState(() => _initializing = true);
    final firebaseUser = _auth.currentUser;
    userEmail = firebaseUser?.email ?? '';
    userName = firebaseUser?.displayName ?? '';

    if (userEmail.isEmpty) {
      // no hay email, terminamos inicialización
      setState(() {
        userDocId = '';
        _initializing = false;
      });
      return;
    }

    try {
      final q = await _fire
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        userDocId = q.docs.first.id;
      } else {
        userDocId = ''; // no encontrado, fallback a email
      }
    } catch (e) {
      debugPrint('Error obtaining userDocId: $e');
      userDocId = '';
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  // marcar como leído
  Future<void> _markRead(String id) async {
    try {
      await _fire.collection('messages').doc(id).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as read')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error marked as read: $e')));
    }
  }

  /// Enviar respuesta/simple mensaje
  /// toId puede estar vacío (si no existe documento 'users' conocido)
  /// toEmail puede estar vacío — si ambos vacíos no envía.
  Future<void> _sendReply({required String toId, required String toEmail, required String text, String? title, String type = 'chat'}) async {
    if (text.trim().isEmpty) return;

    // Aseguramos que conocemos nuestro userDocId (si no, intentamos inicializar)
    if (userDocId.isEmpty && userEmail.isNotEmpty) {
      await _initCurrentUserDocId();
    }

    try {
      // Si no tenemos toId pero sí email, intentamos resolver a document id
      String? resolvedToId = toId;
      if ((resolvedToId == null || resolvedToId.isEmpty) && toEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: toEmail).limit(1).get();
          if (q.docs.isNotEmpty) resolvedToId = q.docs.first.id;
        } catch (_) {
          // ignore, seguiremos guardando recipientEmail
        }
      }

      final payload = <String, dynamic>{
        'senderId': userDocId.isNotEmpty ? userDocId : null,
        'senderEmail': userEmail.isNotEmpty ? userEmail : null,
        'senderName': userName.isNotEmpty ? userName : null,
        'recipientId': (resolvedToId != null && resolvedToId.isNotEmpty) ? resolvedToId : null,
        'recipientEmail': toEmail.isNotEmpty ? toEmail : null,
        'title': title ?? (type == 'chat' ? null : title),
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': type,
      }..removeWhere((k, v) => v == null);

      await _fire.collection('messages').add(payload);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending response: $e')));
    }
  }

  // Devuelve stream según disponibilidad de userDocId o userEmail
  Stream<QuerySnapshot> _messagesStream() {
    // Si todavía inicializando, devolvemos un stream vacío temporal (no usado porque build muestra loader)
    if (_initializing) {
      return const Stream<QuerySnapshot>.empty();
    }

    if (userDocId.isNotEmpty) {
      // filtramos por recipientId = document id
      return _fire.collection('messages').where('recipientId', isEqualTo: userDocId).orderBy('createdAt', descending: true).snapshots();
    }

    if (userEmail.isNotEmpty) {
      // fallback por email
      return _fire.collection('messages').where('recipientEmail', isEqualTo: userEmail).orderBy('createdAt', descending: true).snapshots();
    }

    // si no hay nada, stream vacío
    return const Stream<QuerySnapshot>.empty();
  }

  // Helper: show send-reply bottom sheet and return text or null
  Future<String?> _showReplySheet(BuildContext ctx, {String hint = 'Write your answer'}) {
    return showModalBottomSheet<String>(
      context: ctx,
      isScrollControlled: true,
      builder: (_) {
        final ctrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: MediaQuery.of(ctx).viewInsets.bottom + 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, maxLines: 4, decoration: InputDecoration(labelText: hint)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Send')),
          ]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    // Mientras intentamos obtener userDocId mostramos loader
    if (_initializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages'), backgroundColor: primary),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), backgroundColor: primary),
      body: StreamBuilder<QuerySnapshot>(
        stream: _messagesStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('You have no messages.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final d = docs[index];
              final data = d.data() as Map<String, dynamic>;
              final from = (data['senderEmail'] ?? data['senderId'] ?? 'unknown').toString();
              final text = (data['text'] ?? '').toString();
              final read = (data['read'] ?? false) as bool;
              final type = (data['type'] ?? 'chat').toString();

              return ListTile(
                tileColor: read ? Colors.white : Colors.green.withOpacity(0.07),
                leading: CircleAvatar(child: Text(from.isNotEmpty ? from[0].toUpperCase() : 'U')),
                title: Text(data['title']?.toString() ?? (type == 'report' ? 'Admin / Reporte' : 'Messages')),
                subtitle: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!read)
                      IconButton(
                        onPressed: () => _markRead(d.id),
                        icon: const Icon(Icons.mark_chat_read, color: Colors.green),
                        tooltip: 'Marked as read',
                      ),
                    IconButton(
                      onPressed: () async {
                        // abrir modal para escribir respuesta
                        final reply = await _showReplySheet(context);
                        if (reply != null && reply.isNotEmpty) {
                          // destinatario: preferimos original senderId, si no usar senderEmail
                          final originalSenderId = (data['senderId'] ?? '').toString();
                          final originalSenderEmail = (data['senderEmail'] ?? '').toString();

                          if ((originalSenderId.isEmpty) && originalSenderEmail.isEmpty) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró destinatario para enviar la respuesta.')));
                            return;
                          }

                          await _sendReply(toId: originalSenderId, toEmail: originalSenderEmail, text: reply);
                        }
                      },
                      icon: const Icon(Icons.reply),
                      tooltip: 'Respond',
                    ),
                  ],
                ),
                onTap: () async {
                  // marcar como leído y abrir detalle (detalle permite responder también)
                  await _markRead(d.id);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MessageDetailScreen(messageDoc: d)));
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Pantalla de detalle que permite responder también desde aquí
class MessageDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot messageDoc;
  const MessageDetailScreen({super.key, required this.messageDoc});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _reply(String toId, String toEmail) async {
    final reply = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final ctrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Your answer')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Send')),
          ]),
        );
      },
    );

    if (reply == null || reply.isEmpty) return;

    // Resolve sender info
    final user = _auth.currentUser;
    final myEmail = user?.email ?? '';
    String myDocId = '';
    if (myEmail.isNotEmpty) {
      try {
        final q = await _fire.collection('users').where('email', isEqualTo: myEmail).limit(1).get();
        if (q.docs.isNotEmpty) myDocId = q.docs.first.id;
      } catch (_) {}
    }

    // Try to resolve recipientId if not provided
    String? resolvedToId = toId;
    if ((resolvedToId == null || resolvedToId.isEmpty) && toEmail.isNotEmpty) {
      try {
        final q = await _fire.collection('users').where('email', isEqualTo: toEmail).limit(1).get();
        if (q.docs.isNotEmpty) resolvedToId = q.docs.first.id;
      } catch (_) {}
    }

    final payload = <String, dynamic>{
      'senderId': myDocId.isNotEmpty ? myDocId : null,
      'senderEmail': myEmail.isNotEmpty ? myEmail : null,
      'senderName': user?.displayName ?? null,
      'recipientId': (resolvedToId != null && resolvedToId.isNotEmpty) ? resolvedToId : null,
      'recipientEmail': toEmail.isNotEmpty ? toEmail : null,
      'text': reply,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'type': 'chat',
    }..removeWhere((k, v) => v == null);

    try {
      await _fire.collection('messages').add(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending response: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.messageDoc.data() as Map<String, dynamic>;
    final primary = const Color(0xFF007274);

    String createdAtStr = 'unknown';
    try {
      final t = data['createdAt'];
      if (t is Timestamp) createdAtStr = DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch).toString();
      else if (t is String) createdAtStr = t;
    } catch (_) {}

    final originalSenderId = (data['senderId'] ?? '').toString();
    final originalSenderEmail = (data['senderEmail'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Message details'), backgroundColor: primary),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(child: Text(((data['senderEmail'] ?? data['senderId'] ?? 'X').toString())[0].toUpperCase())),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                (data['senderName'] ?? data['senderEmail'] ?? data['senderId'] ?? 'Remitente').toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Text(data['type'] ?? ''),
          ]),
          const SizedBox(height: 12),
          Text(data['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(data['text']?.toString() ?? '', style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text('Recibido: $createdAtStr', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.reply),
                  label: const Text('Reply'),
                  onPressed: () => _reply(originalSenderId, originalSenderEmail),
                  style: ElevatedButton.styleFrom(backgroundColor: primary),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}