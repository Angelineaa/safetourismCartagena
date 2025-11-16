import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificacionesProveedorScreen extends StatefulWidget {
  const NotificacionesProveedorScreen({super.key});

  @override
  State<NotificacionesProveedorScreen> createState() => _NotificacionesProveedorScreenState();
}

class _NotificacionesProveedorScreenState extends State<NotificacionesProveedorScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _providerEmail = '';
  String _providerUserDocId = '';
  Set<String> _myServiceIds = {};
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initProviderData();
  }

  Future<void> _initProviderData() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final u = _auth.currentUser;
      if (u == null) {
        setState(() {
          _error = 'No hay sesión iniciada';
          _loading = false;
        });
        return;
      }

      _providerEmail = u.email ?? '';
      if (_providerEmail.isNotEmpty) {
        final q = await _fire.collection('users').where('email', isEqualTo: _providerEmail).limit(1).get();
        if (q.docs.isNotEmpty) {
          _providerUserDocId = q.docs.first.id;
        } else {
          _providerUserDocId = u.uid;
        }
      } else {
        _providerUserDocId = u.uid;
      }

      final serviceSnap = await _fire.collection('services').where('providerEmail', isEqualTo: _providerEmail).get();
      final ids = <String>{};
      for (var doc in serviceSnap.docs) {
        ids.add(doc.id);
        final data = doc.data();
        if (data['serviceId'] != null) ids.add(data['serviceId'].toString());
        if (data['servicioid'] != null) ids.add(data['servicioid'].toString());
        if (data['servicioId'] != null) ids.add(data['servicioId'].toString());
      }
      _myServiceIds = ids;
    } catch (e, st) {
      debugPrint('Error init provider data: $e\n$st');
      _error = 'Error cargando datos iniciales: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Stream<QuerySnapshot> _messagesStream() {
    return _fire
        .collection('messages')
        .where('recipientId', isEqualTo: _providerUserDocId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> _reservasStream() {
    return _fire.collection('reservas').orderBy('createdAt', descending: true).snapshots();
  }

  bool _isMyReserva(Map<String, dynamic> data) {
    final sid = (data['idservicio'] ?? data['serviceId'] ?? data['idServicio'] ?? '').toString();
    if (sid.isEmpty) return false;
    return _myServiceIds.contains(sid);
  }

  Future<void> _markMessageRead(String docId) async {
    try {
      await _fire.collection('messages').doc(docId).update({'read': true, 'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error marcando como leído: $e')));
    }
  }

  void _openReservaDetail(DocumentSnapshot reservaDoc) {
    final data = reservaDoc.data() as Map<String, dynamic>? ?? {};
    final hora = data['horaReserva'] ?? 'Hora no especificada';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalles de la reserva'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${data['nombreReserva'] ?? '-'}'),
            Text('Servicio: ${data['serviceName'] ?? data['idservicio'] ?? '-'}'),
            Text('Personas: ${data['numPersonas']?.toString() ?? '-'}'),
            Text('Fecha: ${_formatDate(data['fechaReserva'])}'),
            Text('Hora: $hora'),
            Text('Estado: ${data['estado'] ?? '-'}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  String _formatDate(dynamic fecha) {
    try {
      if (fecha == null) return '-';
      if (fecha is Timestamp) return DateFormat('yyyy-MM-dd').format(fecha.toDate());
      if (fecha is DateTime) return DateFormat('yyyy-MM-dd').format(fecha);
      return fecha.toString();
    } catch (_) {
      return fecha.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones'), backgroundColor: primary),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : RefreshIndicator(
                  onRefresh: () => _initProviderData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Mensajes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        StreamBuilder<QuerySnapshot>(
                          stream: _messagesStream(),
                          builder: (context, msgSnap) {
                            if (msgSnap.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('Error al cargar mensajes: ${msgSnap.error}'),
                              );
                            }
                            if (!msgSnap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final msgs = msgSnap.data!.docs;
                            if (msgs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No tienes mensajes.'),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: msgs.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, i) {
                                final doc = msgs[i];
                                final data = doc.data() as Map<String, dynamic>;
                                final title = data['title'] ?? 'Mensaje';
                                final text = data['body'] ?? data['text'] ?? '';
                                final sender = data['senderEmail'] ?? data['senderId'] ?? 'Usuario';
                                final createdAt = data['createdAt'];
                                final read = data['read'] ?? false;

                                return ListTile(
                                  leading: CircleAvatar(child: Text(sender.toString().isNotEmpty ? sender.toString()[0].toUpperCase() : 'U')),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!read)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                                          child: const Text('NUEVO', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(createdAt is Timestamp ? DateFormat('yyyy-MM-dd').format(createdAt.toDate()) : '', style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  onTap: () {
                                    _markMessageRead(doc.id);
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(title),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('De: $sender'),
                                            const SizedBox(height: 8),
                                            Text(text),
                                            const SizedBox(height: 8),
                                            Text('Fecha: ${createdAt is Timestamp ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt.toDate()) : createdAt?.toString() ?? '-'}'),
                                          ],
                                        ),
                                        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Cancelaciones de reservas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
                          ),
                        ),
                        const SizedBox(height: 8),

                        StreamBuilder<QuerySnapshot>(
                          stream: _reservasStream(),
                          builder: (context, resSnap) {
                            if (resSnap.hasError) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('Error al cargar reservas: ${resSnap.error}'),
                              );
                            }
                            if (!resSnap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final docs = resSnap.data!.docs.where((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final estado = (data['estado'] ?? '').toString().toLowerCase();
                              return _isMyReserva(data) && (estado.contains('cancel') || estado.contains('cancelada') || estado.contains('cancelado'));
                            }).toList();

                            if (docs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text('No hay cancelaciones recientes.'),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, i) {
                                final doc = docs[i];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['nombreReserva'] ?? data['userName'] ?? 'Reserva';
                                final serviceName = data['serviceName'] ?? data['idservicio'] ?? '-';
                                final fecha = _formatDate(data['fechaReserva']);
                                final hora = data['horaReserva'] ?? 'Hora no especificada';
                                final created = data['createdAt'];

                                return ListTile(
                                  leading: const Icon(Icons.cancel, color: Colors.redAccent),
                                  title: Text('$name — $serviceName', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Fecha reserva: $fecha\nHora: $hora\nMotivo: ${data['cancelReason'] ?? 'Usuario canceló'}'),
                                  trailing: Text(created is Timestamp ? DateFormat('yyyy-MM-dd').format(created.toDate()) : ''),
                                  onTap: () => _openReservaDetail(doc),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }
}