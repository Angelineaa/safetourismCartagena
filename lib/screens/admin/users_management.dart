import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_utils.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _search = '';
  String _roleFilter = 'All';

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    // stream completo; la búsqueda / filtrado se hace en cliente (suficiente para listados moderados)
    return _fire.collection('users').orderBy('createdAt', descending: true).snapshots();
  }

  /// Infier el rol de un documento `users` (intenta leer userType/user_role/role/type y
  /// también heurísticas isProvider/isAmbassador). Retorna uno de:
  /// 'Provider', 'Ambassador', 'Admin', 'Tourist'
  String _inferRole(Map<String, dynamic> d) {
    String _norm(String? s) => (s ?? '').toString().trim().toLowerCase();

    // revisa variantes de campo que puedan contener el rol explícito
    final candidates = [
      _norm(d['userType']?.toString()),
      _norm(d['user_type']?.toString()),
      _norm(d['userRole']?.toString()),
      _norm(d['role']?.toString()),
      _norm(d['type']?.toString()),
      _norm(d['accountType']?.toString()),
    ];

    for (var val in candidates) {
      if (val.isEmpty) continue;
      if (val.contains('provider') || val.contains('vendor') || val.contains('business')) return 'Provider';
      if (val.contains('ambassador') || val.contains('embajador') || val.contains('guide')) return 'Ambassador';
      if (val.contains('admin') || val.contains('administrator')) return 'Admin';
      if (val.contains('tourist') || val.contains('user') || val.contains('visitor') || val.contains('cliente')) return 'Tourist';
    }

    // heurísticas por flags booleanas
    if ((d['isProvider'] ?? false) == true) return 'Provider';
    if ((d['isAmbassador'] ?? false) == true) return 'Ambassador';
    if ((d['isAdmin'] ?? false) == true) return 'Admin';

    // fallback: si tiene campos típicos de provider
    if (d.containsKey('businessName') || d.containsKey('services') || d.containsKey('providerId')) return 'Provider';

    // default
    return 'Tourist';
  }

  Future<void> _blockUserFlow(String userDocId, Map<String, dynamic> userData, bool block) async {
    // cuando block==true solicitamos causa
    final admin = _auth.currentUser;
    final adminId = admin?.uid ?? 'admin';
    final adminEmail = admin?.email ?? 'adminsafetourism@gmail.com';
    final adminName = admin?.displayName ?? 'Admin';

    final role = _inferRole(userData);

    if (!block) {
      // desbloquear: confirm rápido
      final ok = await AdminUtils.confirmDialog(context, 'Unblock user', 'Do you want to unblock this user?');
      if (ok != true) return;

      try {
        final batch = _fire.batch();
        final userRef = _fire.collection('users').doc(userDocId);
        batch.update(userRef, {
          'blocked': false,
          'blockedReason': FieldValue.delete(),
          'blockedAt': FieldValue.serverTimestamp(),
        });

        // Propagar desbloqueo a colección heredada según rol
        await _propagateBlockToRoleCollections(batch, userDocId, userData, role, false);

        await batch.commit();

        AdminUtils.showSnack(context, 'User unblocked', color: Colors.green);
      } catch (e) {
        AdminUtils.showSnack(context, 'Error unblocking: $e', color: Colors.red);
      }
      return;
    }

    // pedir causa
    final reason = await _askBlockReason();
    if (reason == null || reason.trim().isEmpty) {
      AdminUtils.showSnack(context, 'Blocking cancelled: reason is required', color: Colors.orange);
      return;
    }

    // realizar updates: users doc + intentar sincronizar en providers/ambassadors/tourists + crear mensaje
    try {
      final batch = _fire.batch();
      final userRef = _fire.collection('users').doc(userDocId);
      batch.update(userRef, {
        'blocked': true,
        'blockedReason': reason.trim(),
        'blockedAt': FieldValue.serverTimestamp(),
      });

      // Propagar bloqueo a colección heredada según rol
      await _propagateBlockToRoleCollections(batch, userDocId, userData, role, true);

      // commit batch (updates)
      await batch.commit();

      // crear mensaje en 'messages' informando la causa
      final msgRef = _fire.collection('messages').doc();
      final userEmail = (userData['email'] ?? userData['userEmail'] ?? '').toString();
      final msgPayload = {
        'id': msgRef.id,
        'senderId': adminId,
        'senderEmail': adminEmail,
        'senderName': adminName,
        'recipientId': userDocId,
        'recipientEmail': userEmail.isNotEmpty ? userEmail : null,
        'title': 'Account blocked',
        // texto en inglés por petición en login antes
        'text': 'Your account has been blocked by the administrator. Reason: ${reason.trim()}',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'admin_action',
      }..removeWhere((k, v) => v == null);
      await msgRef.set(msgPayload);

      AdminUtils.showSnack(context, 'User blocked and notified', color: Colors.green);
    } catch (e) {
      AdminUtils.showSnack(context, 'Error blocking user: $e', color: Colors.red);
    }
  }

  /// Propaga el bloqueo/desbloqueo a la colección heredada que corresponda según role.
  Future<void> _propagateBlockToRoleCollections(WriteBatch batch, String userDocId, Map<String,dynamic> userData, String role, bool block) async {
    final userEmail = (userData['email'] ?? userData['userEmail'] ?? '').toString();
    final possibleId = userDocId;

    // Helper para actualizar doc ref en batch (merge semantics)
    Future<void> _updateRef(DocumentReference ref) async {
      if (block) {
        batch.update(ref, {
          'blocked': true,
          'blockedByAdminAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.update(ref, {
          'blocked': false,
          'blockedByAdminAt': FieldValue.delete(),
        });
      }
    }

    // decide qué colecciones tocar según role
    final List<String> targetCollections = [];
    if (role == 'Provider') {
      targetCollections.addAll(['providers', 'services', 'vendor_profiles']);
    } else if (role == 'Ambassador') {
      targetCollections.addAll(['ambassadors', 'embajadores']);
    } else if (role == 'Tourist') {
      targetCollections.addAll(['tourists', 'tourist_profiles']);
    } else {
      // role desconocido: tocar tanto providers como ambassadors y tourists para máxima cobertura
      targetCollections.addAll(['providers', 'ambassadors', 'tourists']);
    }

    for (var col in targetCollections) {
      try {
        if (userEmail.isNotEmpty) {
          final q = await _fire.collection(col).where('email', isEqualTo: userEmail).limit(10).get();
          for (var doc in q.docs) {
            await _updateRef(doc.reference);
          }
        }

        final idFields = ['userId', 'uid', 'ownerId', 'providerId', 'requesterId'];
        for (var idField in idFields) {
          final q2 = await _fire.collection(col).where(idField, isEqualTo: possibleId).limit(10).get();
          for (var doc in q2.docs) {
            await _updateRef(doc.reference);
          }
        }
      } catch (_) {
        // ignora errores de una colección (por ejemplo si no existe)
      }
    }
  }

  Future<String?> _askBlockReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reason for blocking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter the reason for blocking this user (required).'),
              const SizedBox(height: 8),
              TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Reason...')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Block')),
          ],
        );
      },
    );
  }

  // bloqueo automático de servicios por rating < threshold (ejecuta cuando quieras)
  Future<void> _autoBlockServicesByRating(String userId, {double threshold = 3.0}) async {
    final services = await _fire.collection('services').where('providerId', isEqualTo: userId).get();
    int disabled = 0;
    for (var s in services.docs) {
      final rating = s.data()['rating'];
      double r = 0;
      if (rating is num) r = rating.toDouble();
      else if (rating is String) r = double.tryParse(rating) ?? 0;
      if (r < threshold) {
        await s.reference.update({'active': false, 'disabledByAdmin': true});
        disabled++;
      }
    }
    AdminUtils.showSnack(context, 'Disabled $disabled low-rated services', color: Colors.orange);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name or email'),
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _roleFilter,
            items: const ['All', 'Tourist', 'Provider', 'Ambassador', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _roleFilter = v ?? 'All'),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['fullName'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? data['userEmail'] ?? '').toString().toLowerCase();
    final ratingVal = data['rating'];
    final rating = ratingVal != null ? ratingVal.toString() : 'N/A';
    final role = _inferRole(data);

    if (_roleFilter.toLowerCase() != 'all' && role.toLowerCase() != _roleFilter.toLowerCase()) return false;
    if (_search.isEmpty) return true;
    return name.contains(_search) || email.contains(_search) || rating.toLowerCase().contains(_search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users Management'),
        backgroundColor: const Color(0xFF007274),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) => _matchesFilter(d.data())).toList();
                if (filtered.isEmpty) return const Center(child: Text('No users match your search.'));

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  separatorBuilder: (_, __) => const Divider(),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final d = filtered[i];
                    final data = d.data();
                    final name = (data['name'] ?? data['fullName'] ?? 'Unnamed').toString();
                    final email = (data['email'] ?? data['userEmail'] ?? '').toString();
                    final role = _inferRole(data);
                    final rating = data['rating'] != null ? data['rating'].toString() : 'N/A';
                    final blocked = (data['blocked'] ?? false) as bool;

                    return ListTile(
                      leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U')),
                      title: Text(name),
                      subtitle: Text('Email: ${email.isNotEmpty ? email : '-'}  • Role: $role  • Rating: $rating'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(blocked ? Icons.lock_open : Icons.block, color: blocked ? Colors.green : Colors.red),
                            tooltip: blocked ? 'Unblock user' : 'Block user',
                            onPressed: () => _blockUserFlow(d.id, data, !blocked),
                          ),
                        ],
                      ),
                      onTap: () {
                        // detalle simple: mostrar diálogo con información y botón para enviar mensaje manual
                        showModalBottomSheet(
                          context: context,
                          builder: (_) {
                            final reasonCtrl = TextEditingController();
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('Email: ${email.isNotEmpty ? email : '-'}'),
                                Text('Role: $role'),
                                Text('Rating: $rating'),
                                const SizedBox(height: 12),
                                const Text('Send an admin message to this user (optional):', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                TextField(controller: reasonCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Message to send...')),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        final text = reasonCtrl.text.trim();
                                        if (text.isEmpty) return AdminUtils.showSnack(context, 'Enter a message first', color: Colors.orange);
                                        // send admin message
                                        final admin = _auth.currentUser;
                                        final adminId = admin?.uid ?? 'admin';
                                        final adminEmail = admin?.email ?? 'adminsafetourism@gmail.com';
                                        final adminName = admin?.displayName ?? 'Admin';
                                        final msgRef = _fire.collection('messages').doc();
                                        await msgRef.set({
                                          'id': msgRef.id,
                                          'senderId': adminId,
                                          'senderEmail': adminEmail,
                                          'senderName': adminName,
                                          'recipientId': d.id,
                                          'recipientEmail': email.isNotEmpty ? email : null,
                                          'title': 'Message from admin',
                                          'text': text,
                                          'createdAt': FieldValue.serverTimestamp(),
                                          'read': false,
                                          'type': 'admin_message',
                                        }..removeWhere((k, v) => v == null));
                                        Navigator.pop(context);
                                        AdminUtils.showSnack(context, 'Message sent', color: Colors.green);
                                      },
                                      child: const Text('Send'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                  ],
                                )
                              ]),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
