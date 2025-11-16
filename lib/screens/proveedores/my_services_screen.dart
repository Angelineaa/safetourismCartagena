import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _providerEmail = '';
  String _providerId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    _providerEmail = user.email ?? '';

    try {
      // Buscar el documento del usuario para obtener su ID único
      final query = await _fire
          .collection('users')
          .where('email', isEqualTo: _providerEmail)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _providerId = query.docs.first.id;
      } else {
        _providerId = user.uid;
      }
    } catch (e) {
      debugPrint("Error obteniendo ID del proveedor: $e");
      _providerId = user.uid;
    }

    setState(() => _loading = false);
  }

  /// 🔹 Consulta principal: obtiene todos los servicios del proveedor actual
  Stream<QuerySnapshot> _servicesStream() {
    if (_providerEmail.isEmpty) {
      // Stream vacío si aún no se ha cargado el correo
      return _fire
          .collection('services')
          .where('providerEmail', isEqualTo: '__NO_EMAIL__')
          .snapshots();
    }

    // Consulta con filtro y orden (requiere índice compuesto)
    return _fire
        .collection('services')
        .where('providerEmail', isEqualTo: _providerEmail)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> _openEdit(String serviceId) async {
    final result =
        await Navigator.pushNamed(context, '/editService', arguments: serviceId);
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio actualizado correctamente')),
      );
    }
  }

  Future<void> _showReviews(String serviceId) async {
    try {
      List<QueryDocumentSnapshot> reviews = [];

      // Intentar obtener reseñas de la subcolección del servicio
      try {
        final sub = await _fire
            .collection('services')
            .doc(serviceId)
            .collection('reviews')
            .orderBy('createdAt', descending: true)
            .get();
        reviews = sub.docs;
      } catch (e) {
        debugPrint('Error fetching reviews from subcollection: $e');
      }

      // Si no hay reseñas en la subcolección, buscar en la colección global
      if (reviews.isEmpty) {
        try {
          final global = await _fire
              .collection('reviews')
              .where('serviceId', isEqualTo: serviceId)
              .orderBy('createdAt', descending: true)
              .get();
          reviews = global.docs;
        } catch (e) {
          debugPrint('Error fetching reviews from global collection: $e');
        }
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) {
          if (reviews.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text("No hay reseñas disponibles")),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, i) {
              final data = reviews[i].data() as Map<String, dynamic>;
              final user = data['userEmail'] ?? 'Usuario';
              final comment = data['comment'] ?? '';
              final rating = data['rating']?.toString() ?? '';
              final date = data['createdAt'];
              String dateStr = '';
              if (date is Timestamp) {
                dateStr =
                    "${date.toDate().day}/${date.toDate().month}/${date.toDate().year}";
              }

              return ListTile(
                title: Text('$user ${rating.isNotEmpty ? '· $rating⭐' : ''}'),
                subtitle: Text(comment),
                trailing: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      debugPrint('Error in _showReviews: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reseñas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Servicios"),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _servicesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text("No tienes servicios registrados."),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _serviceTile(docs[i].id, data);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/addService'),
        backgroundColor: primary,
        icon: const Icon(Icons.add),
        label: const Text("Nuevo Servicio"),
      ),
    );
  }

  Widget _serviceTile(String id, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Servicio';
    final type = data['type'] ?? '';
    final price = data['priceRange'] ?? '';
    final address = data['address'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final rating = data['rating']?.toString() ?? '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl,
                    width: 64, height: 64, fit: BoxFit.cover),
              )
            : CircleAvatar(
                backgroundColor: const Color(0xFF007274),
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white)),
              ),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('$type\n$price\n$address ${rating.isNotEmpty ? "· $rating⭐" : ""}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: () => _showReviews(id),
              tooltip: "Ver reseñas",
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _openEdit(id),
              tooltip: "Editar servicio",
            ),
          ],
        ),
      ),
    );
  }
}