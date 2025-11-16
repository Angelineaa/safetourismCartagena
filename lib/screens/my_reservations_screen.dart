import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final _fire = FirebaseFirestore.instance;

  Future<String?> _getUserDocId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final email = user.email ?? '';
      if (email.isEmpty) return user.uid;

      final q = await _fire
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 10));
      if (q.docs.isNotEmpty) return q.docs.first.id;
      return user.uid;
    } on TimeoutException {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      debugPrint('Error in _getUserDocId: $e');
      return FirebaseAuth.instance.currentUser?.uid;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findServiceDocByServiceId(String serviceId) async {
    if (serviceId.isEmpty) return null;

    try {
      final queries = [
        _fire.collection('services').where('servicioid', isEqualTo: serviceId).limit(1),
        _fire.collection('services').where('serviceId', isEqualTo: serviceId).limit(1),
        _fire.collection('services').where('name', isEqualTo: serviceId).limit(1),
      ];
      for (var q in queries) {
        final snap = await q.get();
        if (snap.docs.isNotEmpty) return snap.docs.first;
      }
      final byId = await _fire.collection('services').doc(serviceId).get();
      if (byId.exists) return byId;
      return null;
    } catch (e) {
      debugPrint('Error finding service doc: $e');
      return null;
    }
  }

  Future<String?> _resolveProviderUserDocId(DocumentSnapshot<Map<String, dynamic>> serviceDoc) async {
    final data = serviceDoc.data() ?? {};

    final possibleProviderId = (data['providerId'] ?? data['providerid'] ?? data['provider'] ?? data['providerUID'])?.toString();
    if (possibleProviderId != null && possibleProviderId.isNotEmpty) {
      return possibleProviderId;
    }

    final possibleEmail = (data['providerEmail'] ?? data['provideremail'] ?? data['provider_email'])?.toString() ?? '';
    if (possibleEmail.isNotEmpty) {
      try {
        final q = await _fire.collection('users').where('email', isEqualTo: possibleEmail).limit(1).get();
        if (q.docs.isNotEmpty) return q.docs.first.id;
      } catch (e) {
        debugPrint('Error resolving provider by email: $e');
      }
    }
    return null;
  }

  String _stateToEnglish(String raw) {
    final s = raw.toString().toLowerCase();
    if (s.contains('pend') || s.contains('pendiente') || s.contains('pending')) return 'Pending';
    if (s.contains('confirm') || s.contains('confirmada') || s.contains('confirmed')) return 'Confirmed';
    if (s.contains('cancel') || s.contains('cancelada') || s.contains('cancelled') || s.contains('canceled')) return 'Cancelled';
    if (s.contains('rechaz') || s.contains('rejected')) return 'Rejected';
    if (s.contains('completed') || s.contains('complet') || s.contains('finalizada') || s.contains('finalizado')) return 'Completed';
    if (s.isEmpty) return 'Unknown';
    return s[0].toUpperCase() + s.substring(1);
  }

  bool _isCancellable(String raw) {
    final s = raw.toString().toLowerCase();
    if (s.contains('cancel') || s.contains('cancelada') || s.contains('rechaz') || s.contains('rejected') || s.contains('completed') || s.contains('finaliz')) {
      return false;
    }
    return true;
  }

  /// Extrae fecha y hora de una reserva de forma tolerante.
  /// Prioriza:
  /// 1) campo 'horaReserva' (o variantes) para la hora,
  /// 2) luego extrae hora de 'fechaReserva' si es Timestamp/DateTime o string parseable,
  /// 3) si nada, intenta otros campos.
  Map<String, String> _extractDateAndTime(Map<String, dynamic> reservaData) {
    String fechaTexto = '';
    String horaTexto = '';

    // 1) intentar horaReserva directamente (si está)
    final possibleHourCandidates = [
      'horaReserva', 'hora', 'time', 'reservationTime', 'reservation_time', 'service_time', 'reservationHour'
    ];
    for (var k in possibleHourCandidates) {
      final v = reservaData[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isEmpty) continue;

      // Normalizar formatos comunes a HH:mm
      final tryParseTime = RegExp(r'^\d{1,2}(:\d{1,2}(:\d{1,2})?)?$');
      if (tryParseTime.hasMatch(s)) {
        // tomar la primera parte si viene "09:00 - 17:00"
        if (s.contains('-')) {
          horaTexto = s.split('-').first.trim();
        } else {
          horaTexto = s;
        }
        // Asegurar formato HH:mm
        horaTexto = _normalizeToHHMM(horaTexto);
        break;
      }

      // Si no es simple time but contains ":" try to extract token with ':'
      if (s.contains(':')) {
        final token = s.split(RegExp(r'\s+')).firstWhere((t) => t.contains(':'), orElse: () => s);
        horaTexto = _normalizeToHHMM(token);
        break;
      }

      // si es texto como "9 AM" o "9PM", intentar parsear
      final dtTry = DateTime.tryParse(s);
      if (dtTry != null) {
        horaTexto = DateFormat('HH:mm').format(dtTry);
        break;
      }

      // fallback: take as-is (will be shown raw)
      horaTexto = s;
      break;
    }

    // 2) fechaReserva (Timestamp/DateTime/String) para fecha y posible hora
    final dynamic fechaCampo = reservaData['fechaReserva'] ?? reservaData['fecha'] ?? reservaData['date'];
    if (fechaCampo != null) {
      try {
        if (fechaCampo is Timestamp) {
          final dt = fechaCampo.toDate();
          fechaTexto = DateFormat('yyyy-MM-dd').format(dt);
          // if hora not already found, extract from timestamp
          if (horaTexto.isEmpty) horaTexto = DateFormat('HH:mm').format(dt);
        } else if (fechaCampo is DateTime) {
          fechaTexto = DateFormat('yyyy-MM-dd').format(fechaCampo);
          if (horaTexto.isEmpty) horaTexto = DateFormat('HH:mm').format(fechaCampo);
        } else if (fechaCampo is String) {
          final parsed = DateTime.tryParse(fechaCampo);
          if (parsed != null) {
            fechaTexto = DateFormat('yyyy-MM-dd').format(parsed);
            if (horaTexto.isEmpty) horaTexto = DateFormat('HH:mm').format(parsed);
          } else {
            // if string like "2025-11-09 15:30" try to split
            final s = fechaCampo.toString();
            if (s.contains(' ')) {
              final parts = s.split(' ');
              fechaTexto = parts[0];
              if (horaTexto.isEmpty && parts.length > 1) {
                horaTexto = _normalizeToHHMM(parts[1]);
              }
            } else {
              fechaTexto = s;
            }
          }
        }
      } catch (_) {
        // ignore and continue
      }
    }

    // 3) si aún no hay fecha, intentar createdAt
    if (fechaTexto.isEmpty) {
      final altDate = reservaData['createdAt'] ?? reservaData['created_at'];
      if (altDate != null) {
        try {
          if (altDate is Timestamp) fechaTexto = DateFormat('yyyy-MM-dd').format(altDate.toDate());
          else if (altDate is DateTime) fechaTexto = DateFormat('yyyy-MM-dd').format(altDate);
          else fechaTexto = altDate.toString();
        } catch (_) {
          fechaTexto = altDate.toString();
        }
      }
    }

    if (fechaTexto.isEmpty) fechaTexto = 'Unknown date';
    if (horaTexto.isEmpty) horaTexto = 'Unknown time';

    return {'fecha': fechaTexto, 'hora': horaTexto};
  }

  /// Normaliza un token horario a formato HH:mm (intenta manejar "9", "9:0", "09:00:00", "9 AM", etc.)
 String _normalizeToHHMM(String raw) {
    var s = raw.trim();

    // detectar AM/PM usando flag de case-insensitive en lugar de (?i)
    final ampm = RegExp(r'\b(am|pm)\b', caseSensitive: false);
    if (ampm.hasMatch(s)) {
      // intentar parsear con DateTime tras limpiar caracteres no relevantes
      // (no necesitamos case-insensitive aquí porque ya quitamos todo lo que no sea dígito, dos puntos o espacio)
      final cleaned = s.replaceAll(RegExp(r'[^\d: ]'), '').trim();
      DateTime? parsed;
      try {
        parsed = DateTime.tryParse(cleaned);
      } catch (_) {}
      if (parsed != null) return DateFormat('HH:mm').format(parsed);

      // fallback: manejar "9 AM" o "9:30 pm" manualmente (case-insensitive por constructor)
      final match = RegExp(r'(\d{1,2})(?::(\d{1,2}))?\s*(am|pm)', caseSensitive: false).firstMatch(s);
      if (match != null) {
        int h = int.parse(match.group(1)!);
        final minStr = match.group(2);
        int m = minStr != null ? int.tryParse(minStr) ?? 0 : 0;
        final isPm = match.group(3)!.toLowerCase() == 'pm';
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }

    // quitar segundos si existen y normalizar "HH:mm:ss" o "H:m"
    if (s.contains(':')) {
      final parts = s.split(':').map((p) => p.trim()).toList();
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      } else if (parts.length == 1) {
        final h = int.tryParse(parts[0]) ?? 0;
        return '${h.toString().padLeft(2, '0')}:00';
      }
    }

    // si es sólo número "9" o "09"
    final onlyNum = RegExp(r'^\d{1,2}$');
    if (onlyNum.hasMatch(s)) {
      final h = int.tryParse(s) ?? 0;
      return '${h.toString().padLeft(2, '0')}:00';
    }

    // fallback: devolver raw para evitar crash
    return s;
  }
    
  Future<void> _cancelReservation(String reservaId, Map<String, dynamic> reservaData) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel reservation'),
        content: const Text('Are you sure you want to cancel this reservation?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final reservaRef = _fire.collection('reservas').doc(reservaId);
      await reservaRef.update({
        'estado': 'cancelada', // stored in Spanish per your request
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final serviceId = (reservaData['idservicio'] ?? reservaData['serviceId'] ?? reservaData['idServicio'] ?? reservaData['servicioid'] ?? '').toString();

      String? providerUserDocId;
      String? providerEmail;

      if (serviceId.isNotEmpty) {
        final serviceDoc = await _findServiceDocByServiceId(serviceId);
        if (serviceDoc != null) {
          final sdata = serviceDoc.data() ?? {};
          providerEmail = (sdata['providerEmail'] ?? sdata['provideremail'])?.toString() ?? '';
          providerUserDocId = await _resolveProviderUserDocId(serviceDoc);
        }
      }

      // Use the robust extractor for fecha + hora
      final extracted = _extractDateAndTime(reservaData);
      final fechaTexto = extracted['fecha'] ?? 'Unknown date';
      final horaTexto = extracted['hora'] ?? 'Unknown time';

      // Create message for provider in Spanish
      final notifRef = _fire.collection('messages').doc();
      final user = FirebaseAuth.instance.currentUser;
      final senderEmail = user?.email ?? reservaData['userEmail'] ?? '';

      final notifData = {
        'id': notifRef.id,
        'senderId': user?.uid ?? '',
        'senderEmail': senderEmail,
        'recipientId': providerUserDocId ?? '',
        'recipientEmail': providerEmail ?? '',
        'title': 'Reservation cancelled',
        'text': 'The reservation "${reservaData['nombreReserva'] ?? reservaData['serviceName'] ?? serviceId}" scheduled for $fechaTexto at $horaTexto has been cancelled by the user.',
        'reservationId': reservaId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'reservation_cancelled',
      };

      await notifRef.set(notifData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reservation cancelled and provider notified.')));
      }
    } catch (e) {
      debugPrint('Error cancelling reservation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling reservation: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(title: const Text('My Reservations'), backgroundColor: primary),
      body: FutureBuilder<String?>(
        future: _getUserDocId(),
        builder: (context, futureSnap) {
          if (futureSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (futureSnap.hasError) {
            return Center(child: Text('Error getting user id: ${futureSnap.error}'));
          }
          final userId = futureSnap.data;
          if (userId == null) return const Center(child: Text('User not found'));

          final stream = _fire
              .collection('reservas')
              .where('userId', isEqualTo: userId)
              .orderBy('createdAt', descending: true)
              .snapshots();

          return StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error loading reservations: ${snap.error}'));
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No reservations found'));

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final service = data['serviceName'] ?? 'Unknown Service';

                  // Robust extraction
                  final extracted = _extractDateAndTime(data);
                  final date = extracted['fecha'] ?? 'Unknown date';
                  final hour = extracted['hora'] ?? 'Unknown time';

                  final rawState = (data['estado'] ?? data['status'] ?? 'pending').toString();
                  final state = _stateToEnglish(rawState);
                  final method = (data['paymentMethod'] ?? data['payment_method'] ?? 'not set').toString();
                  final payment = (data['paymentStatus'] ?? data['payment_status'] ?? 'pending').toString();

                  final cancellable = _isCancellable(rawState);

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF007274)),
                      title: Text(service, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Date: $date\nTime: $hour\nPayment: $method ($payment)\nStatus: $state'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: 'Cancel reservation',
                              onPressed: cancellable ? () => _cancelReservation(doc.id, data) : null,
                            ),
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