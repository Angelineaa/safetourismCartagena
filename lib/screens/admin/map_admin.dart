import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MapAdminScreen extends StatefulWidget {
  const MapAdminScreen({super.key});

  @override
  State<MapAdminScreen> createState() => _MapAdminScreenState();
}

class _MapAdminScreenState extends State<MapAdminScreen> {
  final _fire = FirebaseFirestore.instance;

  // Stream de las rutas
  Stream<QuerySnapshot<Map<String, dynamic>>> _routesStream() {
    return _fire
        .collection('routes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Abrir ruta en el mapa
  void _openRouteOnMap(Map<String, dynamic> route) {
    Navigator.pushNamed(context, '/maps', arguments: {'route': route});
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routes Admin'),
        backgroundColor: primary,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _routesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error loading routes: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No routes available.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final name = (d['name'] ?? '-').toString();
              final rawPoints = (d['rawPoints'] ?? d['path'] ?? '').toString();

              return ListTile(
                leading: const Icon(Icons.directions, color: primary),
                title: Text(name),
                subtitle: Text(
                  rawPoints,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.map),
                  tooltip: 'Open route in map',
                  onPressed: () => _openRouteOnMap({...d, 'id': doc.id}),
                ),
                onTap: () => _openRouteOnMap({...d, 'id': doc.id}),
              );
            },
          );
        },
      ),
    );
  }
}