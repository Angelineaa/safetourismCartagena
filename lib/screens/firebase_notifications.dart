import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FirebaseNotifications {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _onMessageSub;

  Future<void> initNotifications(BuildContext context) async {
    // Permisos
    await _messaging.requestPermission();

    // Si ya había una suscripción previa, cancelarla para evitar duplicados
    await _onMessageSub?.cancel();

    // Escuchar mensajes en primer plano y guardar la suscripción para poder
    // cancelarla más tarde (por ejemplo, en dispose())
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${message.notification!.title}: ${message.notification!.body}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF007274),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  /// Cancela la suscripción a `onMessage`. Llamar desde el `dispose()` del
  /// widget que inicializó las notificaciones si corresponde.
  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    _onMessageSub = null;
  }
}