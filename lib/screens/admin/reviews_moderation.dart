import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_utils.dart';

class ReviewsModerationScreen extends StatefulWidget {
  const ReviewsModerationScreen({super.key});

  @override
  State<ReviewsModerationScreen> createState() => _ReviewsModerationScreenState();
}

class _ReviewsModerationScreenState extends State<ReviewsModerationScreen> {
  final _fire = FirebaseFirestore.instance;
  final double _threshold = 3.0;

  // Streams básicos para UI (no filtran por rating; UI hace consulta para encontrar los bajos)
  Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream() =>
      _fire.collection('services').orderBy('createdAt', descending: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> _ambassadorsStream() =>
      _fire.collection('ambassadors').orderBy('submittedAt', descending: true).snapshots();

  Future<void> _suspendService(String serviceId, Map<String, dynamic> serviceData) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      'Suspend service',
      'Suspend service "${serviceData['name'] ?? serviceId}" and notify provider?',
    );
    if (ok != true) return;

    try {
      // 1) deactivate service
      await _fire.collection('services').doc(serviceId).update({
        'active': false,
        'disabledByAdmin': true,
        'adminDisabledAt': FieldValue.serverTimestamp(),
      });

      // 2) mark related ambassador services (optional)
      try {
        final ambId = (serviceData['ambassadorId'] ?? serviceData['providerId'] ?? '').toString();
        if (ambId.isNotEmpty) {
          final snaps = await _fire.collection('servicio_ambajador').where('ambassadorId', isEqualTo: ambId).get();
          for (var s in snaps.docs) {
            await s.reference.update({'status': 'Disabled by admin', 'disabledByAdmin': true});
          }
        }
      } catch (_) {}

      // 3) set provider.status = 'suspending' if provider exists
      String providerId = (serviceData['providerId'] ?? '').toString();
      String providerEmail = (serviceData['providerEmail'] ?? serviceData['provideremail'] ?? '').toString();
      if (providerId.isEmpty && providerEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('providers').where('email', isEqualTo: providerEmail).limit(1).get();
          if (q.docs.isNotEmpty) providerId = q.docs.first.id;
        } catch (_) {}
      }
      if (providerId.isNotEmpty) {
        await _fire.collection('providers').doc(providerId).set({'status': 'suspending', 'statusUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      // 4) send message to provider (try recipientId, fallback recipientEmail)
      String recipientId = providerId;
      String recipientEmail = providerEmail;
      if (recipientId.isEmpty && recipientEmail.isEmpty) {
        // try to resolve from users collection by providerId or email
        final maybeId = (serviceData['providerId'] ?? '').toString();
        if (maybeId.isNotEmpty) {
          try {
            final q = await _fire.collection('users').doc(maybeId).get();
            if (q.exists) {
              final u = q.data() ?? {};
              recipientEmail = (u['email'] ?? u['userEmail'] ?? '').toString();
              recipientId = q.id;
            }
          } catch (_) {}
        }
      }

      final providerName = (serviceData['providerName'] ?? serviceData['provider'] ?? 'Provider').toString();
      final title = 'Servicio suspendido por baja calificación';
      final body =
          'Su servicio "${serviceData['name'] ?? 'Unnamed service'}" ha sido suspendido porque su calificación promedio es inferior a $_threshold. '
          'Para solicitar una nueva revisión envíe un correo a admin@tuapp.com con la razón y evidencia.';

      final msg = {
        'senderId': null,
        'senderEmail': 'adminsafetourism@gmail.com',
        'senderName': 'Admin',
        'recipientId': recipientId.isNotEmpty ? recipientId : null,
        'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
        'title': title,
        'text': body,
        'serviceId': serviceId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'admin_notice',
      }..removeWhere((k, v) => v == null);

      await _fire.collection('messages').add(msg);

      AdminUtils.showSnack(context, 'Service suspended and provider notified', color: Colors.orange);
    } catch (e) {
      AdminUtils.showSnack(context, 'Error suspending service: $e', color: Colors.red);
    }
  }

  Future<void> _suspendAmbassador(String ambDocId, Map<String, dynamic> ambData) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      'Suspend ambassador',
      'Suspend ambassador "${ambData['name'] ?? ambDocId}" and notify them?',
    );
    if (ok != true) return;

    try {
      // 1) set ambassador.status = 'suspending' and optionally verified=false
      await _fire.collection('ambassadors').doc(ambDocId).set({
        'status': 'suspending',
        'verified': false,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2) deactivate services provided by this ambassador (services collection)
      final servSnap = await _fire.collection('services').where('providerId', isEqualTo: ambData['idAmbassador'] ?? ambData['id'] ?? ambDocId).get();
      for (var s in servSnap.docs) {
        await s.reference.update({'active': false, 'disabledByAdmin': true});
      }

      // 3) send message to ambassador (try to resolve recipientId/email)
      String recipientId = '';
      String recipientEmail = (ambData['userEmail'] ?? ambData['email'] ?? '').toString();

      if (recipientEmail.isNotEmpty) {
        // try to find user doc id in 'users'
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: recipientEmail).limit(1).get();
          if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
        } catch (_) {}
      }

      final title = 'Cuenta suspendida por baja calificación';
      final body =
          'Su cuenta como embajador ha sido marcada como en proceso de suspensión porque su calificación promedio es inferior a $_threshold. '
          'Si desea solicitar una revisión, envíe un correo a admin@tuapp.com indicando motivos y evidencia.';

      final msg = {
        'senderId': null,
        'senderEmail': 'adminsafetourism@gmail.com',
        'senderName': 'Admin',
        'recipientId': recipientId.isNotEmpty ? recipientId : null,
        'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
        'title': title,
        'text': body,
        'ambassadorId': ambDocId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'admin_notice',
      }..removeWhere((k, v) => v == null);

      await _fire.collection('messages').add(msg);

      AdminUtils.showSnack(context, 'Ambassador suspended and notified', color: Colors.orange);
    } catch (e) {
      AdminUtils.showSnack(context, 'Error suspending ambassador: $e', color: Colors.red);
    }
  }

  // Escanea y devuelve servicios con rating < threshold
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findLowRatedServices() async {
    final snaps = await _fire.collection('services').where('rating', isLessThan: _threshold).get();
    return snaps.docs;
  }

  // Escanea y devuelve ambassadors con rating < threshold
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _findLowRatedAmbassadors() async {
    final snaps = await _fire.collection('ambassadors').where('rating', isLessThan: _threshold).get();
    return snaps.docs;
  }

  Future<void> _scanAndSuspendAll() async {
    final ok = await AdminUtils.confirmDialog(context, 'Scan and suspend', 'Scan all services and ambassadors with rating < $_threshold and suspend them?');
    if (ok != true) return;
    try {
      final lowServices = await _findLowRatedServices();
      final lowAmbs = await _findLowRatedAmbassadors();

      for (var s in lowServices) {
        final sd = s.data();
        await _fire.collection('services').doc(s.id).update({'active': false, 'disabledByAdmin': true, 'adminDisabledAt': FieldValue.serverTimestamp()});
        // notify provider
        String providerEmail = (sd['providerEmail'] ?? sd['provideremail'] ?? '').toString();
        String providerId = (sd['providerId'] ?? '').toString();
        String recipientId = providerId;
        if (recipientId.isEmpty && providerEmail.isNotEmpty) {
          final q = await _fire.collection('users').where('email', isEqualTo: providerEmail).limit(1).get();
          if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
        }
        await _fire.collection('messages').add({
          'senderEmail': 'adminsafetourism@gmail.com',
          'senderName': 'Admin',
          'recipientId': recipientId.isNotEmpty ? recipientId : null,
          'recipientEmail': providerEmail.isNotEmpty ? providerEmail : null,
          'title': 'Servicio suspendido',
          'text': 'Su servicio "${sd['name'] ?? ''}" fue suspendido por calificación promedio menor a $_threshold. Enviar correo a admin@tuapp.com para solicitar revisión.',
          'serviceId': s.id,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'admin_notice',
          'read': false,
        }..removeWhere((k, v) => v == null));
        // mark provider status
        if (providerId.isNotEmpty) {
          await _fire.collection('providers').doc(providerId).set({'status': 'suspending', 'statusUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }

      for (var a in lowAmbs) {
        final ad = a.data();
        await _fire.collection('ambassadors').doc(a.id).set({'status': 'suspending', 'verified': false, 'statusUpdatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        // disable their services
        final ambKey = (ad['idAmbassador'] ?? ad['id'] ?? a.id).toString();
        final servSnap = await _fire.collection('services').where('providerId', isEqualTo: ambKey).get();
        for (var s in servSnap.docs) {
          await s.reference.update({'active': false, 'disabledByAdmin': true});
        }
        final recipientEmail = (ad['userEmail'] ?? ad['email'] ?? '').toString();
        String recipientId = '';
        if (recipientEmail.isNotEmpty) {
          final q = await _fire.collection('users').where('email', isEqualTo: recipientEmail).limit(1).get();
          if (q.docs.isNotEmpty) recipientId = q.docs.first.id;
        }
        await _fire.collection('messages').add({
          'senderEmail': 'adminsafetourism@gmail.com',
          'senderName': 'Admin',
          'recipientId': recipientId.isNotEmpty ? recipientId : null,
          'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
          'title': 'Cuenta suspendida',
          'text': 'Su cuenta como embajador fue marcada para suspensión por calificación promedio menor a $_threshold. Enviar correo a admin@tuapp.com para solicitar revisión.',
          'ambassadorId': a.id,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'admin_notice',
          'read': false,
        }..removeWhere((k, v) => v == null));
      }

      AdminUtils.showSnack(context, 'Scan complete. Low-rated items suspended and notified.', color: Colors.green);
    } catch (e) {
      AdminUtils.showSnack(context, 'Error during scan: $e', color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reviews Moderation'),
          backgroundColor: primary,
          actions: [
            IconButton(
              tooltip: 'Scan & suspend all',
              icon: const Icon(Icons.search_off),
              onPressed: _scanAndSuspendAll,
            )
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Services <3.0'),
              Tab(text: 'Ambassadors <3.0'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Services tab: filter locally from stream for rating < threshold
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _servicesStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final docs = (snap.data?.docs ?? []).where((d) {
                  final r = d.data()['rating'];
                  if (r == null) return false;
                  if (r is num) return r.toDouble() < _threshold;
                  if (r is String) return double.tryParse(r) != null && double.parse(r) < _threshold;
                  return false;
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('No low-rated services found.'));

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final rating = data['rating']?.toString() ?? '-';
                    return ListTile(
                      leading: data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(data['imageUrl']))
                          : const CircleAvatar(child: Icon(Icons.room_service)),
                      title: Text(data['name'] ?? 'Service'),
                      subtitle: Text('Rating: $rating • Provider: ${data['providerName'] ?? data['providerId'] ?? '-'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.block, color: Colors.orange), onPressed: () => _suspendService(d.id, data)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                            final ok = await AdminUtils.confirmDialog(context, 'Delete service', 'Delete this service?');
                            if (ok == true) {
                              await _fire.collection('services').doc(d.id).delete();
                              AdminUtils.showSnack(context, 'Service deleted', color: Colors.red);
                            }
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            // Ambassadors tab: filter locally for rating < threshold
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ambassadorsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final docs = (snap.data?.docs ?? []).where((d) {
                  final r = d.data()['rating'];
                  if (r == null) return false;
                  if (r is num) return r.toDouble() < _threshold;
                  if (r is String) return double.tryParse(r) != null && double.parse(r) < _threshold;
                  return false;
                }).toList();

                if (docs.isEmpty) return const Center(child: Text('No low-rated ambassadors found.'));

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final data = d.data();
                    final rating = data['rating']?.toString() ?? '-';
                    return ListTile(
                      leading: data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(data['photoUrl']))
                          : const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(data['name'] ?? 'Ambassador'),
                      subtitle: Text('Rating: $rating • Languages: ${(data['languages'] is List) ? (data['languages'] as List).join(', ') : ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.block, color: Colors.orange), onPressed: () => _suspendAmbassador(d.id, data)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                            final ok = await AdminUtils.confirmDialog(context, 'Delete ambassador', 'Delete this ambassador document?');
                            if (ok == true) {
                              await _fire.collection('ambassadors').doc(d.id).delete();
                              AdminUtils.showSnack(context, 'Ambassador removed', color: Colors.red);
                            }
                          }),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}