import 'dart:math'as math;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ---------------------------------------------------------
//  Services Screen — with category “Passadis” instead of “Transport”
// ---------------------------------------------------------
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String selectedCategory = "All";
  String searchQuery = "";

  final List<String> categories = [
    "All",
    "Hotels",
    "Restaurants",
    "Tours",
    "Passadis"
  ];

  // Mapa display -> valor esperado en los documentos (todo en lowerCase)
  final Map<String, String> _categoryKey = {
    'All': '',
    'Hotels': 'hotels',
    'Restaurants': 'restaurants',
    'Tours': 'tours',
    'Passadis': 'passadis', // <- la clave que pediste
  };

  final FirebaseFirestore _fire = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    final accent = const Color(0xFF6CCCE4);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: const Text(
          "Search Services",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              items: categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (v) => setState(() => selectedCategory = v ?? 'All'),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                hintText: "Search by name or location...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _fire.collection('services').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Excluir explícitamente servicios inactive (active == false)
                  final rawDocs = snapshot.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    // por defecto si 'active' no existe lo consideramos activo
                    return !(data['active'] == false);
                  }).toList();

                  return FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: _processAndSortServices(rawDocs),
                    builder: (context, futureSnap) {
                      if (futureSnap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (futureSnap.hasError) {
                        return Center(child: Text('Processing error: ${futureSnap.error}'));
                      }

                      final services = (futureSnap.data ?? []).where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final name = (data['name'] ?? '').toString().toLowerCase();
                        final typeRaw = (data['type'] ?? data['category'] ?? '').toString().toLowerCase();
                        final location = (data['locationName'] ?? data['place'] ?? '').toString().toLowerCase();

                        // Category filter: usa el mapeo display->key
                        final wantedCategoryKey = _categoryKey[selectedCategory] ?? '';
                        final matchCategory = wantedCategoryKey.isEmpty ||
                        typeRaw == wantedCategoryKey ||
                        typeRaw.contains(wantedCategoryKey);

                        final q = searchQuery.toLowerCase().trim();
                        final matchSearch = q.isEmpty || name.contains(q) || location.contains(q);

                        // adicional: asegurar active=true (por si alguna doc pasó)
                        final isActive = !(data['active'] == false);

                        return matchCategory && matchSearch && isActive;
                      }).toList();

                      if (services.isEmpty) {
                        return const Center(child: Text('No services found.'));
                      }

                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: services.length,
                        itemBuilder: (context, index) {
                          final data = services[index].data() as Map<String, dynamic>;
                          return _buildServiceCard(context, data, primary, accent);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _processAndSortServices(
      List<QueryDocumentSnapshot> docs) async {
    final Map<String, Map<String, dynamic>> providerCache = {};
    final Set<String> providerIdsToFetch = {};

    for (var d in docs) {
      final data = d.data() as Map<String, dynamic>;
      final providerId = (data['providerId'] ?? data['providerid'] ?? data['provider'] ?? '').toString();
      if (providerId.isNotEmpty) providerIdsToFetch.add(providerId);
    }

    final List<String> allProviderIds = providerIdsToFetch.toList();
    const int chunk = 10;
    for (int i = 0; i < allProviderIds.length; i += chunk) {
      final end = math.min(i + chunk, allProviderIds.length);
      final sub = allProviderIds.sublist(i, end);
      try {
        final snap = await _fire
            .collection('providers')
            .where(FieldPath.documentId, whereIn: sub)
            .get();
        for (var pdoc in snap.docs) {
          providerCache[pdoc.id] = pdoc.data() as Map<String, dynamic>;
        }
      } catch (_) {
        // ignore provider fetch errors silently
      }
    }

    final List<_ServiceWithFlags> list = [];
    for (var d in docs) {
      final data = d.data() as Map<String, dynamic>;
      bool isPremium = false;

      final svcCategory = (data['category'] ?? data['providerCategory'] ?? data['provider_category'] ?? '').toString().toLowerCase();
      if (svcCategory == 'premium') isPremium = true;

      final providerId = (data['providerId'] ?? data['providerid'] ?? '').toString();
      if (!isPremium && providerId.isNotEmpty) {
        final p = providerCache[providerId];
        if (p != null) {
          final pcat = (p['category'] ?? p['providerCategory'] ?? '').toString().toLowerCase();
          if (pcat == 'premium') isPremium = true;
        }
      }

      bool isVerified = false;
      final ver = data['verified'] ?? data['isVerified'] ?? data['providerVerified'];
      if (ver is bool) isVerified = ver;
      else if (ver is String) isVerified = ver.toLowerCase() == 'true';

      list.add(_ServiceWithFlags(doc: d, isPremium: isPremium, isVerified: isVerified));
    }

    // sort: premium first, then verified
    list.sort((a, b) {
      if (a.isPremium != b.isPremium) return a.isPremium ? -1 : 1;
      if (a.isVerified != b.isVerified) return a.isVerified ? -1 : 1;
      return 0;
    });

    return list.map((e) => e.doc).toList();
  }

  Widget _buildServiceCard(
      BuildContext context, Map<String, dynamic> data, Color primary, Color accent) {
    final String name = (data['name'] ?? 'Unknown').toString();
    final String imageUrl =
        (data['imageUrl'] ?? data['photo'] ?? '').toString().isNotEmpty
            ? (data['imageUrl'] ?? data['photo']).toString()
            : 'https://cdn-icons-png.flaticon.com/512/854/854878.png';

    // safe rating parse
    double rating = 4.5;
    final r = data['rating'];
    if (r is num) rating = r.toDouble();
    else if (r is String) rating = double.tryParse(r) ?? 4.5;

    final bool verified = (data['verified'] ?? false) is bool ? (data['verified'] ?? false) as bool : (data['verified']?.toString().toLowerCase() == 'true');

    return GestureDetector(
      onTap: () {
        // navegar a detalle de servicio
        Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceData: data)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Image.network(
                imageUrl,
                height: 110,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 110,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF004A50),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                    if (verified)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Verified', style: TextStyle(color: Colors.green, fontSize: 12)),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(rating.toStringAsFixed(1),
                            style: const TextStyle(color: Color(0xFF004A50))),
                      ]),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceWithFlags {
  final QueryDocumentSnapshot doc;
  final bool isPremium;
  final bool isVerified;
  _ServiceWithFlags(
      {required this.doc, required this.isPremium, required this.isVerified});
}
// -----------------------------------------------------------------
// ServiceDetailScreen (muestra info y botón Book + Write Review)
// -----------------------------------------------------------------
class ServiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> serviceData;
  const ServiceDetailScreen({super.key, required this.serviceData});

  String _formatDate(dynamic fecha) {
    try {
      if (fecha == null) return "Unknown date";
      if (fecha is Timestamp) return DateFormat('yyyy-MM-dd').format(fecha.toDate());
      if (fecha is DateTime) return DateFormat('yyyy-MM-dd').format(fecha);
      if (fecha is String) return fecha;
      return fecha.toString();
    } catch (e) {
      return "Invalid date";
    }
  }

  String _getServiceIdCandidate() {
    final id = serviceData['servicioid'] ?? serviceData['serviceId'] ?? '';
    if (id != null && id.toString().trim().isNotEmpty) return id.toString();
    return (serviceData['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF007274);
    final serviceName = serviceData['name'] ?? '';
    final serviceIdCandidate = _getServiceIdCandidate();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: Text(
          serviceName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Image.network(
            serviceData['imageUrl'] ?? 'https://cdn-icons-png.flaticon.com/512/854/854878.png',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          const SizedBox(height: 16),
          Text(serviceName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Type: ${serviceData['type'] ?? ''}"),
          Text("Location: ${serviceData['locationName'] ?? ''}"),
          const SizedBox(height: 10),
          Text(serviceData['description'] ?? ''),
          const SizedBox(height: 10),
          Text("Hours: ${serviceData['service_hours'] ?? 'Not specified'}"),
          const Divider(height: 30),

          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReservationScreen(serviceData: serviceData)),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                  icon: const Icon(Icons.calendar_today),
                  label: const Text("Book"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddReviewScreen(serviceData: serviceData)),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  icon: const Icon(Icons.rate_review),
                  label: const Text("Write Review"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text("Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // StreamBuilder para cargar reseñas relacionadas con este servicio
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('resenas').snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Error loading reviews: ${snap.error}');
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;

                final candidates = <dynamic>[
                  data['idservicio'],
                  data['idServicio'],
                  data['servicioid'],
                  data['servicioId'],
                  data['serviceId'],
                  data['serviceName'],
                ];

                for (var c in candidates) {
                  if (c == null) continue;
                  if (c.toString() == serviceIdCandidate) return true;
                  if (serviceIdCandidate.toLowerCase() == c.toString().toLowerCase()) return true;
                }
                return false;
              }).toList();

              filtered.sort((a, b) {
                final A = (a.data() as Map<String, dynamic>)['fecha'];
                final B = (b.data() as Map<String, dynamic>)['fecha'];

                DateTime? da;
                DateTime? db;

                if (A is Timestamp) da = A.toDate();
                else if (A is DateTime) da = A;
                else if (A is String) da = DateTime.tryParse(A);

                if (B is Timestamp) db = B.toDate();
                else if (B is DateTime) db = B;
                else if (B is String) db = DateTime.tryParse(B);

                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No reviews yet.'),
                );
              }

              return Column(
                children: filtered.map((doc) {
                  final r = doc.data() as Map<String, dynamic>;
                  final comment = r['comentario'] ?? r['comment'] ?? '';
                  final rating = r['calificacion'] ?? r['rating'] ?? '-';
                  final fecha = r['fecha'];
                  final fechaText = (fecha is Timestamp) ? DateFormat('yyyy-MM-dd').format(fecha.toDate()) : (fecha?.toString() ?? '');

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Color(0xFF007274)),
                      title: Text(comment.toString()),
                      subtitle: Text("⭐ $rating - $fechaText"),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }
} 
// -----------------------------------------------------------------
// ReservationScreen con opciones de pago y simulación
// -----------------------------------------------------------------
class ReservationScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;
  const ReservationScreen({super.key, required this.serviceData});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final nombreController = TextEditingController();
  final personasController = TextEditingController();
  final roomsController = TextEditingController();
  final nightsController = TextEditingController();
  DateTime? fechaReserva;
  TimeOfDay? horaReserva;
  bool _saving = false;

  // Opciones de pago y estado local
  String? _tourPaymentChoice; // 'in_place' | 'in_app' (solo para Tours)
  String? _passadisPaymentChoice; // 'card' | 'cash' | 'transfer' (solo para Passadis)
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();

  @override
  void dispose() {
    nombreController.dispose();
    personasController.dispose();
    roomsController.dispose();
    nightsController.dispose();
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fechaReserva ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => fechaReserva = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final t = await showTimePicker(context: context, initialTime: horaReserva ?? TimeOfDay(hour: 9, minute: 0));
    if (t != null) setState(() => horaReserva = t);
  }

  String getServiceId() {
    final map = widget.serviceData;
    return (map['servicioid'] ?? map['serviceId'] ?? map['name'] ?? '').toString();
  }

  String _serviceTypeNormalized() {
    final t = (widget.serviceData['type'] ?? '').toString().toLowerCase();
    return t;
  }

  bool _isHotel(String s) {
    final lower = s.toLowerCase();
    return lower.contains('hotel');
  }

  bool _isPassadis(String s) {
    final lower = s.toLowerCase();
    return lower.contains('passad') || lower.contains('transport');
  }

  // Simula un pago con tarjeta (retorna mapa con resultado)
  Future<Map<String, dynamic>> _simulateCardPayment({required String cardNumber, required String expiry, required String cvv, required double amount}) async {
    if (cardNumber.length < 12) return {'success': false, 'message': 'Invalid card number'};
    await Future.delayed(const Duration(seconds: 2));
    final success = Random().nextInt(100) < 85;
    final reference = 'PAY-${DateTime.now().millisecondsSinceEpoch}';
    return {'success': success, 'reference': reference, 'message': success ? 'Payment approved' : 'Payment declined by issuer'};
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat('HH:mm').format(dt);
  }

  Future<void> _createReservation() async {
    // Basic validations
    if (nombreController.text.isEmpty || personasController.text.isEmpty || fechaReserva == null || horaReserva == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields (including time) before confirming.")));
      return;
    }

    final serviceType = _serviceTypeNormalized();
    final isHotel = _isHotel(serviceType);
    final isPassadis = _isPassadis(serviceType);

    // If hotel, validate rooms & nights
    int? numRooms;
    int? nights;
    if (isHotel) {
      if (roomsController.text.trim().isEmpty || nightsController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter number of rooms and nights for hotel reservations.")));
        return;
      }
      numRooms = int.tryParse(roomsController.text.trim());
      nights = int.tryParse(nightsController.text.trim());
      if (numRooms == null || numRooms <= 0 || nights == null || nights <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rooms and nights must be valid positive numbers.")));
        return;
      }
    }

    // Payment-related validations
    if (serviceType.contains('tour')) {
      if (_tourPaymentChoice == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select whether you'll pay in place or through the app.")));
        return;
      }
      if (_tourPaymentChoice == 'in_app') {
        final paid = await _handleCardFlowIfNeeded(amount: 0.0);
        if (!paid) return;
      }
    } else if (isPassadis) {
      if (_passadisPaymentChoice == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select payment method for Passadis.")));
        return;
      }
      if (_passadisPaymentChoice == 'card') {
        final paid = await _handleCardFlowIfNeeded(amount: 0.0);
        if (!paid) return;
      }
    }

    setState(() => _saving = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userEmail = firebaseUser?.email ?? '';

      // 1) Buscar documento 'users' por email (obtener document id) — fallback a uid
      String userDocId = '';
      if (userEmail.isNotEmpty) {
        try {
          final q = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
          if (q.docs.isNotEmpty) userDocId = q.docs.first.id;
          else userDocId = firebaseUser?.uid ?? '';
        } catch (e) {
          debugPrint('Error searching user doc: $e');
          userDocId = firebaseUser?.uid ?? '';
        }
      } else {
        userDocId = firebaseUser?.uid ?? '';
      }

      // Payment fields
      String paymentMethod = 'pending';
      String paymentStatus = 'pending';
      String paymentReference = '';

      if (serviceType.contains('tour')) {
        if (_tourPaymentChoice == 'in_place') {
          paymentMethod = 'Pay in place';
          paymentStatus = 'pending';
        } else if (_tourPaymentChoice == 'in_app') {
          paymentMethod = 'In-app (card)';
          paymentStatus = 'paid';
          paymentReference = _lastPaymentReference ?? '';
        }
      } else if (isPassadis) {
        if (_passadisPaymentChoice == 'cash') {
          paymentMethod = 'Cash';
          paymentStatus = 'pending';
        } else if (_passadisPaymentChoice == 'transfer') {
          paymentMethod = 'Transfer';
          paymentStatus = 'pending';
        } else if (_passadisPaymentChoice == 'card') {
          paymentMethod = 'Card';
          paymentStatus = 'paid';
          paymentReference = _lastPaymentReference ?? '';
        }
      } else {
        paymentMethod = 'Pay in place';
        paymentStatus = 'pending';
      }

      final serviceId = getServiceId();
      final fechaTimestamp = Timestamp.fromDate(fechaReserva!);
      final horaTexto = _formatTimeOfDay(horaReserva!);

      final reserva = {
        "idservicio": serviceId,
        "serviceName": widget.serviceData['name'] ?? '',
        "nombreReserva": nombreController.text.trim(),
        "numPersonas": int.tryParse(personasController.text) ?? 1,
        "fechaReserva": fechaTimestamp,
        "horaReserva": horaTexto,
        "estado": "pending", // stored in English for tourist view
        "userId": userDocId,
        "userEmail": userEmail,
        "createdAt": FieldValue.serverTimestamp(),
        "paymentMethod": paymentMethod,
        "paymentStatus": paymentStatus,
        "paymentReference": paymentReference,
      };

      // include hotel fields if applicable
      if (isHotel) {
        reserva['numRooms'] = numRooms;
        reserva['nights'] = nights;
      }

      // Guardar reserva
      final reservaRef = await FirebaseFirestore.instance.collection('reservas').add(reserva);
      final reservaId = reservaRef.id;

      // NOTIFICAR al proveedor: intentar resolver providerDocId y providerEmail desde serviceData
      String providerDocId = '';
      String providerEmail = '';

      final s = widget.serviceData;
      if (s['providerId'] != null) providerDocId = s['providerId'].toString();
      if (providerDocId.isEmpty && s['providerid'] != null) providerDocId = s['providerid'].toString();
      if (s['providerEmail'] != null) providerEmail = s['providerEmail'].toString();
      if (providerEmail.isEmpty && s['provideremail'] != null) providerEmail = s['provideremail'].toString();

      if (providerDocId.isEmpty && providerEmail.isNotEmpty) {
        try {
          final qprov = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: providerEmail).limit(1).get();
          if (qprov.docs.isNotEmpty) providerDocId = qprov.docs.first.id;
        } catch (e) {
          debugPrint('Error searching provider doc by email: $e');
        }
      }

      // 3) construir título y cuerpo del mensaje (EN ESPAÑOL para el proveedor)
      final fechaStr = DateFormat('yyyy-MM-dd').format(fechaReserva!);
      final title = 'Nueva reserva';
      String body = 'Se ha creado una nueva reserva para "${reserva['serviceName']}"\n'
          'Nombre: ${reserva['nombreReserva']}\n'
          'Fecha: $fechaStr\n'
          'Hora: $horaTexto\n'
          'Personas: ${reserva['numPersonas']}';

      // si es hotel, agregar habitaciones y noches al cuerpo del mensaje (solo para proveedor)
      if (isHotel) {
        body += '\nHabitaciones: ${reserva['numRooms']}\nNoches: ${reserva['nights']}';
      }

      // 4) crear mensaje en 'messages' para el proveedor (si encontramos recipient)
      final messageData = {
        'senderId': userDocId,
        'senderEmail': userEmail,
        'recipientId': providerDocId,
        'recipientEmail': providerEmail,
        'title': title,
        'text': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'reservation',
        'reservationId': reservaId,
        // include structured fields to make it easier for provider actions
        'fechaReserva': fechaTimestamp,
        'horaReserva': horaTexto,
      };

      if (isHotel) {
        messageData['numRooms'] = reserva['numRooms'];
        messageData['nights'] = reserva['nights'];
      }

      await FirebaseFirestore.instance.collection('messages').add(messageData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reservation created successfully!")));
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error creating reservation: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating reservation: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _lastPaymentReference; // para almacenar referencia de pago simulado

  Future<bool> _handleCardFlowIfNeeded({required double amount}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Pay with card (simulation)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _cardNumberCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Card number')),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: _cardExpiryCtrl, decoration: const InputDecoration(labelText: 'MM/YY'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _cardCvvCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'CVV'))),
            ]),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                if (_cardNumberCtrl.text.trim().length < 12) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid card number')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Process payment (simulation)'),
            ),
            const SizedBox(height: 12),
          ]),
        );
      },
    );

    if (result != true) return false;

    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(content: Text('Processing payment...')));

    final payResult = await _simulateCardPayment(
      cardNumber: _cardNumberCtrl.text.trim(),
      expiry: _cardExpiryCtrl.text.trim(),
      cvv: _cardCvvCtrl.text.trim(),
      amount: amount,
    );

    if (payResult['success'] == true) {
      _lastPaymentReference = payResult['reference'] ?? '';
      snack.showSnackBar(SnackBar(content: Text('Payment success — ref: ${_lastPaymentReference!}')));
      return true;
    } else {
      snack.showSnackBar(SnackBar(content: Text('Payment failed: ${payResult['message'] ?? ''}')));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    final serviceName = widget.serviceData['name'] ?? 'Service';
    final serviceType = _serviceTypeNormalized();
    final isHotel = _isHotel(serviceType);
    final isPassadis = _isPassadis(serviceType);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Reserve service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Service: $serviceName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007274))),
          const SizedBox(height: 20),
          TextField(controller: nombreController, decoration: const InputDecoration(labelText: "Reservation name", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          TextField(controller: personasController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Number of people", border: OutlineInputBorder())),
          const SizedBox(height: 15),

          // If hotel, show rooms & nights
          if (isHotel) ...[
            TextField(controller: roomsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Number of rooms", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nightsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Number of nights", border: OutlineInputBorder())),
            const SizedBox(height: 15),
          ],

          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Reservation date", border: OutlineInputBorder()),
                  child: Text(fechaReserva != null ? DateFormat('yyyy-MM-dd').format(fechaReserva!) : "Select a date"),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => _selectTime(context),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Reservation time", border: OutlineInputBorder()),
                  child: Text(horaReserva != null ? _formatTimeOfDay(horaReserva!) : "Select a time"),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Opciones específicas por tipo
          if (serviceType.contains('tour')) ...[
            const Text('Tour payment', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Pay in place'),
              value: 'in_place',
              groupValue: _tourPaymentChoice,
              onChanged: (v) => setState(() => _tourPaymentChoice = v),
            ),
            RadioListTile<String>(
              title: const Text('Pay via app (card)'),
              value: 'in_app',
              groupValue: _tourPaymentChoice,
              onChanged: (v) => setState(() => _tourPaymentChoice = v),
            ),
          ] else if (isPassadis) ...[
            const Text('Passadis payment method', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Card'),
              value: 'card',
              groupValue: _passadisPaymentChoice,
              onChanged: (v) => setState(() => _passadisPaymentChoice = v),
            ),
            RadioListTile<String>(
              title: const Text('Cash'),
              value: 'cash',
              groupValue: _passadisPaymentChoice,
              onChanged: (v) => setState(() => _passadisPaymentChoice = v),
            ),
            RadioListTile<String>(
              title: const Text('Transfer'),
              value: 'transfer',
              groupValue: _passadisPaymentChoice,
              onChanged: (v) => setState(() => _passadisPaymentChoice = v),
            ),
          ] else ...[
            const Text('Payment is usually made in place unless provider indicates otherwise.'),
          ],

          const Spacer(),

          _saving
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _createReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Confirm reservation", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
        ]),
      ),
    );
  }
}

// -----------------------------------------------------------------
// AddReviewScreen
// -----------------------------------------------------------------
class AddReviewScreen extends StatefulWidget {
  final Map<String, dynamic> serviceData;
  const AddReviewScreen({super.key, required this.serviceData});

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  final comentarioController = TextEditingController();
  double calificacion = 3;
  bool _loading = false;

  String getServiceId() {
    final map = widget.serviceData;
    return (map['servicioid'] ?? map['name'] ?? '').toString();
  }

  Future<void> _guardarResena() async {
    final serviceId = getServiceId();
    final comentario = comentarioController.text.trim();

    if (comentario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please write a comment before submitting.")));
      return;
    }

    setState(() => _loading = true);

    final resenasRef = FirebaseFirestore.instance.collection('resenas');
    final servicesRef = FirebaseFirestore.instance.collection('services');

    try {
      await resenasRef.add({
        "idservicio": serviceId,
        "comentario": comentario,
        "calificacion": calificacion.toInt(),
        "fecha": FieldValue.serverTimestamp(),
        "estado": "pendiente",
      });

      final snapshot = await resenasRef.where('idservicio', isEqualTo: serviceId).get();
      if (snapshot.docs.isNotEmpty) {
        double suma = 0;
        for (var d in snapshot.docs) {
          final dat = d.data();
          final val = dat['calificacion'];
          if (val is int) suma += val.toDouble();
          else if (val is double) suma += val;
          else if (val is String) suma += double.tryParse(val) ?? 0;
        }
        final promedio = suma / snapshot.docs.length;

        final serviciosSnapshot = await servicesRef.where('servicioid', isEqualTo: serviceId).get();
        if (serviciosSnapshot.docs.isNotEmpty) {
          for (var servicioDoc in serviciosSnapshot.docs) {
            await servicioDoc.reference.update({"rating": promedio});
          }
        } else {
          final byName = await servicesRef.where('name', isEqualTo: serviceId).get();
          for (var s in byName.docs) {
            await s.reference.update({"rating": promedio});
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review submitted and rating updated!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving review: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(backgroundColor: primary, title: const Text("Write Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: comentarioController, decoration: const InputDecoration(labelText: "Your comment", border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            const Text("Your rating:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(onPressed: () => setState(() => calificacion = i + 1), icon: Icon(Icons.star, color: i < calificacion ? Colors.amber : Colors.grey, size: 30)))),
            const Spacer(),
            ElevatedButton(onPressed: _loading ? null : _guardarResena, style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Send Review", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }
}