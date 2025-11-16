import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});
  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> _reportsStream() =>
      _fire.collection('reports').orderBy('createdAt', descending: true).snapshots();

  /// Abre modal para actualizar nivel de gravedad / estado / respuesta admin.
  Future<void> _openUpdateModal(String id, Map<String, dynamic> current) async {
    final levels = ['Low', 'Medium', 'High'];
    String selectedLevel = (current['level'] ?? current['riskLevel'] ?? 'Low').toString();
    if (!levels.contains(selectedLevel)) selectedLevel = 'Low';

    String status = (current['status'] ?? 'open').toString(); // open | in_progress | resolved
    bool resolved = status == 'resolved';

    final responseCtrl = TextEditingController(text: current['adminResponse'] ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(builder: (context, setStateModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Update report status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                // severity dropdown
                Row(children: [
                  const Text('Severity: '),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: selectedLevel,
                    items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setStateModal(() => selectedLevel = v ?? selectedLevel),
                  ),
                ]),
                const SizedBox(height: 12),

                // resolved switch
                Row(children: [
                  const Text('Resolved: '),
                  const SizedBox(width: 12),
                  Switch(value: resolved, onChanged: (v) => setStateModal(() => resolved = v)),
                ]),
                const SizedBox(height: 12),

                // admin response
                TextField(
                  controller: responseCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Admin response / message to reporter',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save updates'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
            );
          }),
        );
      },
    );

    if (saved != true) return;

    await _applyReportUpdate(id, current, selectedLevel, resolved, responseCtrl.text.trim());
  }

 Future<void> _applyReportUpdate(String id, Map<String, dynamic> current, String level, bool resolved, String adminResponse) async {
  try {
    final adminUser = _auth.currentUser;
    final adminId = adminUser?.uid ?? 'admin';
    final adminEmail = adminUser?.email ?? 'admin@safetourism.com';
    final adminName = adminUser?.displayName ?? 'Admin';

    // calcular nuevo status string
    final newStatus = resolved ? 'resolved' : ((current['status'] == 'open') ? 'in_progress' : (current['status'] ?? 'in_progress'));

    // 1) actualizar documento principal 'reports' (campos visibles)
    await _fire.collection('reports').doc(id).update({
      'level': level,
      'status': newStatus,
      'adminResponse': adminResponse,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) en lugar de crear una colección nueva, agregar un entry al mismo documento reports.statusHistory (array)
    final historyEntry = {
      'level': level,
      'resolved': resolved,
      'adminResponse': adminResponse,
      'adminId': adminId,
      'adminEmail': adminEmail,
      'adminName': adminName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // añadir (arrayUnion) para preservar historial dentro del documento reports
    await _fire.collection('reports').doc(id).update({
      'statusHistory': FieldValue.arrayUnion([historyEntry])
    });

    // 3) Si es grave / high -> notificar autoridad (simulación) y enviar mensaje al reporter (ENGLISH + report id)
    final levelLower = level.toLowerCase();
    final reporterEmail = (current['userEmail'] ?? current['reporterEmail'] ?? '').toString();
    final reporterId = (current['userId'] ?? current['reporterId'] ?? '').toString();
    final title = (current['title'] ?? 'Report').toString();

    if (levelLower.contains('high')) {
      // Simular notificación a autoridad (colección authority_notifications)
      await _fire.collection('authority_notifications').add({
        'reportId': id,
        'reportSnapshot': current,
        'notifiedAt': FieldValue.serverTimestamp(),
        'message': 'An authority has been alerted and is on the way (simulated).',
        'status': 'sent',
      });

      // enviar mensaje al reporter (collection 'messages') - ENGLISH and include report id
      final msgBody = 'Your report (ID: $id) titled "$title" has been escalated due to its severity. An authority has been notified and is on the way.';
      final msg = {
        'senderId': adminId,
        'senderEmail': adminEmail,
        'senderName': adminName,
        'recipientId': reporterId.isNotEmpty ? reporterId : null,
        'recipientEmail': reporterEmail.isNotEmpty ? reporterEmail : null,
        'title': 'Report escalated',
        'text': msgBody,
        'reportId': id,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'report_escalation',
      }..removeWhere((k, v) => v == null);
      await _fire.collection('messages').add(msg);
    } else {
      // si no es high, igualmente notificar al reporter con la respuesta si adminResponse existe (ENGLISH + report id)
      if (adminResponse.isNotEmpty) {
        final msgBody = 'Update on your report (ID: $id) titled "$title":\n\n${adminResponse}';
        final msg = {
          'senderId': adminId,
          'senderEmail': adminEmail,
          'senderName': adminName,
          'recipientId': reporterId.isNotEmpty ? reporterId : null,
          'recipientEmail': reporterEmail.isNotEmpty ? reporterEmail : null,
          'title': 'Update on your report',
          'text': msgBody,
          'reportId': id,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'report_response',
        }..removeWhere((k, v) => v == null);
        await _fire.collection('messages').add(msg);
      }
    }

    AdminUtils.showSnack(context, 'Report status updated', color: Colors.green);
  } catch (e) {
    AdminUtils.showSnack(context, 'Error updating report: $e', color: Colors.redAccent);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Reports Management'), backgroundColor: const Color(0xFF007274)),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reportsStream(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No reports'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final level = (data['level'] ?? data['riskLevel'] ?? 'N/A').toString();
              final status = (data['status'] ?? 'open').toString();
              final created = data['createdAt'];
              final createdStr = created is Timestamp ? created.toDate().toString() : (created?.toString() ?? '-');

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: level.toLowerCase().contains('high') ? Colors.redAccent : (level.toLowerCase().contains('medium') ? Colors.orange : Colors.green),
                  child: Text(level.isNotEmpty ? level[0].toUpperCase() : 'R', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(data['title'] ?? 'Report'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),
                  Text('Level: $level  •  Status: $status'),
                  const SizedBox(height: 6),
                  Text(data['description'] ?? ''),
                ]),
                isThreeLine: true,
                // boton para actualizar nivel / estado / respuesta (NO editar contenido)
                trailing: IconButton(
                  icon: const Icon(Icons.update, color: Colors.blue),
                  tooltip: 'Update severity / status',
                  onPressed: () => _openUpdateModal(d.id, data),
                ),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(data['title'] ?? 'Report', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Reported by: ${data['userEmail'] ?? data['reporterEmail'] ?? '-'}'),
                          const SizedBox(height: 8),
                          Text(data['description'] ?? ''),
                          const SizedBox(height: 8),
                          Text('Created: $createdStr', style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          if ((data['adminResponse'] ?? '').toString().isNotEmpty)
                            Text('Admin response: ${data['adminResponse']}', style: const TextStyle(color: Colors.blue)),
                          const SizedBox(height: 12),
                          Row(children: [
                            ElevatedButton(
                              onPressed: () => _openUpdateModal(d.id, data),
                              child: const Text('Update status'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                          ])
                        ]),
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