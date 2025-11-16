import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditServiceScreen extends StatefulWidget {
  const EditServiceScreen({super.key});

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _fire = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  String? _serviceId;
  Map<String, dynamic> _data = {};
  bool _initialized = false;

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _verified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _serviceId = args;
      } else if (args is Map && args['serviceId'] != null) {
        _serviceId = args['serviceId'] as String;
      } else if (args is Map && args['id'] != null) {
        _serviceId = args['id'] as String;
      }
      _initialized = true;
      _loadService();
    }
  }

  Future<void> _loadService() async {
    if (_serviceId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final doc = await _fire.collection('services').doc(_serviceId).get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not found')));
          Navigator.pop(context);
        }
        return;
      }
      _data = doc.data() ?? {};
      _nameCtrl.text = _data['name'] ?? '';
      _descCtrl.text = _data['description'] ?? '';
      _addressCtrl.text = _data['address'] ?? '';
      _contactCtrl.text = _data['contact'] ?? '';
      _priceCtrl.text = _data['priceRange'] ?? '';
      _locationNameCtrl.text = _data['locationName'] ?? '';
      _imageUrlCtrl.text = _data['imageUrl'] ?? '';
      _verified = _data['verified'] == true;
      final lat = _data['latitude'];
      final lng = _data['longitude'];
      _latCtrl.text = lat != null ? lat.toString() : '';
      _lngCtrl.text = lng != null ? lng.toString() : '';
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading service: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceId == null) return;
    setState(() => _saving = true);
    try {
      final update = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'contact': _contactCtrl.text.trim(),
        'priceRange': _priceCtrl.text.trim(),
        'locationName': _locationNameCtrl.text.trim(),
        'imageUrl': _imageUrlCtrl.text.trim(),
        'verified': _verified,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final lat = double.tryParse(_latCtrl.text.trim());
      final lng = double.tryParse(_lngCtrl.text.trim());
      if (lat != null && lng != null) {
        update['latitude'] = lat;
        update['longitude'] = lng;
      }

      await _fire.collection('services').doc(_serviceId).set(update, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service updated')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteService() async {
    if (_serviceId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete service'),
        content: const Text('Are you sure you want to permanently delete this service?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _fire.collection('services').doc(_serviceId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service deleted')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _priceCtrl.dispose();
    _locationNameCtrl.dispose();
    _imageUrlCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: Text(_serviceId == null ? 'Create Service' : 'Edit Service'),
        backgroundColor: primary,
        actions: [
          if (!_loading && _serviceId != null)
            IconButton(icon: const Icon(Icons.delete_forever), onPressed: _deleteService),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(14.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationNameCtrl,
                      decoration: const InputDecoration(labelText: 'Location name (e.g. Centro Histórico)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latCtrl,
                            decoration: const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lngCtrl,
                            decoration: const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactCtrl,
                      decoration: const InputDecoration(labelText: 'Contact', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: 'Price Range', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _imageUrlCtrl,
                      decoration: const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Verified'),
                      value: _verified,
                      onChanged: (v) => setState(() => _verified = v),
                    ),
                    const SizedBox(height: 16),
                    _saving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(backgroundColor: primary, minimumSize: const Size(double.infinity, 50)),
                            child: const Text('Save changes'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}