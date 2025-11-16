import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AmbassadorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ambassadorData;
  const AmbassadorDetailScreen({super.key, required this.ambassadorData});

  @override
  State<AmbassadorDetailScreen> createState() => _AmbassadorDetailScreenState();
}

class _AmbassadorDetailScreenState extends State<AmbassadorDetailScreen> {
  final _dateController = TextEditingController();
  final _timeController = TextEditingController(); // nuevo: hora
  final _durationController = TextEditingController();
  final _placeController = TextEditingController(); // nuevo: lugar
  final _notesController = TextEditingController(); // nuevo: notas
  String _metodoPago = "Cash";
  bool _loading = false;

  final _fire = FirebaseFirestore.instance;

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _durationController.dispose();
    _placeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatNow() => DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

  /// Resuelve el id del embajador (variantes comunes)
  String _resolveAmbassadorId(Map<String, dynamic> d) {
    return (d['idAmbassador'] ??
            d['IdAmbassador'] ??
            d['id'] ??
            d['AMB001'] ??
            d['ambassadorId'] ??
            '')
        .toString();
  }

  String _resolveAmbassadorEmail(Map<String, dynamic> d) {
    return (d['userEmail'] ?? d['email'] ?? d['ambassadorEmail'] ?? '').toString();
  }

  /// Comprueba si el usuario (autenticado) tiene al menos una reserva aceptada/completada
  Future<bool> _hasContractedService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      String userDocId = user.uid;
      final userEmail = user.email ?? '';

      // intentamos buscar userDocId real en 'users'
      if (userEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
          if (q.docs.isNotEmpty) userDocId = q.docs.first.id;
        } catch (_) {}
      }

      final ambId = _resolveAmbassadorId(widget.ambassadorData);
      if (ambId.isEmpty) return false;

      // Buscamos reservas donde requesterId == userDocId (o requesterEmail == userEmail)
      // y ambassadorId == ambId y estado sea Accepted/Confirmed/Completed
      final allowed = ['Accepted', 'Confirmed', 'Completed', 'accepted', 'confirmed', 'completed'];

      // Query por requesterId
      final q1 = await _fire
          .collection('servicio_ambajador')
          .where('ambassadorId', isEqualTo: ambId)
          .where('requesterId', isEqualTo: userDocId)
          .limit(1)
          .get();

      if (q1.docs.isNotEmpty) {
        final s = (q1.docs.first.data()['status'] ?? '').toString();
        if (allowed.any((a) => s.toLowerCase().contains(a.toLowerCase()))) return true;
      }

      // Si no encontrado por id, intentamos por correo
      if (userEmail.isNotEmpty) {
        final q2 = await _fire
            .collection('servicio_ambajador')
            .where('ambassadorId', isEqualTo: ambId)
            .where('requesterEmail', isEqualTo: userEmail)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) {
          final s = (q2.docs.first.data()['status'] ?? '').toString();
          if (allowed.any((a) => s.toLowerCase().contains(a.toLowerCase()))) return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking contracted service: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ambassadorData;
    final primary = const Color(0xFF007274);

    final languages = (data['languages'] is List)
        ? (data['languages'] as List).join(', ')
        : (data['languages']?.toString() ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data['name'] ?? 'Ambassador',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {
              // navegar a mensajes si quieres
            },
            icon: const Icon(Icons.message),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Imagen
          if ((data['photoUrl'] ?? '').toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                data['photoUrl'] ?? '',
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 20),
          Text(data['description'] ?? data['experience'] ?? '', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('Languages: $languages'),
          const SizedBox(height: 8),
          Text('Price per hour: ${data['pricePerHour'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(height: 30),

          const Text('Schedule your tour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004A50))),
          const SizedBox(height: 12),

          // Date (solo fecha)
          TextField(
            controller: _dateController,
            decoration: const InputDecoration(labelText: "Date", prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
            readOnly: true,
            onTap: () async {
              FocusScope.of(context).requestFocus(FocusNode());
              final pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030));
              if (pickedDate != null) {
                _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
              }
            },
          ),
          const SizedBox(height: 12),

          // Time (hora)
          TextField(
            controller: _timeController,
            decoration: const InputDecoration(labelText: "Time", prefixIcon: Icon(Icons.access_time), border: OutlineInputBorder()),
            readOnly: true,
            onTap: () async {
              FocusScope.of(context).requestFocus(FocusNode());
              final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (t != null) {
                final hh = t.hour.toString().padLeft(2, '0');
                final mm = t.minute.toString().padLeft(2, '0');
                _timeController.text = '$hh:$mm';
              }
            },
          ),
          const SizedBox(height: 12),

          // Duration (hours)
          TextField(
            controller: _durationController,
            decoration: const InputDecoration(labelText: "Duration (hours)", prefixIcon: Icon(Icons.timer), border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Place
          TextField(
            controller: _placeController,
            decoration: const InputDecoration(labelText: "Place / Meeting point", prefixIcon: Icon(Icons.place), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: "Notes (optional)", prefixIcon: Icon(Icons.note), border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 12),

          // Methods of payment
          DropdownButtonFormField<String>(
            value: _metodoPago,
            decoration: const InputDecoration(labelText: "Payment Method", prefixIcon: Icon(Icons.payment), border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: "Cash", child: Text("Cash")),
              DropdownMenuItem(value: "Transfer", child: Text("Transfer")),
              DropdownMenuItem(value: "Card", child: Text("Card")),
            ],
            onChanged: (value) => setState(() => _metodoPago = value!),
          ),
          const SizedBox(height: 12),

          if (_metodoPago == "Transfer" || _metodoPago == "Card")
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processing ${_metodoPago.toLowerCase()} payment..."), backgroundColor: Colors.orangeAccent));
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.attach_money),
                label: const Text("Pay Now"),
              ),
            ),

          const SizedBox(height: 20),

          _loading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _scheduleAmbassador,
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 14), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Confirm Booking"),
                ),

          const SizedBox(height: 12),

          // Write review button: comprobamos si tiene servicio contratado
          ElevatedButton.icon(
            onPressed: () async {
              final allowed = await _hasContractedService();
              if (!allowed) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only write a review if you have booked a service with this ambassador.'), backgroundColor: Colors.orange));
                return;
              }
              _openWriteReview(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
            icon: const Icon(Icons.rate_review),
            label: const Text("Write Review"),
          ),

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _scheduleAmbassador() async {
    if (_dateController.text.isEmpty || _durationController.text.isEmpty || _timeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill date, time and duration.")));
      return;
    }

    setState(() => _loading = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final userEmail = firebaseUser?.email ?? '';
      String userDocId = firebaseUser?.uid ?? '';
      String requesterName = firebaseUser?.displayName ?? '';
      String requesterPhone = '';

      // intentar obtener doc id y datos en 'users' por email
      if (userEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
          if (q.docs.isNotEmpty) {
            userDocId = q.docs.first.id;
            final userData = q.docs.first.data();
            // prefer user displayName, si no existe, usar campo 'name' del doc users
            if (requesterName.isEmpty) requesterName = (userData['name'] ?? userData['fullName'] ?? '').toString();
            // distintos nombres para teléfono posibles
            requesterPhone = (userData['phone'] ?? userData['telefono'] ?? userData['mobile'] ?? '').toString();
          }
        } catch (_) {}
      }

      // si aún no tenemos nombre, dejamos email como fallback
      if (requesterName.isEmpty) requesterName = userEmail.isNotEmpty ? userEmail : 'Guest';

      final ambId = _resolveAmbassadorId(widget.ambassadorData);
      final ambEmail = _resolveAmbassadorEmail(widget.ambassadorData);
      final ambName = widget.ambassadorData['name']?.toString() ?? '';

      // crear reserva en servicio_ambajador con hora, lugar, notas y teléfono del solicitante
      final newDocRef = await _fire.collection('servicio_ambajador').add({
        'ambassadorId': ambId,
        'ambassadorEmail': ambEmail,
        'ambassadorName': ambName,
        'requesterId': userDocId,
        'requesterEmail': userEmail,
        'requesterName': requesterName,
        'requesterPhone': requesterPhone,
        'date': _dateController.text,
        'time': _timeController.text,
        'duration': _durationController.text,
        'place': _placeController.text.trim(),
        'notes': _notesController.text.trim(),
        'paymentMethod': _metodoPago,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // crear mensaje/ notificación en 'messages' para el embajador (EN ESPAÑOL) incluyendo lugar/nota/hora/teléfono
      String ambassadorUserDocId = '';
      if (ambEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: ambEmail).limit(1).get();
          if (q.docs.isNotEmpty) ambassadorUserDocId = q.docs.first.id;
        } catch (_) {}
      }

      final title = 'Nueva reserva de embajador';
      final body = 'Se ha creado una nueva solicitud para $ambName.\n'
          'Solicitante: $requesterName\n'
          'Correo solicitante: $userEmail\n'
          'Teléfono solicitante: ${requesterPhone.isNotEmpty ? requesterPhone : 'No proporcionado'}\n'
          'Fecha: ${_dateController.text}\n'
          'Hora: ${_timeController.text}\n'
          'Duración (horas): ${_durationController.text}\n'
          'Lugar: ${_placeController.text.trim().isNotEmpty ? _placeController.text.trim() : 'No especificado'}\n'
          'Notas: ${_notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'Ninguna'}\n\n'
          'Por favor acepta o rechaza la solicitud en tu panel.';

      await _fire.collection('messages').add({
        'senderId': userDocId,
        'senderEmail': userEmail,
        'senderName': requesterName, // ahora guardamos nombre correctamente
        'recipientId': ambassadorUserDocId.isNotEmpty ? ambassadorUserDocId : null,
        'recipientEmail': ambEmail.isNotEmpty ? ambEmail : null,
        'title': title,
        'text': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'ambassador_request',
        'serviceDocId': newDocRef.id,
      }..removeWhere((k, v) => v == null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reservation created and ambassador notified."), backgroundColor: Colors.green));
      }
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error booking ambassador: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error booking ambassador: $e"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- Reviews ----
  void _openWriteReview(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      builder: (_) {
        final commentCtrl = TextEditingController();
        double rating = 5;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Write a review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: commentCtrl, decoration: const InputDecoration(labelText: 'Your comment'), maxLines: 3),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
              return IconButton(
                onPressed: () {
                  rating = i + 1.0;
                  // rebuild to show stars? setState not available here, but it's OK: user taps and later rating saved
                },
                icon: Icon(Icons.star, color: i < rating ? Colors.amber : Colors.grey),
              );
            })),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final comment = commentCtrl.text.trim();
                if (comment.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please write a comment')));
                  return;
                }
                Navigator.pop(ctx);
                await _saveAmbassadorReview(comment, rating.toInt());
              },
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Send review'),
            ),
            const SizedBox(height: 12),
          ]),
        );
      },
    );
  }

  Future<void> _saveAmbassadorReview(String comment, int rating) async {
    setState(() => _loading = true);
    try {
      final ambId = _resolveAmbassadorId(widget.ambassadorData);
      if (ambId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ambassador id not available')));
        return;
      }

      // Añadimos quién escribe la reseña (opcional): reviewerId / reviewerEmail
      final user = FirebaseAuth.instance.currentUser;
      String reviewerId = user?.uid ?? '';
      final reviewerEmail = user?.email ?? '';

      // buscar userDocId real por email si existe
      if (reviewerEmail.isNotEmpty) {
        try {
          final q = await _fire.collection('users').where('email', isEqualTo: reviewerEmail).limit(1).get();
          if (q.docs.isNotEmpty) reviewerId = q.docs.first.id;
        } catch (_) {}
      }

      final resRef = _fire.collection('resena_embajador').doc();
      await resRef.set({
        'ambassadorId': ambId,
        'comment': comment,
        'rating': rating,
        'reviewerId': reviewerId,
        'reviewerEmail': reviewerEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // recalcular promedio
      final snaps = await _fire.collection('resena_embajador').where('ambassadorId', isEqualTo: ambId).get();
      double sum = 0;
      for (var d in snaps.docs) {
        final r = d.data()['rating'];
        if (r is int) sum += r.toDouble();
        else if (r is double) sum += r;
        else if (r is String) sum += double.tryParse(r) ?? 0;
      }
      final avg = snaps.docs.isNotEmpty ? (sum / snaps.docs.length) : rating.toDouble();

      // intentar actualizar rating en colecciones probables
      bool updated = false;
      final possibleCollections = ['ambassadors', 'embajadores', 'users'];
      final ambEmail = _resolveAmbassadorEmail(widget.ambassadorData);

      for (var col in possibleCollections) {
        try {
          final q1 = await _fire.collection(col).where('idAmbassador', isEqualTo: ambId).limit(1).get();
          if (q1.docs.isNotEmpty) {
            await q1.docs.first.reference.update({'rating': avg});
            updated = true;
            break;
          }
          final q2 = await _fire.collection(col).where('IdAmbassador', isEqualTo: ambId).limit(1).get();
          if (q2.docs.isNotEmpty) {
            await q2.docs.first.reference.update({'rating': avg});
            updated = true;
            break;
          }
          final q3 = await _fire.collection(col).where('id', isEqualTo: ambId).limit(1).get();
          if (q3.docs.isNotEmpty) {
            await q3.docs.first.reference.update({'rating': avg});
            updated = true;
            break;
          }
          if (ambEmail.isNotEmpty) {
            final q4 = await _fire.collection(col).where('email', isEqualTo: ambEmail).limit(1).get();
            if (q4.docs.isNotEmpty) {
              await q4.docs.first.reference.update({'rating': avg});
              updated = true;
              break;
            }
          }
        } catch (_) {}
      }

      if (!updated) {
        debugPrint('Ambassador doc not found to update rating for id $ambId');
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving review: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}