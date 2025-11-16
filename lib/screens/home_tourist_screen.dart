import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';
import 'my_reservations_screen.dart';

class HomeTouristScreen extends StatelessWidget {
  const HomeTouristScreen({super.key});

  Future<Map<String, dynamic>?> _loadCurrentUserDoc() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return null;
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF007274);
    final Color accent = const Color(0xFFFF7D00);
    final Color lightBg = const Color(0xFFF6F9FB);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Image.asset('assets/icono.png', height: 38),
            const SizedBox(width: 8),
            const Text(
              'Safe Tourism Cartagena',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),

      // Drawer con FutureBuilder para mostrar foto del usuario si existe
      drawer: Drawer(
        backgroundColor: const Color(0xFFF8FAFA),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            FutureBuilder<Map<String, dynamic>?>(
              future: _loadCurrentUserDoc(),
              builder: (context, snap) {
                final data = snap.data;
                final photoUrl = data?['photoUrl'] ?? data?['photo'] ?? '';
                final displayName = data?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? 'User';
                final email = data?['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';

                return DrawerHeader(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, const Color(0xFF6CCCE4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                   child: FutureBuilder<String?>(
                     future: _getTouristPhotoUrl(), // función abajo
                     builder: (context, snap) {
                        final photoUrl = snap.data;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (photoUrl != null && photoUrl.isNotEmpty)
                              CircleAvatar(radius: 30, backgroundImage: NetworkImage(photoUrl))
                            else
                              Image.asset('assets/icono.png', height: 60),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text('Safe Tourism Cartagena', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                           ),
                          ],
                        );
                     },
                    ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF004A50)),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF004A50)),
              title: const Text('Messages'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFF004A50)),
              title: const Text('My Reservations'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyReservationsScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Color(0xFF004A50)),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Color(0xFF004A50)),
              title: const Text('My Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/reports');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/start', (route) => false);
              },
            ),
          ],
        ),
      ),

      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  child: Image.asset(
                    'assets/Cartagena.png',
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to Cartagena de Indias!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF004A50),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'We are happy to guide you through a safe and unforgettable experience in this beautiful city.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(55),
                    backgroundColor: Colors.redAccent,
                    elevation: 10,
                    shadowColor: Colors.redAccent.withOpacity(0.5),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/report'),
                  child: const Icon(Icons.report, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Make a Report',
                  style: TextStyle(
                    color: Color(0xFF004A50),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                _buildInfoSection(),
                const SizedBox(height: 40),
                // Contact Footer
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
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
                const SizedBox(height: 40),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, const Color(0xFF005C69)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _footerButton(
                      icon: Icons.map,
                      label: 'Map',
                      onTap: () => Navigator.pushNamed(context, '/map'),
                    ),
                    _footerButton(
                      icon: Icons.room_service,
                      label: 'Services',
                      onTap: () => Navigator.pushNamed(context, '/services'),
                    ),
                    _footerButton(
                      icon: Icons.group,
                      label: 'Ambassador',
                      onTap: () => Navigator.pushNamed(context, '/ambassador'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final infoData = [
      {
        "icon": Icons.info_outline,
        "title": "About Us",
        "text":
            "We promote safe, transparent, and authentic tourism in Cartagena through technology and verified local services."
      },
      {
        "icon": Icons.flag_rounded,
        "title": "Mission",
        "text":
            "To ensure every visitor experiences Cartagena with confidence, security, and cultural respect."
      },
      {
        "icon": Icons.remove_red_eye_rounded,
        "title": "Vision",
        "text":
            "To position Cartagena as the most secure and sustainable tourist destination in Latin America."
      },
    ];

    return Column(
      children: infoData
          .map(
            (item) => AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6CCCE4), Color(0xFF007274)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      item["icon"] as IconData,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["title"] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item["text"] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _footerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: Colors.white24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _getTouristPhotoUrl() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) return null;
  try {
    final q = await FirebaseFirestore.instance.collection('tourist').where('email', isEqualTo: user.email).limit(1).get();
    if (q.docs.isNotEmpty) return (q.docs.first.data()['photoUrl'] ?? q.docs.first.data()['photo'] ?? '').toString();
    // fallback: buscar en 'users'
    final q2 = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();
    if (q2.docs.isNotEmpty) return (q2.docs.first.data()['photoUrl'] ?? q2.docs.first.data()['photo'] ?? '').toString();
  } catch (e) {
    debugPrint('Error getting tourist photo: $e');
  }
  return null;
}