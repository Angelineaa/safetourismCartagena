import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'admin_utils.dart';

class AmbassadorsManagementScreen extends StatefulWidget {
  const AmbassadorsManagementScreen({super.key});

  @override
  State<AmbassadorsManagementScreen> createState() =>
      _AmbassadorsManagementScreenState();
}

class _AmbassadorsManagementScreenState
    extends State<AmbassadorsManagementScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Query: sólo pendientes y availability = 'Available'
  Stream<QuerySnapshot<Map<String, dynamic>>> _ambStream() {
    return _fire
        .collection('ambassadors')
        .where('applicationStatus', isEqualTo: 'pending')
        .where('availability', isEqualTo: 'Available')
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  String _fmtTs(dynamic ts) {
    try {
      if (ts == null) return '-';
      if (ts is Timestamp) {
        return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
      } else if (ts is DateTime) {
        return DateFormat('yyyy-MM-dd HH:mm').format(ts);
      } else {
        return ts.toString();
      }
    } catch (_) {
      return ts.toString();
    }
  }

  Future<void> _approve(String docId, Map<String, dynamic> data) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      'Approve ambassador',
      'Are you sure you want to approve this ambassador?',
    );
    if (ok != true) return;

    try {
      // update ambassador doc
      await _fire.collection('ambassadors').doc(docId).update({
        'verified': true,
        'applicationStatus': 'approved',
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // notify ambassador via messages (in Spanish per request)
      await _sendApplicationMessage(
        data: data,
        approved: true,
        reason: null,
        ambassadorDocId: docId,
      );

      AdminUtils.showSnack(context, 'Ambassador approved and notified');
    } catch (e) {
      AdminUtils.showSnack(context, 'Error approving ambassador: $e',
          color: Colors.red);
    }
  }

  Future<void> _reject(String docId, Map<String, dynamic> data) async {
    // pedir motivo
    final reason = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Reason for rejection', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Motivo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Send rejection'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (reason == null) return; // usuario canceló

    final ok = await AdminUtils.confirmDialog(
      context,
      'Reject ambassador',
      'Are you sure you want to reject this ambassador?',
    );
    if (ok != true) return;

    try {
      // actualizar doc del embajador con motivo y estado
      await _fire.collection('ambassadors').doc(docId).update({
        'verified': false,
        'applicationStatus': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // notificar via messages con motivo (en español)
      await _sendApplicationMessage(
        data: data,
        approved: false,
        reason: reason,
        ambassadorDocId: docId,
      );

      AdminUtils.showSnack(context, 'Ambassador rejected and notified');
    } catch (e) {
      AdminUtils.showSnack(context, 'Error rejecting ambassador: $e',
          color: Colors.red);
    }
  }

  /// Envía mensaje al embajador (collection 'messages').
  /// Si approved==true envía texto de aprobación; si false envía texto de rechazo incluyendo reason.
  /// Intenta poblar recipientId (user doc id) y recipientEmail desde `data`.
  Future<void> _sendApplicationMessage({
    required Map<String, dynamic> data,
    required bool approved,
    String? reason,
    required String ambassadorDocId,
  }) async {
    try {
      final adminUser = _auth.currentUser;
      final senderId = adminUser?.uid ?? null;
      final senderEmail = adminUser?.email ?? 'adminsafetourism@gmail.com';
      final senderName = adminUser?.displayName ?? 'Admin';

      // intentar obtener recipientId/email del documento del embajador
      String recipientId = '';
      String recipientEmail = '';

      // campos comunes en tu esquema
      if ((data['userId'] ?? data['requesterId'] ?? data['user_id']) != null) {
        recipientId = (data['userId'] ?? data['requesterId'] ?? data['user_id']).toString();
      }
      if ((data['userEmail'] ?? data['user_email'] ?? data['email'] ?? data['userEmail']) != null) {
        recipientEmail = (data['userEmail'] ?? data['user_email'] ?? data['email'] ?? data['userEmail']).toString();
      }

      // sanitize email (trim + lowercase) to avoid issues with trailing spaces/typos
      if (recipientEmail.isNotEmpty) {
        recipientEmail = recipientEmail.trim().toLowerCase();
      }

      // si no tenemos recipientId pero sí email, intentar resolver en users (email sanitized)
      if (recipientId.isEmpty && recipientEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: recipientEmail).limit(1).get();
          if (q.docs.isNotEmpty) {
            recipientId = q.docs.first.id;
          } else {
            // fallback: buscar en collection 'ambassadors' por email
            try {
              final q2 = await _fire.collection('ambassadors').where('userEmail', isEqualTo: recipientEmail).limit(1).get();
              if (q2.docs.isNotEmpty) {
                // encontramos en ambassadors; no forzamos recipientId a users id, pero guardamos recipientEmail correctamente
                recipientId = recipientId; // keep empty or existing
              } else {
                // try other field name
                final q3 = await _fire.collection('ambassadors').where('email', isEqualTo: recipientEmail).limit(1).get();
                if (q3.docs.isNotEmpty) {
                  recipientId = recipientId;
                }
              }
            } catch (e) {
              debugPrint('Error resolving recipientId in ambassadors by email: $e');
            }
          }
        } catch (e) {
          debugPrint('Error resolving recipientId by email: $e');
        }
      }

      // si no tenemos recipientEmail pero sí recipientId, intentar obtener de users doc
      if (recipientEmail.isEmpty && recipientId.isNotEmpty) {
        bool found = false;
        try {
          final ud = await _fire.collection('users').doc(recipientId).get();
          if (ud.exists) {
            final m = ud.data() ?? {};
            recipientEmail = (m['email'] ?? m['userEmail'] ?? '').toString().trim().toLowerCase();
            found = true;
          }
        } catch (e) {
          debugPrint('Error resolving recipientEmail in users by id: $e');
        }

        if (!found) {
          // fallback: maybe recipientId is an ambassadors doc id
          try {
            final ad = await _fire.collection('ambassadors').doc(recipientId).get();
            if (ad.exists) {
              final ma = ad.data() ?? {};
              recipientEmail = (ma['userEmail'] ?? ma['email'] ?? '').toString().trim().toLowerCase();
              found = true;
            }
          } catch (e) {
            debugPrint('Error resolving recipientEmail in ambassadors by id: $e');
          }
        }
      }

      // last-resort: if recipientEmail contains obvious typos (like spaces), log it for manual check
      if (recipientEmail.isNotEmpty && recipientEmail.contains(' ')) {
        debugPrint('Warning: recipientEmail contains spaces: "$recipientEmail"');
      }

      final ambName = (data['name'] ?? data['fullName'] ?? '').toString();
      final submitted = _fmtTs(data['submittedAt'] ?? data['createdAt']);
      final title = approved ? 'Solicitud aprobada' : 'Solicitud rechazada';
      final body = approved
          ? 'Hola $ambName,\n\nTu solicitud como embajador ha sido aprobada. Felicitaciones.\n\nSubmitted: $submitted\n\nPuedes acceder al panel para completar tu perfil y comenzar a ofrecer servicios.'
          : 'Hola $ambName,\n\nLamentamos informarte que tu solicitud como embajador ha sido rechazada.\n\nMotivo: ${reason ?? 'No especificado'}\n\nSi quieres volver a aplicar, corrige lo indicado y envía una nueva solicitud.';

      final msg = <String, dynamic>{
        if (senderId != null) 'senderId': senderId,
        'senderEmail': senderEmail,
        'senderName': senderName,
        'recipientId': recipientId.isNotEmpty ? recipientId : null,
        'recipientEmail': recipientEmail.isNotEmpty ? recipientEmail : null,
        'title': title,
        'text': body,
        'applicationDocId': ambassadorDocId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'application_review',
      }..removeWhere((k, v) => v == null);

      await _fire.collection('messages').add(msg);
    } catch (e) {
      debugPrint('Error sending application message: $e');
    }
  }

  void _showDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final langs = (data['languages'] is List) ? (data['languages'] as List).join(', ') : (data['languages']?.toString() ?? '');
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Center(
                child: data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty
                    ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['photoUrl'], height: 140, width: 140, fit: BoxFit.cover))
                    : const CircleAvatar(radius: 40, child: Icon(Icons.person)),
              ),
              const SizedBox(height: 12),
              Text((data['name'] ?? '-').toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('ID: ${data['id'] ?? data['idAmbassador'] ?? '-'}'),
              Text('UserId: ${data['userId'] ?? '-'}'),
              Text('Email: ${data['userEmail'] ?? data['email'] ?? '-'}'),
              Text('Phone: ${data['phone'] ?? '-'}'),
              Text('Nationality: ${data['nationality'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Languages: $langs'),
              const SizedBox(height: 8),
              Text('Experience: ${data['experience'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Price/hour: ${data['pricePerHour'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Description:\n${data['description'] ?? '-'}'),
              const SizedBox(height: 12),
              Text('Submitted: ${_fmtTs(data['submittedAt'])}'),
              Text('CreatedAt: ${_fmtTs(data['createdAt'])}'),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: Text('Verified: ${data['verified'] == true ? 'YES' : 'NO'}')),
              const SizedBox(height: 12),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ambassadors Management'),
        backgroundColor: const Color(0xFF007274),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ambStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No pending ambassadors with availability "Available".'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final verified = (data['verified'] ?? false) as bool;
              final name = (data['name'] ?? 'Unnamed').toString();
              final email = (data['userEmail'] ?? data['email'] ?? '').toString();
              final phone = (data['phone'] ?? '').toString();

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (data['photoUrl'] ?? '').toString().isNotEmpty ? NetworkImage(data['photoUrl']) as ImageProvider : null,
                    child: (data['photoUrl'] ?? '').toString().isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(name),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Text('Email: $email'),
                    Text('Phone: $phone'),
                    Text('Submitted: ${_fmtTs(data['submittedAt'])}'),
                    Text('Verified: ${verified ? 'YES' : 'NO'}'),
                  ]),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Approve',
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _approve(d.id, data),
                      ),
                      IconButton(
                        tooltip: 'Reject',
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () => _reject(d.id, data),
                      ),
                      IconButton(
                        tooltip: 'View details',
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showDetails(data),
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