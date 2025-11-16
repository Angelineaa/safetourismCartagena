import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AmbassadorNotificationsScreen extends StatefulWidget {
  const AmbassadorNotificationsScreen({super.key});

  @override
  State<AmbassadorNotificationsScreen> createState() =>
      _AmbassadorNotificationsScreenState();
}

class _AmbassadorNotificationsScreenState
    extends State<AmbassadorNotificationsScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _email = '';
  String _userDocId = ''; // si el embajador tiene docId en 'users'
  bool _loading = true;
  String _error = '';

  // toggle: 0 = Bookings, 1 = Messages
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAmbassador();
  }

  Future<void> _initAmbassador() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'No hay sesión activa.';
          _loading = false;
        });
        return;
      }
      _email = user.email ?? '';

      // intentamos encontrar documentId en collection 'users'
      if (_email.isNotEmpty) {
        final q = await _fire
            .collection('users')
            .where('email', isEqualTo: _email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) _userDocId = q.docs.first.id;
      }
    } catch (e) {
      _error = 'Error cargando datos: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  // Stream de bookings (servicio_ambajador) filtrado por ambassadorEmail o ambassadorId
  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingsStream() {
    // preferimos filtrar por ambassadorEmail porque tu código guardaba eso
    if (_email.isNotEmpty) {
      return _fire
          .collection('servicio_ambajador')
          .where('ambassadorEmail', isEqualTo: _email)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    // fallback: streams vacíos
    return const Stream.empty();
  }

  // Stream de messages: filtrar por recipientEmail o recipientId
  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream() {
    if (_userDocId.isNotEmpty) {
      // preferimos recipientId (document id)
      return _fire
          .collection('messages')
          .where('recipientId', isEqualTo: _userDocId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (_email.isNotEmpty) {
      return _fire
          .collection('messages')
          .where('recipientEmail', isEqualTo: _email)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  /// Actualiza estado de booking y notifica al turista.
  /// Ajustes: siempre intenta incluir recipientEmail; añade senderPhone (teléfono del embajador).
  Future<void> _updateStatusAndNotify(String docId, String status) async {
  try {
    final docRef = _fire.collection('servicio_ambajador').doc(docId);
    final snap = await docRef.get();
    final data = snap.data() ?? {};

    // actualizar estado
    await docRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // preparar destinatario (turista)
    String recipientId = '';
    String recipientEmail = '';
    String touristName = '';

    // posibles keys para id/email/nombre en el documento de reserva
    final possibleIdKeys = ['userId', 'requesterId', 'requester_id', 'requester'];
    final possibleEmailKeys = ['userEmail', 'requesterEmail', 'email', 'requester_email', 'user_email'];
    final possibleNameKeys = ['nombreReserva', 'userName', 'requesterName', 'name'];

    for (var k in possibleIdKeys) {
      if ((data[k] ?? '').toString().isNotEmpty) {
        recipientId = data[k].toString();
        break;
      }
    }
    for (var k in possibleEmailKeys) {
      if ((data[k] ?? '').toString().isNotEmpty) {
        recipientEmail = data[k].toString();
        break;
      }
    }
    for (var k in possibleNameKeys) {
      if ((data[k] ?? '').toString().isNotEmpty) {
        touristName = data[k].toString();
        break;
      }
    }

    // Si no tenemos recipientId pero sí email, intentar resolverlo en collection 'users'
    if (recipientId.isEmpty && recipientEmail.isNotEmpty) {
      try {
        final q = await _fire.collection('users').where('email', isEqualTo: recipientEmail).limit(1).get();
        if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
      } catch (_) {}
    }

    // Si no tenemos recipientEmail pero sí recipientId, intentar obtener email desde users doc
    if (recipientEmail.isEmpty && recipientId.isNotEmpty) {
      try {
        final q = await _fire.collection('users').doc(recipientId).get();
        if (q.exists) {
          final u = q.data() ?? {};
          recipientEmail = (u['email'] ?? u['userEmail'] ?? '').toString();
          if (touristName.isEmpty) touristName = (u['name'] ?? u['fullName'] ?? '').toString();
        }
      } catch (_) {}
    }

    // resolver phone del embajador (senderPhone) desde el doc 'users' del embajador (_userDocId) o buscando por email
    String senderPhone = '';
    try {
      if (_userDocId.isNotEmpty) {
        final q = await _fire.collection('users').doc(_userDocId).get();
        if (q.exists) {
          final ud = q.data() ?? {};
          senderPhone = (ud['phone'] ?? ud['telefono'] ?? ud['mobile'] ?? ud['phoneNumber'] ?? '').toString();
        }
      } else if (_email.isNotEmpty) {
        final q = await _fire.collection('users').where('email', isEqualTo: _email).limit(1).get();
        if (q.docs.isNotEmpty) {
          final ud = q.docs.first.data();
          senderPhone = (ud['phone'] ?? ud['telefono'] ?? ud['mobile'] ?? ud['phoneNumber'] ?? '').toString();
        }
      }
    } catch (_) {
      // ignore
    }

    final ambassadorName = _auth.currentUser?.displayName ?? _email ?? 'Ambassador';

    // TITLE / BODY en INGLÉS para el turista
    final title = status == 'Accepted' ? 'Booking accepted' : 'Booking rejected';
    var body = status == 'Accepted'
        ? 'Your tour request for ${data['serviceName'] ?? 'the service'} on ${_formatDate(data['date'] ?? data['fecha'])} has been accepted by $ambassadorName.'
        : 'Your tour request for ${data['serviceName'] ?? 'the service'} on ${_formatDate(data['date'] ?? data['fecha'])} has been rejected by $ambassadorName.';

    // incluir información extra en el texto (hora / place) si existe
    final extraParts = <String>[];
    if ((data['time'] ?? data['hora'] ?? '').toString().isNotEmpty) {
      extraParts.add('Time: ${data['time'] ?? data['hora']}');
    }
    if ((data['place'] ?? data['lugar'] ?? '').toString().isNotEmpty) {
      extraParts.add('Place: ${data['place'] ?? data['lugar']}');
    }
    if (extraParts.isNotEmpty) {
      // añadimos al final del body en inglés
      body += '\n' + extraParts.join('\n');
    }

    // crear mensaje en collection 'messages' asegurando recipientEmail + senderPhone
    final msg = {
      'senderId': _userDocId.isNotEmpty ? _userDocId : null,
      'senderEmail': _email,
      'senderName': ambassadorName,
      'senderPhone': senderPhone.isNotEmpty ? senderPhone : null, // nuevo campo
      'recipientId': recipientId.isNotEmpty ? recipientId : null,
      'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
      'title': title,
      'text': body,
      'reservationId': docId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'type': 'reservation_status',
    }..removeWhere((k, v) => v == null);

    await _fire.collection('messages').add(msg);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Solicitud ${status == 'Accepted' ? 'aceptada' : 'rechazada'} y usuario notificado.'),
      backgroundColor: status == 'Accepted' ? Colors.green : Colors.redAccent,
    ));
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando estado: $e')));
  }
 } 

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) return DateFormat('yyyy-MM-dd').format(date.toDate());
      if (date is DateTime) return DateFormat('yyyy-MM-dd').format(date);
      return date?.toString() ?? '-';
    } catch (_) {
      return date.toString();
    }
  }

  Future<void> _markMessageRead(String messageDocId) async {
    try {
      await _fire.collection('messages').doc(messageDocId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // enviar respuesta corta desde embajador a usuario
  Future<void> _sendReplyToMessage(Map<String, dynamic> original, String replyText) async {
    if (replyText.trim().isEmpty) return;
    try {
      String recipientId = (original['senderId'] ?? '').toString();
      String recipientEmail = (original['senderEmail'] ?? '').toString();

      // si no tenemos recipientId pero sí email, intentar resolverlo
      if (recipientId.isEmpty && recipientEmail.isNotEmpty) {
        final q = await _fire.collection('users').where('email', isEqualTo: recipientEmail).limit(1).get();
        if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
      }

      // obtener phone del embajador para incluir en el reply (opcional)
      String senderPhone = '';
      try {
        if (_userDocId.isNotEmpty) {
          final q = await _fire.collection('users').doc(_userDocId).get();
          if (q.exists) {
            final ud = q.data() ?? {};
            senderPhone = (ud['phone'] ?? ud['telefono'] ?? ud['mobile'] ?? ud['phoneNumber'] ?? '').toString();
          }
        }
      } catch (_) {}

      final payload = {
        'senderId': _userDocId.isNotEmpty ? _userDocId : null,
        'senderEmail': _email,
        'senderName': _auth.currentUser?.displayName ?? _email,
        'senderPhone': senderPhone.isNotEmpty ? senderPhone : null,
        'recipientId': recipientId.isNotEmpty ? recipientId : null,
        'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
        'text': replyText.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'chat',
      }..removeWhere((k, v) => v == null);

      await _fire.collection('messages').add(payload);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respuesta enviada')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error enviando respuesta: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones'), backgroundColor: primary),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones'), backgroundColor: primary),
        body: Center(child: Text(_error)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones'), backgroundColor: primary),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ToggleButtons(
              isSelected: [ _tabIndex == 0, _tabIndex == 1 ],
              onPressed: (i) => setState(() => _tabIndex = i),
              borderRadius: BorderRadius.circular(8),
              selectedColor: Colors.white,
              fillColor: primary,
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text('Bookings')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Text('Messages')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _tabIndex == 0 ? _buildBookingsList() : _buildMessagesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _bookingsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No tienes nuevas contrataciones.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final id = doc.id;
            final date = _formatDate(d['date'] ?? d['fecha'] ?? d['createdAt']);
            final duration = d['duration'] ?? d['duracion'] ?? 'N/A';
            final payment = d['paymentMethod'] ?? d['payment'] ?? '-';
            final status = (d['status'] ?? 'Pending').toString();

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF007274), child: Icon(Icons.person, color: Colors.white)),
                title: const Text('Solicitud de tour', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),
                  Text('Fecha: $date'),
                  Text('Duración: $duration horas'),
                  Text('Pago: $payment'),
                  Text('Estado: $status'),
                ]),
                isThreeLine: true,
                trailing: status == 'Pending'
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), tooltip: 'Aceptar', onPressed: () => _confirmAcceptReject(id, 'Accepted')),
                        IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), tooltip: 'Rechazar', onPressed: () => _confirmAcceptReject(id, 'Rejected')),
                      ])
                    : status == 'Accepted'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.redAccent),
                onTap: () => _showBookingDetails(d),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAcceptReject(String id, String newStatus) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newStatus == 'Accepted' ? 'Confirm accept' : 'Confirm reject'),
        content: Text(newStatus == 'Accepted'
            ? 'Are you sure you want to accept this booking? This will notify the user.'
            : 'Are you sure you want to reject this booking? This will notify the user.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    );

    if (ok == true) {
      await _updateStatusAndNotify(id, newStatus);
    }
  }

  void _showBookingDetails(Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Service: ${d['serviceName'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Name: ${d['nombreReserva'] ?? d['userName'] ?? '-'}'),
            Text('Email: ${d['userEmail'] ?? '-'}'),
            Text('Date: ${_formatDate(d['date'] ?? d['fecha'] ?? d['createdAt'])}'),
            Text('Duration: ${d['duration'] ?? d['duracion'] ?? '-'}'),
            Text('Payment: ${d['paymentMethod'] ?? '-'}'),
            const SizedBox(height: 12),
            Text('Notes: ${d['notes'] ?? d['observaciones'] ?? '-'}'),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: Text('Status: ${d['status'] ?? 'Pending'}')),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _messagesStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No messages.'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final d = doc.data();
            final from = (d['senderName'] ?? d['senderEmail'] ?? d['senderId'] ?? 'Unknown').toString();
            final text = (d['text'] ?? d['title'] ?? '').toString();
            final read = (d['read'] ?? false) as bool;
            String created = '-';
            try {
              final c = d['createdAt'];
              if (c is Timestamp) created = DateFormat('yyyy-MM-dd HH:mm').format(c.toDate());
              else if (c is String) created = c;
            } catch (_) {}

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                tileColor: read ? Colors.white : Colors.green.withOpacity(0.06),
                leading: CircleAvatar(child: Text(from.isNotEmpty ? from[0].toUpperCase() : 'U')),
                title: Text(d['title']?.toString() ?? 'Message from $from'),
                subtitle: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(created, style: const TextStyle(fontSize: 11)),
                    const SizedBox(height: 6),
                    IconButton(
                      icon: const Icon(Icons.reply),
                      onPressed: () async {
                        // abrir modal para escribir respuesta
                        final reply = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) {
                            final ctrl = TextEditingController();
                            return Padding(
                              padding: EdgeInsets.only(left: 12, right: 12, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Reply')),
                                const SizedBox(height: 8),
                                ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Send')),
                              ]),
                            );
                          },
                        );

                        if (reply != null && reply.isNotEmpty) {
                          await _sendReplyToMessage(d, reply);
                          // code above sends reply based on original sender fields
                        }
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  // marcar como leído y mostrar detalle
                  await _markMessageRead(doc.id);
                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(d['title']?.toString() ?? 'Message', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(d['text']?.toString() ?? ''),
                          const SizedBox(height: 12),
                          Text('From: ${d['senderName'] ?? d['senderEmail'] ?? ''}'),
                          const SizedBox(height: 6),
                          Text('Received: $created', style: const TextStyle(color: Colors.grey)),
                        ]),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}