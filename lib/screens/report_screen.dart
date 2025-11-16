import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _incidentTypeController = TextEditingController();

  bool _loading = false;

  XFile? _pickedFile; // imagen seleccionada (ImagePicker XFile)
  Uint8List? _imageBytes; // bytes para previsualizar
  String? _fileName;

  // Seleccionar imagen (galería o cámara)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      setState(() {
        _pickedFile = picked;
        _imageBytes = bytes;
        _fileName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  // Subir reporte (SIMULACIÓN de URL, NO usa Storage)
  Future<void> _submitReport() async {
    final desc = _descriptionController.text.trim();
    final loc = _locationController.text.trim();
    final inc = _incidentTypeController.text.trim();

    if (desc.isEmpty || loc.isEmpty || inc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all the fields")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      // Buscar documento del usuario por correo para obtener su 'id' (campo 'id' en doc)
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      String userId = "unknown";
      if (userQuery.docs.isNotEmpty) {
        final d = userQuery.docs.first.data();
        if (d.containsKey('id') && d['id'] != null && d['id'].toString().isNotEmpty) {
          userId = d['id'].toString();
        } else {
          userId = userQuery.docs.first.id;
        }
      }

      // 🔹 SIMULACIÓN: si hay imagen, generamos una URL falsa en vez de subir
      String? fileUrl;
      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        final userEmail = user.email ?? 'unknown';
        final safeEmail = userEmail.replaceAll(RegExp(r'[^\w@._-]'), '_');
        final simulatedFileName =
            "${safeEmail}_${DateTime.now().millisecondsSinceEpoch}_${_fileName ?? 'evidence'}.jpg";
        fileUrl = "https://fake-storage.example.com/reports/$simulatedFileName";
        // Nota: es solo una cadena simulada, no hace upload.
      }

      // Crear documento del reporte (firestore genera id)
      final reportRef = _firestore.collection('reports').doc();
      final reportData = {
        "reportId": reportRef.id,                     // id generado y guardado
        "userId": userId,
        "userEmail": user.email ?? '',
        "description": desc,
        "incidentType": inc,
        "location": loc,
        "status": "Under review",
        "adminResponse": "",
        "date": Timestamp.fromDate(DateTime.now()),
        "createdAt": FieldValue.serverTimestamp(),     // marca temporal fiable
        "evidenceUrl": fileUrl ?? "",
      };

      await reportRef.set(reportData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report sent successfully")),
        );

        // limpiar campos
        setState(() {
          _descriptionController.clear();
          _incidentTypeController.clear();
          _locationController.clear();
          _pickedFile = null;
          _imageBytes = null;
          _fileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending report: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _incidentTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report an Issue", style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              "Describe the issue and (optionally) attach evidence.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            // incident type
            TextField(
              controller: _incidentTypeController,
              decoration: const InputDecoration(
                labelText: "Incident Type",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // location
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: "Location",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // description
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // botones para elegir imagen (previsualización local sólo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text("Gallery"),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // vista previa: si hay bytes, mostramos Image.memory (funciona en web y móvil)
            if (_imageBytes != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.memory(_imageBytes!, height: 220, fit: BoxFit.cover),
              ),

            const SizedBox(height: 20),

            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _submitReport,
                    icon: const Icon(Icons.send),
                    label: const Text("Send Report"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}