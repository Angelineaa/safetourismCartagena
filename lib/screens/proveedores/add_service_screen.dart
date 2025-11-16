import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Controladores (en español)
  final nombreCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final tipoCtrl = TextEditingController();
  final precioCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final contactoCtrl = TextEditingController();
  final nombreUbicacionCtrl = TextEditingController();
  final imagenUrlCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();
  final horarioCtrl = TextEditingController(); // nuevo campo horario

  bool _loading = false;

  // Sanitiza el nombre para usar como id: letras, números y guiones bajos
  String _sanitizeId(String raw) {
    final s = raw.trim().toLowerCase();
    // reemplaza espacios por guiones bajos y elimina caracteres no alfanuméricos/_/-
    return s.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^\w\-]'), '');
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No hay usuario autenticado");

      // 1) Obtener providerId: buscar documento en 'users' por email
      String providerId = '';
      try {
        final q = await _firestore.collection('users').where('email', isEqualTo: user.email).limit(1).get();
        if (q.docs.isNotEmpty) {
          providerId = q.docs.first.id;
        } else {
          // fallback: si no encuentra por email, usar uid (pero preferimos doc id)
          providerId = user.uid;
        }
      } catch (e) {
        providerId = user.uid;
      }

      // 2) Construir serviceId a partir del nombre (sanitizado)
      final rawName = nombreCtrl.text.trim();
      if (rawName.isEmpty) throw Exception("El nombre del servicio no puede estar vacío");
      String baseId = _sanitizeId(rawName);
      if (baseId.isEmpty) {
        // si sanitizado queda vacío, usar timestamp
        baseId = 'service_${DateTime.now().millisecondsSinceEpoch}';
      }

      // 3) Si ya existe documento con ese id, añadimos sufijo para evitar sobreescribir
      String finalServiceId = baseId;
      final existing = await _firestore.collection('services').doc(finalServiceId).get();
      if (existing.exists) {
        finalServiceId = '${baseId}_${DateTime.now().millisecondsSinceEpoch}';
      }

      // 4) Crear documento con serviceId = nombre sanitizado (o con sufijo si colisión)
      final docRef = _firestore.collection('services').doc(finalServiceId);

      await docRef.set({
        // guardamos el serviceId explícitamente y el nombre literal
        'serviceId': finalServiceId,
        'name': nombreCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'type': tipoCtrl.text.trim(),
        'priceRange': precioCtrl.text.trim(),
        'address': direccionCtrl.text.trim(),
        'contact': contactoCtrl.text.trim(),
        'locationName': nombreUbicacionCtrl.text.trim(),
        'latitude': double.tryParse(latCtrl.text.trim()) ?? 0.0,
        'longitude': double.tryParse(lngCtrl.text.trim()) ?? 0.0,
        'imageUrl': imagenUrlCtrl.text.trim(),
        'rating': 0,
        'verified': false,
        'createdAt': FieldValue.serverTimestamp(),

        // campos nuevos/solicitados
        'service_hours': horarioCtrl.text.trim(), // horario en español
        'providerEmail': user.email ?? '',
        'providerId': providerId, // id del documento en 'users' (o fallback uid)
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Servicio registrado correctamente")),
      );

      // limpiar formulario
      _formKey.currentState!.reset();
      nombreCtrl.clear();
      descCtrl.clear();
      tipoCtrl.clear();
      precioCtrl.clear();
      direccionCtrl.clear();
      contactoCtrl.clear();
      nombreUbicacionCtrl.clear();
      imagenUrlCtrl.clear();
      latCtrl.clear();
      lngCtrl.clear();
      horarioCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error guardando servicio: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    descCtrl.dispose();
    tipoCtrl.dispose();
    precioCtrl.dispose();
    direccionCtrl.dispose();
    contactoCtrl.dispose();
    nombreUbicacionCtrl.dispose();
    imagenUrlCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    horarioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrar Servicio"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Ingresa los detalles de tu servicio.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),

              _buildField(nombreCtrl, "Nombre del servicio"),
              _buildField(descCtrl, "Descripción", maxLines: 3),
              _buildField(tipoCtrl, "Tipo (ej. Hoteles, Restaurantes, Tours)"),
              _buildField(precioCtrl, "Rango de precio (ej. \$300 - \$450 / noche)"),
              _buildField(direccionCtrl, "Dirección (ej. Carrera 3 #31-23, Centro Histórico, Cartagena)"),
              _buildField(contactoCtrl, "Contacto (ej. +57 300 1234567)"),
              _buildField(nombreUbicacionCtrl, "Nombre de la ubicación (ej. Centro Histórico)"),
              Row(
                children: [
                  Expanded(child: _buildField(latCtrl, "Latitud")),
                  const SizedBox(width: 8),
                  Expanded(child: _buildField(lngCtrl, "Longitud")),
                ],
              ),
              _buildField(imagenUrlCtrl, "URL de la imagen (https://...)"),

              // Nuevo campo horario (service_hours)
              _buildField(horarioCtrl, "Horario (ej. 08:00 - 20:00)"),

              const SizedBox(height: 24),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _saveService,
                      icon: const Icon(Icons.save),
                      label: const Text("Guardar servicio"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (v) => v == null || v.isEmpty ? "Campo obligatorio" : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}