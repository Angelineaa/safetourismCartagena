import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String providerEmail = '';
  String providerDocId = '';
  Set<String> _myServiceIds = {}; // ids de servicios del proveedor
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initProviderAndServices();
  }

  Future<void> _initProviderAndServices() async {
    final u = _auth.currentUser;
    if (u == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    providerEmail = u.email ?? '';

    try {
      // 1) obtener el document id del usuario en la colección 'users'
      final q = await _fire.collection('users').where('email', isEqualTo: providerEmail).limit(1).get();
      if (q.docs.isNotEmpty) {
        providerDocId = q.docs.first.id;
      } else {
        // fallback al uid si no existe doc (no recomendado pero útil)
        providerDocId = u.uid;
      }

      // 2) cargar servicios propios: primero por providerId
      final snapById = await _fire.collection('services').where('providerId', isEqualTo: providerDocId).get();
      final services = <QueryDocumentSnapshot>[];
      services.addAll(snapById.docs);

      // 3) si no hay resultados por providerId, intentar por providerEmail
      if (services.isEmpty && providerEmail.isNotEmpty) {
        final snapByEmail = await _fire.collection('services').where('providerEmail', isEqualTo: providerEmail).get();
        services.addAll(snapByEmail.docs);
      }

      // 4) acumular ids (doc.id) y posibles campos serviceId
      final ids = <String>{};
      for (var d in services) {
        ids.add(d.id);
        final data = d.data();
        if (data is Map<String, dynamic>) {
          if (data['serviceId'] != null) ids.add(data['serviceId'].toString());
          if (data['idservicio'] != null) ids.add(data['idservicio'].toString());
        }
      }

      setState(() {
        _myServiceIds = ids;
      });
    } catch (e) {
      debugPrint('Error inicializando proveedor/servicios: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Stream de reservas:
  // - Si no hay servicios -> stream vacío (sin resultados)
  // - Si <= 10 servicios -> usar whereIn (eficiente)
  // - Si > 10 -> traer todo y filtrar cliente (evita error whereIn > 10)
  Stream<QuerySnapshot> _reservasStream() {
    if (_myServiceIds.isEmpty) {
      // coleccion que no devuelve nada (falso filtro)
      return _fire.collection('reservas').where('idservicio', isEqualTo: '__NO_MATCH__').snapshots();
    }
    final idsList = _myServiceIds.toList();
    if (idsList.length <= 10) {
      // usar whereIn
      // ordenamiento posterior se puede hacer cliente si es necesario.
      return _fire
          .collection('reservas')
          .where('idservicio', whereIn: idsList)
          .snapshots();
    } else {
      // demasiados ids -> traer todos y filtrar localmente
      return _fire.collection('reservas').snapshots();
    }
  }

  // Actualizar estado y enviar notificación (mensaje) al turista
  Future<void> _updateReservationStatus(QueryDocumentSnapshot reservaDoc, String newStatus) async {
    final id = reservaDoc.id;
    final data = reservaDoc.data() as Map<String, dynamic>;
    final userIdField = (data['userId'] ?? '').toString(); // se espera document id en 'users'
    final userEmail = (data['userEmail'] ?? '').toString();
    final reservaRef = _fire.collection('reservas').doc(id);

    try {
      // 1) actualizar estado en la reserva
      await reservaRef.update({
        'estado': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'handledBy': providerDocId,
      });

      // 2) preparar mensaje para el turista
      final title = 'Reserva ${newStatus[0].toUpperCase()}${newStatus.substring(1)}';
      final serviceName = (data['serviceName'] ?? data['idservicio'] ?? 'tu servicio').toString();
      final body = 'Your reservation for "$serviceName" has been $newStatus by the provider.';

      // 3) determinar recipientId (document id en 'users')
      String recipientId = userIdField;
      if (recipientId.isEmpty && userEmail.isNotEmpty) {
        final q = await _fire.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
        if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
      }

      // 4) crear mensaje en la colección 'messages'
      await _fire.collection('messages').add({
        'senderId': providerDocId,
        'senderEmail': providerEmail,
        'recipientId': recipientId, // puede quedar vacío si no encontramos
        'recipientEmail': userEmail,
        'title': title,
        'text': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'reservation',
        'reservationId': id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reserva actualizada: $newStatus')));
      }
    } catch (e) {
      debugPrint('Error actualizando reserva: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando reserva: $e')));
    }
  }

  // Helper para decidir si una reserva pertenece a mis servicios (cliente-side)
  bool _isMineReservation(Map<String, dynamic> data) {
    final sid = (data['idservicio'] ?? data['serviceId'] ?? data['idServicio'] ?? '').toString();
    if (sid.isEmpty) return false;
    return _myServiceIds.contains(sid);
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Reservas'), backgroundColor: primary),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reservasStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          var docs = snap.data!.docs;

          // Si usamos el fallback (demasiados ids), filtramos localmente.
          if (_myServiceIds.length > 10) {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return _isMineReservation(data);
            }).toList();
          }

          // ordenar por fechaReserva desc (si existe campo)
          docs.sort((a, b) {
            final ad = a.data() as Map<String, dynamic>;
            final bd = b.data() as Map<String, dynamic>;
            final at = ad['fechaReserva'];
            final bt = bd['fechaReserva'];
            DateTime? aDt;
            DateTime? bDt;
            if (at is Timestamp) aDt = at.toDate();
            else if (at is String) aDt = DateTime.tryParse(at);
            if (bt is Timestamp) bDt = bt.toDate();
            else if (bt is String) bDt = DateTime.tryParse(bt);
            if (aDt == null && bDt == null) return 0;
            if (aDt == null) return 1;
            if (bDt == null) return -1;
            return bDt.compareTo(aDt);
          });

          if (docs.isEmpty) return const Center(child: Text('No hay reservas para tus servicios.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;

              final nombre = data['nombreReserva'] ?? data['customerName'] ?? 'Reserva';
              final idserv = (data['idservicio'] ?? data['serviceId'] ?? '').toString();
              final numP = data['numPersonas']?.toString() ?? '';
              final estado = (data['estado'] ?? 'pendiente').toString();
              String fechaStr = '';
              try {
                final t = data['fechaReserva'];
                if (t is Timestamp) fechaStr = DateFormat('yyyy-MM-dd').format(t.toDate());
                else if (t is String) fechaStr = t;
              } catch (_) {}

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(nombre.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Servicio: $idserv\nPersonas: $numP\nFecha: $fechaStr'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // estado
                      Text(estado, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // aceptar
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          tooltip: 'Aceptar',
                          onPressed: estado == 'accepted' ? null : () => _updateReservationStatus(doc, 'accepted'),
                        ),
                      ),
                      // rechazar
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          tooltip: 'Rechazar',
                          onPressed: estado == 'rejected' ? null : () => _updateReservationStatus(doc, 'rejected'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}