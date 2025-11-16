import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ---------------------------
/// AmbassadorHomeScreen (usa collection 'ambassadors')
/// ---------------------------
class AmbassadorHomeScreen extends StatefulWidget {
  const AmbassadorHomeScreen({super.key});

  @override
  State<AmbassadorHomeScreen> createState() => _AmbassadorHomeScreenState();
}

class _AmbassadorHomeScreenState extends State<AmbassadorHomeScreen> {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _ambassadorDoc;
  String? _ambassadorDocId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAmbassador();
  }

  Future<void> _loadAmbassador() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _ambassadorDoc = null;
        _ambassadorDocId = null;
        return;
      }
      final email = user.email ?? '';

      final snap = await _fire
          .collection('ambassadors')
          .where('userEmail', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        _ambassadorDocId = snap.docs.first.id;
        _ambassadorDoc = snap.docs.first.data();
      } else {
        // fallback: search by 'email' field if stored differently
        final snap2 = await _fire
            .collection('ambassadors')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (snap2.docs.isNotEmpty) {
          _ambassadorDocId = snap2.docs.first.id;
          _ambassadorDoc = snap2.docs.first.data();
        } else {
          _ambassadorDoc = null;
          _ambassadorDocId = null;
        }
      }
    } catch (e) {
      debugPrint('Error loading ambassador: $e');
      _ambassadorDoc = null;
      _ambassadorDocId = null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Decide si ya existe "aplicación" en el documento
    final hasDoc = _ambassadorDoc != null;
    final hasApplication = hasDoc &&
        (_ambassadorDoc!.containsKey('applicationStatus') ||
            _ambassadorDoc!.containsKey('idAmbassador'));

    // Si no hay documento OR existe doc pero no aplicación -> mostrar vista para enviar solicitud
    // Si hay aplicación -> mostrar vista limitada/verificada según 'verified'
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Embajador", style: TextStyle(color: Colors.white)),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/ambassador_notifications'),
          )
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(color: primary),
                accountName: Text(_ambassadorDoc?['name']?.toString() ?? 'User'),
                accountEmail: Text(_ambassadorDoc?['userEmail']?.toString() ?? _auth.currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: NetworkImage(_ambassadorDoc?['photoUrl']?.toString() ?? ''),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notificaciones'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/ambassador_notifications');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Perfil'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileEditScreen(ambassadorDoc: _ambassadorDoc, ambassadorDocId: _ambassadorDocId)),
                  ).then((_) => _loadAmbassador());
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () async {
                  Navigator.pop(context);
                  await _signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: !hasApplication ? _noAmbassadorView(primary) : _ambassadorView(primary),
            ),
          ),
          // Contact Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.email, color: Colors.white, size: 24),
                const SizedBox(height: 8),
                const Text(
                  'Need Help or Information?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Contact: adminsafetourism@gmail.com',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Vista cuando no hay aplicación aún (documento puede existir o no)
  Widget _noAmbassadorView(Color primary) {
    final existsDoc = _ambassadorDoc != null;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Aún no eres embajador.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            icon: const Icon(Icons.person_add),
            label: const Text("Enviar solicitud para ser embajador"),
            onPressed: () {
              // Si existe doc creado en el registro, pasamos existingData y existingDocId
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AmbassadorApplicationScreen(
                    existingData: existsDoc ? _ambassadorDoc : null,
                    existingDocId: existsDoc ? _ambassadorDocId : null,
                    showContactFields: false, // NO mostrar telefono/email/nacionalidad en la creación inicial
                  ),
                ),
              ).then((_) => _loadAmbassador());
            },
          ),
          const SizedBox(height: 10),
          const Text('Después de la aprobación del administrador podrás acceder a las funciones de embajador.'),
        ],
      ),
    );
  }

  Widget _ambassadorView(Color primary) {
    final data = _ambassadorDoc!;
    final verified = (data['verified'] == true);
    final appStatus = (data['applicationStatus'] ?? '').toString().toLowerCase();

    if (verified) {
      // full panel
      return Column(
        children: [
          CircleAvatar(radius: 50, backgroundImage: NetworkImage(data['photoUrl'] ?? '')),
          const SizedBox(height: 12),
          Text(data['name'] ?? 'No name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(data['nationality'] ?? ''),
          const SizedBox(height: 20),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.language, color: Colors.teal),
              title: Text("Languages: ${(data['languages'] is List) ? (data['languages'] as List).join(', ') : (data['languages']?.toString() ?? '')}"),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text("Rating: ${data['rating'] ?? 0.0} ⭐"),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            icon: const Icon(Icons.edit),
            label: const Text("Actualizar perfil"),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProfileEditScreen(ambassadorDoc: data, ambassadorDocId: _ambassadorDocId)),
              ).then((_) => _loadAmbassador());
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            icon: const Icon(Icons.message),
            label: const Text("Ver mis mensajes"),
            onPressed: () => Navigator.pushNamed(context, '/ambassador_notifications'),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: const Icon(Icons.map),
                    label: const Text("Mapa"),
                    onPressed: () => Navigator.pushNamed(context, '/map'),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                    icon: const Icon(Icons.room_service),
                    label: const Text("Servicios"),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AmbassadorServicesScreen())),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // limited view (pending / rejected)
    return Column(
      children: [
        CircleAvatar(radius: 50, backgroundImage: NetworkImage(data['photoUrl'] ?? '')),
        const SizedBox(height: 12),
        Text(data['name'] ?? 'No name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Estado de solicitud: ${data['applicationStatus'] ?? 'desconocido'}'),
        const SizedBox(height: 12),
        if (appStatus == 'pending') const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Tu solicitud está en trámite. Puedes agregar más información mientras esperas.', style: TextStyle(color: Colors.orange))),
        if (appStatus == 'rejected') const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Tu solicitud fue rechazada. Puedes actualizar y reenviar.', style: TextStyle(color: Colors.red))),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
          icon: const Icon(Icons.edit_note),
          label: const Text("Agregar información a mi solicitud"),
          onPressed: () {
            // Cuando el usuario quiere agregar info ya se muestran campos de contacto
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AmbassadorApplicationScreen(
                  existingData: _ambassadorDoc,
                  existingDocId: _ambassadorDocId,
                  showContactFields: true,
                ),
              ),
            ).then((_) => _loadAmbassador());
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
          icon: const Icon(Icons.message),
          label: const Text("Ver mis mensajes"),
          onPressed: () => Navigator.pushNamed(context, '/ambassador_notifications'),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    side: BorderSide(color: primary),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text("Mapa"),
                  onPressed: () => Navigator.pushNamed(context, '/map'),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                  icon: const Icon(Icons.room_service),
                  label: const Text("Servicios"),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AmbassadorServicesScreen())),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ------------------------------------------------------------------
/// AmbassadorServicesScreen (read-only)
/// ------------------------------------------------------------------
class AmbassadorServicesScreen extends StatelessWidget {
  AmbassadorServicesScreen({super.key});
  final FirebaseFirestore _fire = FirebaseFirestore.instance;
  final Color primary = const Color(0xFF007274);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios (solo lectura)'), backgroundColor: primary),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fire.collection('services').orderBy('name').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No se encontraron servicios.'));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final title = data['name'] ?? 'Service';
              final subtitle = data['locationName'] ?? data['type'] ?? '';
              final image = data['imageUrl'] ?? '';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                child: ListTile(
                  leading: image.toString().isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(image, width: 56, height: 56, fit: BoxFit.cover)) : const Icon(Icons.room_service),
                  title: Text(title.toString()),
                  subtitle: Text(subtitle.toString()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceDetailReadOnlyScreen(serviceData: data)));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// ServiceDetailReadOnlyScreen
/// ------------------------------------------------------------------
class ServiceDetailReadOnlyScreen extends StatelessWidget {
  final Map<String, dynamic> serviceData;
  const ServiceDetailReadOnlyScreen({super.key, required this.serviceData});

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF007274);
    final imageUrl = serviceData['imageUrl'] ?? '';
    final name = serviceData['name'] ?? 'Service';
    final description = serviceData['description'] ?? '';
    final location = serviceData['locationName'] ?? '';
    final hours = serviceData['service_hours'] ?? '';
    final rating = serviceData['rating']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(name.toString()), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (imageUrl.toString().isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(imageUrl, height: 200, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Text(name.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Ubicación: $location'),
          const SizedBox(height: 6),
          if (rating.isNotEmpty) Text('Calificación: $rating ⭐'),
          const SizedBox(height: 12),
          Text(description.toString()),
          const SizedBox(height: 12),
          Text('Horario: $hours'),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Text('Esta vista es de solo lectura. La reserva y las reseñas están deshabilitadas aquí.'),
          ),
        ]),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// ProfileEditScreen - edita doc en 'ambassadors' (debe existir)
/// ------------------------------------------------------------------
class ProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic>? ambassadorDoc;
  final String? ambassadorDocId;
  const ProfileEditScreen({super.key, this.ambassadorDoc, this.ambassadorDocId});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fire = FirebaseFirestore.instance;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  List<String> _languages = [];
  final _nationalityCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.ambassadorDoc ?? {};
    _nameCtrl.text = d['name'] ?? '';
    _phoneCtrl.text = d['phone'] ?? '';
    _emailCtrl.text = d['userEmail'] ?? d['email'] ?? '';
    _photoCtrl.text = d['photoUrl'] ?? '';
    _languages = List<String>.from(d['languages'] ?? []);
    _nationalityCtrl.text = d['nationality'] ?? '';
    _experienceCtrl.text = d['experience'] ?? '';
    _descriptionCtrl.text = d['description'] ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _photoCtrl.dispose();
    _nationalityCtrl.dispose();
    _experienceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.ambassadorDocId == null) {
      // If there's no ambassador doc, prevent editing here
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes solicitar primero para editar tu perfil de embajador.')));
      return;
    }

    setState(() => _loading = true);

    try {
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        // store as userEmail to keep consistency
        'userEmail': _emailCtrl.text.trim(),
        'photoUrl': _photoCtrl.text.trim().isNotEmpty ? _photoCtrl.text.trim() : null,
        'languages': _languages,
        'nationality': _nationalityCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

      await _fire.collection('ambassadors').doc(widget.ambassadorDocId).set(payload, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado correctamente.')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving ambassador profile: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil'), backgroundColor: primary),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Nombre completo"), validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: "Teléfono")),
              const SizedBox(height: 12),
              TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email"), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _photoCtrl, decoration: const InputDecoration(labelText: "URL de foto (enlace de imagen)")),
              const SizedBox(height: 12),
              const Text('Idiomas (administrados manualmente en edición de perfil)'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _languages.map((l) => Chip(label: Text(l))).toList(),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // quick dialog to edit languages as comma-separated text
                  final ctrl = TextEditingController(text: _languages.join(', '));
                  final res = await showDialog<String?>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Editar idiomas (separados por comas)'),
                      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ej: Español, Inglés')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                        TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Guardar')),
                      ],
                    ),
                  );
                  if (res != null) {
                    setState(() {
                      _languages = res.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    });
                  }
                },
                child: const Text('Editar idiomas'),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _nationalityCtrl, decoration: const InputDecoration(labelText: "Nacionalidad")),
              const SizedBox(height: 12),
              TextFormField(controller: _experienceCtrl, decoration: const InputDecoration(labelText: "Experiencia")),
              const SizedBox(height: 12),
              TextFormField(controller: _descriptionCtrl, decoration: const InputDecoration(labelText: "Descripción"), maxLines: 3),
              const SizedBox(height: 24),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white), onPressed: _saveProfile, child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Guardar cambios'))),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// AmbassadorApplicationScreen (versión final)
/// - existingData & existingDocId: si se pasan, actualizarán ese documento en lugar de crear otro
/// - showContactFields: controla si mostramos telefono/email/nacionalidad (por defecto false en creación)
/// ------------------------------------------------------------------
class AmbassadorApplicationScreen extends StatefulWidget {
  final Map<String, dynamic>? existingData;
  final String? existingDocId;
  final bool showContactFields;
  const AmbassadorApplicationScreen({super.key, this.existingData, this.existingDocId, this.showContactFields = false});

  @override
  State<AmbassadorApplicationScreen> createState() => _AmbassadorApplicationScreenState();
}

class _AmbassadorApplicationScreenState extends State<AmbassadorApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _photoUrlCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController(); // text input: "Español, Inglés"
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();

  String _availability = "Available";
  bool _loading = false;

  bool get isEditing => widget.existingData != null;

  @override
  void initState() {
    super.initState();
    final u = _auth.currentUser;
    if (u != null) _emailCtrl.text = u.email ?? '';

    final e = widget.existingData;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _descriptionCtrl.text = e['description'] ?? '';
      _experienceCtrl.text = e['experience'] ?? '';
      _priceCtrl.text = e['pricePerHour']?.toString().replaceAll('USD', '').trim() ?? '';
      _photoUrlCtrl.text = e['photoUrl'] ?? '';
      _phoneCtrl.text = e['phone'] ?? '';
      _emailCtrl.text = e['userEmail'] ?? e['email'] ?? _emailCtrl.text;
      _nationalityCtrl.text = e['nationality'] ?? '';
      _languagesCtrl.text = (e['languages'] is List) ? (e['languages'] as List).join(', ') : (e['languages']?.toString() ?? '');
      _availability = e['availability'] ?? 'Available';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _experienceCtrl.dispose();
    _priceCtrl.dispose();
    _photoUrlCtrl.dispose();
    _languagesCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _nationalityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("Usuario no autenticado.");

      // languages: parse comma-separated text into List<String>
      final languagesList = _languagesCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final data = <String, dynamic>{
        'idAmbassador': widget.existingData?['idAmbassador'] ?? "AMB${DateTime.now().millisecondsSinceEpoch}",
        'name': _nameCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'experience': _experienceCtrl.text.trim(),
        'languages': languagesList,
        'availability': _availability,
        'pricePerHour': _priceCtrl.text.trim().isNotEmpty ? "${_priceCtrl.text.trim()} USD" : null,
        'photoUrl': _photoUrlCtrl.text.trim().isNotEmpty ? _photoUrlCtrl.text.trim() : null,
        'verified': false,
        'applicationStatus': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null || (v is String && v.isEmpty));

      // Only include contact fields if showContactFields==true (user requested to add contact)
      if (widget.showContactFields) {
        if (_phoneCtrl.text.trim().isNotEmpty) data['phone'] = _phoneCtrl.text.trim();
        if (_emailCtrl.text.trim().isNotEmpty) data['userEmail'] = _emailCtrl.text.trim();
        if (_nationalityCtrl.text.trim().isNotEmpty) data['nationality'] = _nationalityCtrl.text.trim();
      } else if (widget.existingDocId == null) {
        // Only add userId and userEmail when creating a NEW document (not when editing)
        data['userId'] = user.uid;
        data['userEmail'] = user.email;
      }

      final ref = _fire.collection('ambassadors');
      if (widget.existingDocId != null) {
        // update existing doc (merge)
        await ref.doc(widget.existingDocId).set(data, SetOptions(merge: true));
      } else {
        // create new doc
        await ref.add(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud enviada. Espera la aprobación del administrador.')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error enviando solicitud: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud de Embajador'),
        backgroundColor: primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: "Nombre completo"),
                      validator: (v) => v == null || v.isEmpty ? 'Campo obligatorio' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(controller: _descriptionCtrl, decoration: const InputDecoration(labelText: "Descripción")),
                    const SizedBox(height: 8),
                    TextFormField(controller: _experienceCtrl, decoration: const InputDecoration(labelText: "Experiencia (años o texto)")),
                    const SizedBox(height: 8),
                    TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: "Precio por hora en usd (número)"), keyboardType: TextInputType.number),
                    const SizedBox(height: 8),
                    TextFormField(controller: _photoUrlCtrl, decoration: const InputDecoration(labelText: "URL de foto (enlace de imagen)")),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _languagesCtrl,
                      decoration: const InputDecoration(
                        labelText: "Idiomas (separados por comas)",
                        hintText: "Ejemplo: Español, Inglés, Francés",
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _availability,
                      decoration: const InputDecoration(labelText: "Disponibilidad"),
                      items: const [
                        DropdownMenuItem(value: "Available", child: Text("Disponible")),
                        DropdownMenuItem(value: "Busy", child: Text("Ocupado")),
                      ],
                      onChanged: (v) => setState(() => _availability = v!),
                    ),
                    const SizedBox(height: 16),

                    // Contact fields: only shown when showContactFields == true (user asked to add)
                    if (widget.showContactFields) ...[
                      TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: "Teléfono")),
                      const SizedBox(height: 8),
                      TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Correo electrónico")),
                      const SizedBox(height: 8),
                      TextFormField(controller: _nationalityCtrl, decoration: const InputDecoration(labelText: "Nacionalidad")),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                      onPressed: _submitApplication,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Enviar solicitud'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
