import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MembresiaScreen extends StatefulWidget {
  const MembresiaScreen({super.key});

  @override
  State<MembresiaScreen> createState() => _MembresiaScreenState();
}

class _MembresiaScreenState extends State<MembresiaScreen> {
  final _cardNumberCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCvvCtrl = TextEditingController();

  bool _processing = false;
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCvvCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _simulateCardPayment({
    required String cardNumber,
    required String expiry,
    required String cvv,
    required double amount,
  }) async {
    if (cardNumber.trim().length < 12) {
      return {'success': false, 'message': 'Número de tarjeta inválido'};
    }
    if (cvv.trim().length < 3) {
      return {'success': false, 'message': 'CVV inválido'};
    }

    await Future.delayed(const Duration(seconds: 2));

    final success = Random().nextInt(100) < 90;
    final reference = 'M-REF-${DateTime.now().millisecondsSinceEpoch}';
    return {
      'success': success,
      'reference': reference,
      'message': success ? 'Pago aprobado' : 'Pago rechazado por el emisor'
    };
  }

  Future<void> _handlePurchase() async {
    const membershipAmount = 9.99;

    setState(() => _processing = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      String userDocId = '';
      final userEmail = user.email ?? '';
      if (userEmail.isNotEmpty) {
        final q = await _fire.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
        if (q.docs.isNotEmpty) {
          userDocId = q.docs.first.id;
        }
      }

      if (_cardNumberCtrl.text.trim().isEmpty ||
          _cardExpiryCtrl.text.trim().isEmpty ||
          _cardCvvCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor completa los datos de la tarjeta.')));
        setState(() => _processing = false);
        return;
      }

      final result = await _simulateCardPayment(
        cardNumber: _cardNumberCtrl.text.trim(),
        expiry: _cardExpiryCtrl.text.trim(),
        cvv: _cardCvvCtrl.text.trim(),
        amount: membershipAmount,
      );

      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pago fallido: ${result['message'] ?? ''}')));
        setState(() => _processing = false);
        return;
      }

      final batch = _fire.batch();
      final membRef = _fire.collection('membresias').doc();
      batch.set(membRef, {
        'membershipId': membRef.id,
        'userUid': user.uid,
        'userEmail': userEmail,
        'amount': membershipAmount,
        'method': 'tarjeta',
        'reference': result['reference'],
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'paid',
      });

      if (userDocId.isNotEmpty) {
        final providerDocRef = _fire.collection('providers').doc(userDocId);
        batch.set(providerDocRef, {'category': 'premium', 'premiumSince': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } else {
        final provQ = await _fire.collection('providers').where('email', isEqualTo: userEmail).limit(1).get();
        if (provQ.docs.isNotEmpty) {
          final providerDocRef = provQ.docs.first.reference;
          batch.set(providerDocRef, {'category': 'premium', 'premiumSince': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }

      if (userDocId.isNotEmpty) {
        final userRef = _fire.collection('users').doc(userDocId);
        batch.set(userRef, {'category': 'premium', 'premiumSince': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } else {
        final uQ = await _fire.collection('users').where('email', isEqualTo: userEmail).limit(1).get();
        if (uQ.docs.isNotEmpty) {
          batch.set(uQ.docs.first.reference, {'category': 'premium', 'premiumSince': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pago exitoso — ref: ${result['reference']}. ¡Ahora eres premium!')),
      );

      _cardNumberCtrl.clear();
      _cardExpiryCtrl.clear();
      _cardCvvCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error procesando membresía: $e')));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    const usdPrice = 10.0;
    final copPrice = (usdPrice * 4000).toStringAsFixed(0); // tasa aprox. COP

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membresía Premium'),
        backgroundColor: primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Cuadro de precio y beneficios
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primary.withOpacity(0.5), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💎 Membresía Premium',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Precio: USD $usdPrice  ≈  COP $copPrice',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Beneficios:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.teal),
                      SizedBox(width: 6),
                      Expanded(child: Text('Mayor visibilidad de tus servicios en el mapa y listados.')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      SizedBox(width: 6),
                      Expanded(child: Text('Recomendaciones destacadas para turistas en la aplicación.')),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.green),
                      SizedBox(width: 6),
                      Expanded(child: Text('Mayor probabilidad de aparecer en búsquedas relevantes.')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'El único método disponible es tarjeta. Ingresa los datos para procesar el pago y obtener la categoría "premium".',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Campos de tarjeta
            TextFormField(
              controller: _cardNumberCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Número de tarjeta', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cardExpiryCtrl,
                    decoration: const InputDecoration(labelText: 'MM/AA', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cardCvvCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),

            const Spacer(),

            _processing
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Pagar Membresía (Tarjeta)', style: TextStyle(fontSize: 16)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}