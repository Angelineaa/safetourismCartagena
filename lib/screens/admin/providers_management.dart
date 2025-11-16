import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_utils.dart';

class ProvidersManagementScreen extends StatefulWidget {
  const ProvidersManagementScreen({super.key});

  @override
  State<ProvidersManagementScreen> createState() =>
      _ProvidersManagementScreenState();
}

class _ProvidersManagementScreenState extends State<ProvidersManagementScreen> {
  final _fire = FirebaseFirestore.instance;

  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() => _loading = true);

    try {
      final snap = await _fire.collection('providers').get();
      _providers = snap.docs;
    } catch (e) {
      debugPrint("Error loading providers: $e");
      AdminUtils.showSnack(context, "Error loading providers",
          color: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveProvider(String docId, bool approved) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      approved ? 'Approve provider' : 'Revoke approval',
      approved ? 'Approve this provider?' : 'Revoke approval?',
    );

    if (ok != true) return;

    await _fire.collection('providers').doc(docId).update({
      'approved': approved,
      'approvedAt': FieldValue.serverTimestamp(),
    });

    AdminUtils.showSnack(
        context, approved ? 'Provider approved' : 'Approval revoked');

    _loadProviders();
  }

  /// ============
  /// CARGAR SERVICIOS DEL PROVEEDOR
  /// Solo usa providerId
  /// ============
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getServicesForProvider(Map<String, dynamic> provider) async {
    final providerId = provider['id'] ?? provider['providerId'] ?? '';

    if (providerId.isEmpty) return [];

    try {
      final snap = await _fire
          .collection('services')
          .where('providerId', isEqualTo: providerId)
          .get();

      return snap.docs;
    } catch (e) {
      debugPrint("Error loading services: $e");
      return [];
    }
  }

  Future<void> _toggleServiceActive(
      String id, bool newState, Map<String, dynamic> data) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      newState ? 'Activate' : 'Deactivate',
      newState ? 'Activate this service?' : 'Deactivate this service?',
    );

    if (ok != true) return;

    await _fire.collection('services').doc(id).update({
      'active': newState,
      'updatedByAdminAt': FieldValue.serverTimestamp(),
    });

    await _sendProviderMessage(data, id, newState ? 'activated' : 'disabled');

    AdminUtils.showSnack(
        context, newState ? 'Service activated' : 'Service deactivated');
  }

  Future<void> _verifyService(
      String id, Map<String, dynamic> data) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      'Verify',
      'Verify this service?',
    );

    if (ok != true) return;

    await _fire.collection('services').doc(id).update({
      'verified': true,
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    await _sendProviderMessage(data, id, 'verified');

    AdminUtils.showSnack(context, "Service verified");
  }

  /// ============
  /// MENSAJE AL PROVEEDOR
  /// Ya NO usa email, userId, providerEmail
  /// Solo deja un campo seguro: providerId
  /// ============
  Future<void> _sendProviderMessage(
      Map<String, dynamic> d, String serviceId, String action) async {
    final admin = FirebaseAuth.instance.currentUser;

    final msg = {
      'senderId': admin?.uid,
      'senderEmail': admin?.email ?? 'admin@system',
      'senderName': admin?.displayName ?? 'Admin',
      'providerId': d['providerId'] ?? d['id'],
      'serviceId': serviceId,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      'type': action,
      'title': 'Service $action',
      'text': 'Your service "${d['name']}" has been $action by the admin.',
    };

    await _fire.collection('messages').add(msg);
  }

  void _openServicesModal(Map<String, dynamic> provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => FutureBuilder(
        future: _getServicesForProvider(provider),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ));
          }

          final services = snap.data!;
          if (services.isEmpty) {
            return const Center(
                child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No services found'),
            ));
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            builder: (_, controller) => ListView.builder(
              controller: controller,
              itemCount: services.length,
              itemBuilder: (_, i) {
                final doc = services[i];
                final d = doc.data();

                return ListTile(
                  title: Text(d['name'] ?? 'Service'),
                  subtitle: Text(d['description'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          d['active'] == true ? Icons.pause : Icons.play_arrow,
                          color: Colors.blue,
                        ),
                        onPressed: () => _toggleServiceActive(
                            doc.id, !(d['active'] == true), d),
                      ),
                      if (d['verified'] != true)
                        IconButton(
                          icon:
                              const Icon(Icons.verified, color: Colors.green),
                          onPressed: () => _verifyService(doc.id, d),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Providers Management"),
        backgroundColor: primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProviders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _providers.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final doc = _providers[i];
                final d = doc.data();

                final name =
                    d['name'] ?? d['businessName'] ?? 'Provider';
                final approved = d['approved'] == true;

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(name.isNotEmpty
                        ? name[0].toUpperCase()
                        : 'P'),
                  ),
                  title: Text(name),
                  subtitle: Text(
                      "Status: ${approved ? 'Approved' : 'Pending'}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          approved
                              ? Icons.check_circle
                              : Icons.check,
                          color:
                              approved ? Colors.green : Colors.grey,
                        ),
                        onPressed: () =>
                            _approveProvider(doc.id, !approved),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.list, color: Colors.teal),
                        onPressed: () =>
                            _openServicesModal(d),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}