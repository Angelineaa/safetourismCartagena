import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/screens/proveedores/proveedor_home.dart';
import 'screens/start_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_tourist_screen.dart';
import 'screens/register_screen.dart';
import 'screens/report_screen.dart';  
import 'screens/map_screen.dart'; 
import 'screens/services_screen.dart';
import 'screens/ambassador_screen.dart';
import 'screens/reports_list_screen.dart'; 
import 'screens/report_detail_screen.dart';
import 'screens/proveedores/my_services_screen.dart';
import 'screens/proveedores/edit_service_screen.dart';
import 'screens/proveedores/reservas_screen.dart';
import 'screens/proveedores/add_service_screen.dart';
import 'screens/proveedores/provider_profile_screen.dart';
import 'screens/proveedores/notificaciones_proveedor_screen.dart';
import 'screens/proveedores/membresia_screen.dart';
import 'screens/ambassador/ambassador_home_screen.dart';
import 'screens/ambassador/ambassador_notifications_screen.dart';
import 'screens/admin/admin_home.dart';
import 'screens/admin/users_management.dart';
import 'screens/admin/providers_management.dart';
import 'screens/admin/ambassadors_management.dart';
import 'screens/admin/services_management.dart';
import 'screens/admin/reviews_moderation.dart';
import 'screens/admin/map_admin.dart';
import 'screens/admin/reports_management.dart';
import 'screens/admin/tools_admin.dart';
import 'screens/admin/admin_messages.dart';
import 'screens/admin/admin_profile.dart';
import 'screens/admin/admin_notifications.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDNsY1tB0O-EoGlhIB9lqrMvr4tcE44Ik8",
      authDomain: "safe-tourism-cartagena.firebaseapp.com",
      projectId: "safe-tourism-cartagena",
      storageBucket: "safe-tourism-cartagena.appspot.com",
      messagingSenderId: "326339524473",
      appId: "1:326339524473:web:b732b5fd31f3b5500c61a8",
      measurementId: "G-7FJT370PDV"
    ),
  );
  // Temporalmente deshabilitar la persistencia de Firestore para descartar bugs
  // relacionados con la capa offline. Quitar o comentar esta línea cuando
  // se haya verificado la causa del problema.
  try {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
  } catch (e) {
    // En algunas plataformas o versiones esto puede lanzar; ignoramos aquí.
  }
  
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe Tourism Cartagena',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007274)),
        useMaterial3: true,
      ),
       initialRoute: '/start',
      routes: {
        '/start': (context) => const StartScreen(), 
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/touristHome': (context) => const HomeTouristScreen(),
        '/providerHome': (context) => const ProveedorHomeScreen(),
        '/ambassadorHome': (context) => const AmbassadorHomeScreen(),
        '/report': (context) => ReportScreen(),
        '/reports': (context) => const ReportsListScreen(),
        '/reportDetail': (context)  => const ReportDetailScreen(),
        '/map': (context) => const MapScreen(), 
        '/services': (context) => ServicesScreen(),
        '/addService': (context) => const AddServiceScreen(),
        '/myServices': (context) => const MyServicesScreen(),           
        '/editService': (context) => const EditServiceScreen(),
        '/reservas': (context) => const ReservasScreen(), 
        '/providerProfile': (context) => const ProviderProfileScreen(),
        '/notificacionesProveedor': (context) => const NotificacionesProveedorScreen(),
        '/membresia': (context) => const MembresiaScreen(),
        '/ambassador': (context) => AmbassadorScreen(),
        '/ambassador_notifications': (ctx) => const AmbassadorNotificationsScreen(),
        '/adminHome': (context) => const AdminHomeScreen(),
        '/admin/users': (_) => const UsersManagementScreen(),
        '/admin/providers': (_) => const ProvidersManagementScreen(),
        '/admin/ambassadors': (_) => const AmbassadorsManagementScreen(),
        '/admin/services': (_) => const ServicesManagementScreen(),
        '/admin/reviews': (_) => const ReviewsModerationScreen(),
        '/admin/reports': (_) => const ReportsManagementScreen(),
        '/admin/tools': (_) => const AdminToolsScreen(),
        '/admin/messages': (_) => const AdminMessagesScreen(),
        '/admin/profile': (_) => const AdminProfileScreen(),
        '/admin/notifications': (_) => const AdminNotificationsScreen(),
        '/maps': (_) => const MapAdminScreen(),
      },
    );
  }
}

