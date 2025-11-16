import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_utils.dart';

class ServicesManagementScreen extends StatefulWidget {
  const ServicesManagementScreen({super.key});

  @override
  State<ServicesManagementScreen> createState() =>
      _ServicesManagementScreenState();
}

class _ServicesManagementScreenState extends State<ServicesManagementScreen> {
  final _fire = FirebaseFirestore.instance;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _servicesStream;

  @override
  void initState() {
    super.initState();
    // Initialize stream once in initState - removed orderBy to avoid index issues
    _servicesStream = _fire.collection('services').snapshots();
  }

  Future<void> _toggleActive(String id, bool currentActive) async {
    final ok = await AdminUtils.confirmDialog(
      context,
      currentActive ? 'Deactivate service' : 'Activate service',
      currentActive
          ? 'Are you sure you want to deactivate this service?'
          : 'Activate this service?',
    );
    if (ok != true) return;
    await _fire.collection('services').doc(id).update({
      'active': !currentActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    AdminUtils.showSnack(
        context, !currentActive ? 'Service activated' : 'Service deactivated');
  }

  // convierte de forma segura a string (maneja num, list, map, Timestamp)
  String _stringify(dynamic v) {
    if (v == null) return '-';
    if (v is String) return v;
    if (v is num) return v.toString();
    if (v is Timestamp) return v.toDate().toString();
    if (v is DateTime) return v.toString();
    if (v is List) return v.map((e) => e.toString()).join(', ');
    if (v is Map) return v.values.map((e) => e.toString()).join(', ');
    try {
      return v.toString();
    } catch (_) {
      return '-';
    }
  }

  // obtiene precio prefiriendo variantes conocidas
  String _getPrice(Map<String, dynamic> d) {
    final candidates = [
      d['price'],
      d['priceRange'],
      d['price_range'],
      d['pricePerHour'],
      d['price_per_hour'],
      d['cost'],
    ];
    for (var c in candidates) {
      if (c != null) {
        final s = _stringify(c);
        if (s.isNotEmpty && s != '-') return s;
      }
    }
    return '-';
  }

  // obtiene horario prefiriendo variantes conocidas
  String _getSchedule(Map<String, dynamic> d) {
    final candidates = [
      d['service_hours'],
      d['serviceHours'],
      d['hours'],
      d['schedule'],
      d['horario'],
      d['openingHours'],
    ];
    for (var c in candidates) {
      if (c != null) {
        final s = _stringify(c);
        if (s.isNotEmpty && s != '-') return s;
      }
    }
    return '-';
  }

  // vista detalle (modal)
  Future<void> _viewService(Map<String, dynamic> data) async {
    final price = _getPrice(data);
    final schedule = _getSchedule(data);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: (data['imageUrl'] ?? '').toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['imageUrl'].toString(),
                          height: 160,
                          width: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 80),
                        ),
                      )
                    : const CircleAvatar(radius: 40, child: Icon(Icons.room_service)),
              ),
              const SizedBox(height: 12),
              Text(_stringify(data['name']),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Price: $price'),
              const SizedBox(height: 6),
              Text('Schedule: $schedule'),
              const SizedBox(height: 6),
              Text('Active: ${((data['active'] ?? true) as bool) ? 'Yes' : 'No'}'),
              const SizedBox(height: 6),
              Text('Provider: ${_stringify(data['providerName'] ?? data['providerId'])}'),
              const SizedBox(height: 6),
              Text('Location: ${_stringify(data['location'] ?? data['locationName'])}'),
              const SizedBox(height: 12),
              Text('Description:\n${_stringify(data['description'])}'),
              const SizedBox(height: 12),
              Text('Rating: ${_stringify(data['rating'])}'),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerRight,
                  child: Text('Created: ${_stringify(data['createdAt'])}')),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // editar servicio (ahora incluye price y schedule)
  Future<void> _editServiceDoc(String docId, Map<String, dynamic> initial) async {
    final nameCtrl = TextEditingController(text: initial['name']?.toString() ?? '');
    // prefill price using helper
    final pricePrefill = _getPrice(initial);
    final priceCtrl = TextEditingController(text: pricePrefill == '-' ? '' : pricePrefill);
    final schedulePrefill = _getSchedule(initial);
    final scheduleCtrl = TextEditingController(text: schedulePrefill == '-' ? '' : schedulePrefill);

    final descCtrl = TextEditingController(text: initial['description']?.toString() ?? '');
    final imageCtrl = TextEditingController(text: initial['imageUrl']?.toString() ?? '');
    final providerCtrl = TextEditingController(
        text: initial['providerId']?.toString() ?? initial['providerName']?.toString() ?? '');
    final locationCtrl = TextEditingController(
        text: initial['location']?.toString() ?? initial['locationName']?.toString() ?? '');
    bool active = (initial['active'] ?? true) as bool;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
          ),
          child: StatefulBuilder(builder: (ctxModal, setStateModal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price (e.g. COP 15000, 10 USD, 15-20)')),
                const SizedBox(height: 8),
                TextField(controller: scheduleCtrl, decoration: const InputDecoration(labelText: 'Schedule (e.g. Mon-Sun 08:00-20:00)')),
                const SizedBox(height: 8),
                TextField(controller: providerCtrl, decoration: const InputDecoration(labelText: 'Provider id/name (optional)')),
                const SizedBox(height: 8),
                TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location (optional)')),
                const SizedBox(height: 8),
                TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Active:'),
                    const SizedBox(width: 8),
                    Switch(value: active, onChanged: (v) => setStateModal(() => active = v)),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      AdminUtils.showSnack(context, 'Name is required', color: Colors.red);
                      return;
                    }
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('Save changes'),
                ),
                const SizedBox(height: 12),
              ],
            );
          }),
        ),
      );

      if (saved == true) {
        // Guardamos price en 'price' y también en 'priceRange' por compatibilidad.
        // Guardamos horario en 'service_hours' y 'schedule' por compatibilidad con distintos esquemas.
        final payload = <String, dynamic>{
          'name': nameCtrl.text.trim(),
          'price': priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : null,
          'priceRange': priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : null,
          'service_hours': scheduleCtrl.text.trim().isNotEmpty ? scheduleCtrl.text.trim() : null,
          'schedule': scheduleCtrl.text.trim().isNotEmpty ? scheduleCtrl.text.trim() : null,
          'description': descCtrl.text.trim(),
          'imageUrl': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
          'providerId': providerCtrl.text.trim().isNotEmpty ? providerCtrl.text.trim() : null,
          'location': locationCtrl.text.trim().isNotEmpty ? locationCtrl.text.trim() : null,
          'active': active,
          'updatedAt': FieldValue.serverTimestamp(),
        }..removeWhere((k, v) => v == null);

        await _fire.collection('services').doc(docId).set(payload, SetOptions(merge: true));
        AdminUtils.showSnack(context, 'Service updated', color: Colors.green);
      }
    } finally {
      nameCtrl.dispose();
      priceCtrl.dispose();
      scheduleCtrl.dispose();
      descCtrl.dispose();
      imageCtrl.dispose();
      providerCtrl.dispose();
      locationCtrl.dispose();
    }
  }

  Future<void> _createService() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final providerCtrl = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Service name')),
          const SizedBox(height: 8),
          TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price')),
          const SizedBox(height: 8),
          TextField(controller: scheduleCtrl, decoration: const InputDecoration(labelText: 'Schedule')),
          const SizedBox(height: 8),
          TextField(controller: providerCtrl, decoration: const InputDecoration(labelText: 'Provider id/name (optional)')),
          const SizedBox(height: 8),
          TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL (optional)')),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () {
            if (nameCtrl.text.trim().isEmpty) {
              AdminUtils.showSnack(context, 'Service name is required', color: Colors.red);
              return;
            }
            Navigator.pop(context, true);
          }, child: const Text('Create')),
        ]),
      ),
    );

    if (created == true) {
      await _fire.collection('services').add({
        'name': nameCtrl.text.trim(),
        'price': priceCtrl.text.trim(),
        'priceRange': priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : null,
        'service_hours': scheduleCtrl.text.trim().isNotEmpty ? scheduleCtrl.text.trim() : null,
        'schedule': scheduleCtrl.text.trim().isNotEmpty ? scheduleCtrl.text.trim() : null,
        'description': descCtrl.text.trim(),
        'imageUrl': imageCtrl.text.trim().isNotEmpty ? imageCtrl.text.trim() : null,
        'providerId': providerCtrl.text.trim().isNotEmpty ? providerCtrl.text.trim() : null,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      AdminUtils.showSnack(context, 'Service created', color: Colors.green);
    }

    nameCtrl.dispose();
    priceCtrl.dispose();
    scheduleCtrl.dispose();
    descCtrl.dispose();
    imageCtrl.dispose();
    providerCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Management'),
        backgroundColor: const Color(0xFF007274),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createService),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _servicesStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No services'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            separatorBuilder: (_, __) => const Divider(),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final active = (data['active'] ?? true) as bool;
              final imageUrl = (data['imageUrl'] ?? '').toString();
              final provider = (data['providerName'] ?? data['providerId'] ?? '').toString();
              final price = _getPrice(data);
              final schedule = _getSchedule(data);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                leading: imageUrl.isNotEmpty
                    ? CircleAvatar(backgroundImage: NetworkImage(imageUrl))
                    : const CircleAvatar(child: Icon(Icons.room_service)),
                title: Text(data['name']?.toString() ?? 'Service'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),
                  Text('Price: $price'),
                  Text('${data['description']?.toString() ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (provider.isNotEmpty) Text('Provider: $provider'),
                  Text('Schedule: $schedule'),
                ]),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(active ? Icons.visibility : Icons.visibility_off, color: active ? Colors.green : Colors.grey),
                      onPressed: () => _toggleActive(d.id, active),
                      tooltip: active ? 'Deactivate' : 'Activate',
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: Colors.teal),
                      onPressed: () => _viewService(data),
                      tooltip: 'View details',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editServiceDoc(d.id, data),
                      tooltip: 'Edit service',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}