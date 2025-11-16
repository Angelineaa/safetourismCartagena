import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _adminResponseCtrl = TextEditingController();
  String _status = '';
  bool _loading = false;
  late QueryDocumentSnapshot reportDoc;
  bool isAdmin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['reportDoc'] != null) {
      reportDoc = args['reportDoc'] as QueryDocumentSnapshot;
      isAdmin = args['isAdmin'] ?? false;
      final data = reportDoc.data() as Map<String, dynamic>;
      _status = data['status'] ?? 'Under review';
      _adminResponseCtrl.text = data['adminResponse'] ?? '';
    } else {
      // Si no vienen args, cerramos la pantalla
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await reportDoc.reference.update({'status': newStatus});
      setState(() => _status = newStatus);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando estado: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAdminResponse() async {
    setState(() => _loading = true);
    try {
      await reportDoc.reference.update({
        'adminResponse': _adminResponseCtrl.text.trim(),
        'status': _status,
        'reviewedBy': _auth.currentUser?.email ?? '',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Respuesta guardada')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando respuesta: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildAdminActions() {
    if (!isAdmin) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('Actualizar estado:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Under review', 'In progress', 'Resolved', 'Rejected'].map((s) {
            final active = s == _status;
            return ElevatedButton(
              onPressed: () => _updateStatus(s),
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? const Color(0xFF007274) : Colors.grey[300],
                foregroundColor: active ? Colors.white : Colors.black,
              ),
              child: Text(s),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text('Respuesta del admin:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _adminResponseCtrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Escribe tu respuesta...'),
        ),
        const SizedBox(height: 8),
        _loading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                onPressed: _saveAdminResponse,
                icon: const Icon(Icons.save),
                label: const Text('Guardar respuesta'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007274)),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = reportDoc.data() as Map<String, dynamic>;
    final primary = const Color(0xFF007274);

    final evidenceUrl = (data['evidenceUrl'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del reporte'), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tipo: ${data['incidentType'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Ubicación: ${data['location'] ?? ''}'),
          const SizedBox(height: 8),
          Text('Usuario: ${data['userEmail'] ?? ''}'),
          const SizedBox(height: 8),
          Text('Fecha: ${data['date'] is Timestamp ? (data['date'] as Timestamp).toDate().toString() : (data['date'] ?? '')}'),
          const SizedBox(height: 12),
          const Text('Descripción:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(data['description'] ?? ''),
          const SizedBox(height: 12),

          // No mostramos la imagen completa — solo indicamos si existe evidencia
          if (evidenceUrl.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Evidencia adjunta:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(evidenceUrl, style: const TextStyle(color: Colors.blue)),
              const SizedBox(height: 12),
            ]),

          const Divider(),
          Text('Estado: $_status', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if ((data['adminResponse'] ?? '').toString().isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Respuesta admin:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(data['adminResponse'] ?? ''),
              const SizedBox(height: 12),
            ]),

          _buildAdminActions(),
        ]),
      ),
    );
  }
}