import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Asegúrate de que estas rutas estén registradas en main.dart
import 'add_service_screen.dart';
import 'my_services_screen.dart';
import 'reservas_screen.dart';
// import 'membresia_screen.dart';
// import 'notificaciones_proveedor_screen.dart';
import 'provider_profile_screen.dart';

class ProveedorHomeScreen extends StatelessWidget {
  const ProveedorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);
    final bg = const Color(0xFFF7F9F9);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: Row(
          children: [
            // logo pequeño en el appbar
            Image.asset('assets/icono.png', height: 36),
            const SizedBox(width: 8),
            Text(
              "Proveedor",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),

      // Drawer lateral simple con Perfil y Cerrar sesión
      drawer: Drawer(
        backgroundColor: const Color(0xFFF8FAFA),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, const Color(0xFF6CCCE4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // logo redondo
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('assets/icono.png'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Panel de proveedor',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gestiona tus servicios y reservas',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF004A50)),
              title: const Text('Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/providerProfile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFF004A50)),
              title: const Text('Mis Servicios'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/myServices');
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Color(0xFF004A50)),
              title: const Text('Reservas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reservas');
              },
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium, color: Color(0xFF004A50)),
              title: const Text('Membresía'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/membresia');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active, color: Color(0xFF004A50)),
              title: const Text('Notificaciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/notificacionesProveedor');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/start', (route) => false);
              },
            ),
          ],
        ),
      ),

      // Body con imagen de inicio + tarjetas
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Imagen de inicio grande (assets/cartagena_inicio.png)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 14),
                  // imagen principal (si ocupa mucho, ajusta height)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
                    child: Image.asset(
                      'assets/cartagena_inicio.png',
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "¡Bienvenido a tu panel de proveedor!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Gestiona tus servicios, revisa reservas y controla tu membresía.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Wrap(
                spacing: 18,
                runSpacing: 18,
                alignment: WrapAlignment.center,
                children: [
                  _buildCard(
                    context,
                    title: "Registrar Servicio",
                    icon: Icons.add_business,
                    color: Colors.teal,
                    onTap: () => Navigator.pushNamed(context, '/addService'),
                  ),
                  _buildCard(
                    context,
                    title: "Mis Servicios",
                    icon: Icons.store,
                    color: Colors.lightBlue,
                    onTap: () => Navigator.pushNamed(context, '/myServices'),
                  ),
                  _buildCard(
                    context,
                    title: "Reservas",
                    icon: Icons.assignment_turned_in,
                    color: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, '/reservas'),
                  ),
                  _buildCard(
                    context,
                    title: "Membresía",
                    icon: Icons.workspace_premium,
                    color: const Color.fromARGB(255, 0, 62, 66),
                    onTap: () => Navigator.pushNamed(context, '/membresia'),
                  ),
                  _buildCard(
                    context,
                    title: "Notificaciones",
                    icon: Icons.notifications_active,
                    color: Colors.redAccent,
                    onTap: () => Navigator.pushNamed(context, '/notificacionesProveedor'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            // Contact Footer
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF007274),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.email, color: Colors.white, size: 28),
                  const SizedBox(height: 12),
                  const Text(
                    'Need Help or Information?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Contact us at:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'adminsafetourism@gmail.com',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context,
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      splashColor: color.withOpacity(0.2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: MediaQuery.of(context).size.width * 0.42,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 10, offset: const Offset(2, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.12), radius: 30, child: Icon(icon, color: color, size: 30)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14, color: const Color(0xFF007274))),
          ],
        ),
      ),
    );
  }
}