import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_utils.dart';

class AdminToolsScreen extends StatefulWidget {
  const AdminToolsScreen({super.key});
  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  final _fire = FirebaseFirestore.instance;

  late final Stream<QuerySnapshot> _routesStream;
  late final Stream<QuerySnapshot> _zonesStream;

  @override
  void initState() {
    super.initState();
    // Initialize streams once in initState - with delay to allow Firestore initialization
    Future.delayed(const Duration(milliseconds: 500), () {
      try {
        _routesStream = _fire.collection('routes').snapshots();
        _zonesStream = _fire.collection('risk_zones').snapshots();
        debugPrint('AdminToolsScreen: Streams initialized successfully');
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('AdminToolsScreen Error: $e');
      }
    });
  }

  // ---------- util: parse "lat,lng" -> GeoPoint ----------
  GeoPoint? _parseLatLng(String s) {
    try {
      final parts = s.split(',');
      if (parts.length != 2) return null;
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      return GeoPoint(lat, lng);
    } catch (_) {
      return null;
    }
  }

  // parse path: "lat,lng;lat,lng;..."
  List<GeoPoint> _parsePath(String raw) {
    final out = <GeoPoint>[];
    try {
      final parts = raw.split(';');
      for (var p in parts) {
        p = p.trim();
        if (p.isEmpty) continue;
        final gp = _parseLatLng(p);
        if (gp != null) out.add(gp);
      }
    } catch (_) {}
    return out;
  }

  // ---------- create or edit route ----------
  Future<void> _editRoute(String? docId, Map<String, dynamic>? current) async {
    final routeIdCtrl = TextEditingController(text: current?['routeId'] ?? '');
    final nameOriginCtrl = TextEditingController(text: current?['name_origin'] ?? '');
    final nameDestCtrl = TextEditingController(text: current?['name_destine'] ?? '');
    final originCtrl = TextEditingController(text: current?['origin'] is GeoPoint
        ? '${(current!['origin'] as GeoPoint).latitude},${(current['origin'] as GeoPoint).longitude}'
        : (current?['origin']?.toString() ?? ''));
    final destCtrl = TextEditingController(text: current?['destination'] is GeoPoint
        ? '${(current!['destination'] as GeoPoint).latitude},${(current['destination'] as GeoPoint).longitude}'
        : (current?['destination']?.toString() ?? ''));
    final pathCtrl = TextEditingController(text: current?['path'] is List
        ? (current!['path'] as List).map((e) => e is GeoPoint ? '${e.latitude},${e.longitude}' : e.toString()).join(';')
        : (current?['rawPoints']?.toString() ?? ''));
    final distanceCtrl = TextEditingController(text: current?['distance']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: current?['price']?.toString() ?? '');
    final riskLevelCtrl = TextEditingController(text: current?['riskLevel'] ?? (current?['risk_level'] ?? ''));

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: routeIdCtrl, decoration: const InputDecoration(labelText: 'routeId (e.g. R001)')),
            const SizedBox(height: 8),
            TextField(controller: nameOriginCtrl, decoration: const InputDecoration(labelText: 'name_origin')),
            const SizedBox(height: 8),
            TextField(controller: nameDestCtrl, decoration: const InputDecoration(labelText: 'name_destine')),
            const SizedBox(height: 8),
            TextField(controller: originCtrl, decoration: const InputDecoration(labelText: 'origin (lat,lng)')),
            const SizedBox(height: 8),
            TextField(controller: destCtrl, decoration: const InputDecoration(labelText: 'destination (lat,lng)')),
            const SizedBox(height: 8),
            TextField(controller: pathCtrl, decoration: const InputDecoration(labelText: 'path (lat,lng;lat,lng;...)'), maxLines: 3),
            const SizedBox(height: 8),
            TextField(controller: distanceCtrl, decoration: const InputDecoration(labelText: 'distance (string, e.g. "3.2 km")')),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'price (string)')),
            const SizedBox(height: 8),
            TextField(controller: riskLevelCtrl, decoration: const InputDecoration(labelText: 'riskLevel (Low/Medium/High)')),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );

    if (saved != true) return;

    // validate and build doc
    final routeId = routeIdCtrl.text.trim();
    final originGP = _parseLatLng(originCtrl.text.trim());
    final destGP = _parseLatLng(destCtrl.text.trim());
    final pathList = _parsePath(pathCtrl.text.trim());

    final payload = <String, dynamic>{
      if (routeId.isNotEmpty) 'routeId': routeId,
      if (nameOriginCtrl.text.trim().isNotEmpty) 'name_origin': nameOriginCtrl.text.trim(),
      if (nameDestCtrl.text.trim().isNotEmpty) 'name_destine': nameDestCtrl.text.trim(),
      if (originGP != null) 'origin': originGP,
      if (destGP != null) 'destination': destGP,
      if (pathList.isNotEmpty) 'path': pathList,
      if (distanceCtrl.text.trim().isNotEmpty) 'distance': distanceCtrl.text.trim(),
      if (priceCtrl.text.trim().isNotEmpty) 'price': priceCtrl.text.trim(),
      if (riskLevelCtrl.text.trim().isNotEmpty) 'riskLevel': riskLevelCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (docId == null) {
      // create
      await _fire.collection('routes').add({...payload, 'createdAt': FieldValue.serverTimestamp()});
      AdminUtils.showSnack(context, 'Route created', color: Colors.green);
    } else {
      await _fire.collection('routes').doc(docId).set(payload, SetOptions(merge: true));
      AdminUtils.showSnack(context, 'Route updated', color: Colors.green);
    }
  }

  // ---------- create or edit risk zone ----------
  Future<void> _editZone(String? docId, Map<String, dynamic>? current) async {
    final nameCtrl = TextEditingController(text: current?['name'] ?? '');
    final levelCtrl = TextEditingController(text: current?['level'] ?? '');
    final radiusCtrl = TextEditingController(text: current?['radius']?.toString() ?? '');
    final locCtrl = TextEditingController(text: current?['location'] is GeoPoint
        ? '${(current!['location'] as GeoPoint).latitude},${(current['location'] as GeoPoint).longitude}'
        : (current?['location']?.toString() ?? ''));
    final colorCtrl = TextEditingController(text: current?['color'] ?? current?['colorCode'] ?? current?['color_name'] ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Zone name')),
          const SizedBox(height: 8),
          TextField(controller: levelCtrl, decoration: const InputDecoration(labelText: 'level (Low/Medium/High)')),
          const SizedBox(height: 8),
          TextField(controller: radiusCtrl, decoration: const InputDecoration(labelText: 'radius (meters)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'location (lat,lng)')),
          const SizedBox(height: 8),
          TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'color (name or hex, e.g. orange or #FFA500)')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          const SizedBox(height: 12),
        ]),
      ),
    );

    if (saved != true) return;

    final locGP = _parseLatLng(locCtrl.text.trim());
    final radius = int.tryParse(radiusCtrl.text.trim()) ?? 0;

    final payload = <String, dynamic>{
      if (nameCtrl.text.trim().isNotEmpty) 'name': nameCtrl.text.trim(),
      if (levelCtrl.text.trim().isNotEmpty) 'level': levelCtrl.text.trim(),
      'radius': radius,
      if (locGP != null) 'location': locGP,
      if (colorCtrl.text.trim().isNotEmpty) 'color': colorCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (docId == null) {
      await _fire.collection('risk_zones').add({...payload, 'createdAt': FieldValue.serverTimestamp()});
      AdminUtils.showSnack(context, 'Risk zone created', color: Colors.green);
    } else {
      await _fire.collection('risk_zones').doc(docId).set(payload, SetOptions(merge: true));
      AdminUtils.showSnack(context, 'Risk zone updated', color: Colors.green);
    }
  }

  Future<void> _deleteDoc(String col, String id) async {
    final ok = await AdminUtils.confirmDialog(context, 'Delete', 'Delete this item?');
    if (ok != true) return;
    await _fire.collection(col).doc(id).delete();
    AdminUtils.showSnack(context, 'Deleted', color: Colors.redAccent);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Tools'),
        backgroundColor: primary,
        actions: [
          // Create route
          IconButton(
            tooltip: 'Create route',
            icon: const Icon(Icons.add_road),
            onPressed: () => _editRoute(null, null),
          ),
          // Create zone
          IconButton(
            tooltip: 'Create risk zone',
            icon: const Icon(Icons.add_location_alt),
            onPressed: () => _editZone(null, null),
          ),
        ],
      ),
      body: Column(
        children: [
          // Routes panel
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _routesStream,
              builder: (c, s) {
                if (s.hasError) {
                  return Center(child: Text('Error: ${s.error}'));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = s.data!.docs;
                return Column(
                  children: [
                    ListTile(title: Text('Routes (${docs.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(child: Text('No routes'))
                          : ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(data['name'] ?? data['routeId'] ?? 'Route'),
                            subtitle: Text('${data['name_origin'] ?? ''} → ${data['name_destine'] ?? ''}\n${data['price'] ?? ''}'),
                            isThreeLine: true,
                            leading: const Icon(Icons.alt_route, color: Color(0xFF007274)),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              // Map button REMOVED as requested
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editRoute(d.id, data)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteDoc('routes', d.id)),
                            ]),
                          );
                        },
                      ),
                    )
                  ],
                );
              },
            ),
          ),

          const Divider(),

          // Zones panel
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _zonesStream,
              builder: (c, s) {
                if (s.hasError) {
                  return Center(child: Text('Error: ${s.error}'));
                }
                if (!s.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = s.data!.docs;
                return Column(
                  children: [
                    ListTile(title: Text('Risk Zones (${docs.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: docs.isEmpty
                          ? const Center(child: Text('No risk zones'))
                          : ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text(data['name'] ?? 'Zone'),
                            subtitle: Text('Level: ${data['level'] ?? '-'} • Radius: ${data['radius'] ?? '-'}m'),
                            leading: Icon(Icons.location_on, color: Colors.orangeAccent),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editZone(d.id, data)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteDoc('risk_zones', d.id)),
                            ]),
                          );
                        },
                      ),
                    )
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}