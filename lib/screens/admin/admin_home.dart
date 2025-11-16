import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  final Color primary = const Color(0xFF007274);
  final Color accent = const Color(0xFF6CCCE4);

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _email = '';
  String _userDocId = '';
  late final AnimationController _aniCtrl;

  // para forzar recarga del contador de unread
  late Future<int> _unreadFuture;

  @override
  void initState() {
    super.initState();
    _aniCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _initUser();
    _unreadFuture = _fetchUnreadCount(); // inicial
  }

  @override
  void dispose() {
    _aniCtrl.dispose();
    super.dispose();
  }

  Future<void> _initUser() async {
    final u = _auth.currentUser;
    if (u == null) return;
    _email = u.email ?? '';

    if (_email.isNotEmpty) {
      try {
        final q = await _fire
            .collection('users')
            .where('email', isEqualTo: _email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          _userDocId = q.docs.first.id;
        } else {
          final q2 = await _fire
              .collection('tourist')
              .where('email', isEqualTo: _email)
              .limit(1)
              .get();
          if (q2.docs.isNotEmpty) _userDocId = q2.docs.first.id;
        }
      } catch (_) {
        // ignore errors
      }
    }
    if (mounted) setState(() {});
  }

  /// Cuenta los mensajes no leídos dirigidos al admin (por email o recipientId).
  Future<int> _fetchUnreadCount() async {
  try {
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryByEmail =
        Future.value([]);
    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> queryById =
        Future.value([]);

    if (_email.isNotEmpty) {
      queryByEmail = _fire
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('recipientEmail', isEqualTo: _email)
          .get()
          .then((snap) => snap.docs);
    }

    if (_userDocId.isNotEmpty) {
      queryById = _fire
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('recipientId', isEqualTo: _userDocId)
          .get()
          .then((snap) => snap.docs);
    }

    final results = await Future.wait([queryByEmail, queryById]);

    // Unir resultados sin duplicados
    final Set<String> ids = {};
    for (var list in results) {
      for (var d in list) ids.add(d.id);
    }

    return ids.length;
  } catch (e) {
    debugPrint('Error fetching unread count: $e');
    return 0;
  }
}

  Future<DocumentSnapshot<Map<String, dynamic>>?> _fetchProfileDoc() async {
    try {
      if (_email.isNotEmpty) {
        final q = await _fire
            .collection('users')
            .where('email', isEqualTo: _email)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) return q.docs.first;
        final q2 = await _fire
            .collection('tourist')
            .where('email', isEqualTo: _email)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) return q2.docs.first;
      }
    } catch (_) {}
    return null;
  }

  Widget _buildHeader(double height) {
    return AnimatedBuilder(
      animation: _aniCtrl,
      builder: (context, _) {
        final t = _aniCtrl.value;
        return Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + t, -0.5),
              end: Alignment(1.0 - t, 0.5),
              colors: [primary, accent],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Admin Dashboard',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Control panel • Manage users, services & ambassadors',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      Row(children: [
                        ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/admin/reports'),
                          icon: const Icon(Icons.report, size: 18),
                          label: const Text('Reports'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: primary,
                              elevation: 0),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/admin/services'),
                          icon: const Icon(Icons.room_service, size: 18),
                          label: const Text('Services'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side:
                                  BorderSide(color: Colors.white.withOpacity(0.2))),
                        ),
                      ])
                    ]),
              ),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                future: _fetchProfileDoc(),
                builder: (context, snap) {
                  final data = (snap.data?.data() ?? {});
                  final name =
                      data['name'] ?? _auth.currentUser?.displayName ?? 'Admin';
                  final photo =
                      (data['photoUrl'] ?? data['photo'] ?? _auth.currentUser?.photoURL) ?? '';
                  return InkWell(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundImage:
                              photo.toString().isNotEmpty ? NetworkImage(photo) : null,
                          backgroundColor: Colors.white30,
                          child: photo.toString().isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              Text('Administrator',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 12)),
                            ]),
                      ]),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridTile(String title, String subtitle, IconData icon,
      String routeName, {Color? color}) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, routeName),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [Colors.white, Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: primary.withOpacity(0.12), child: Icon(icon, color: primary)),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const Spacer(),
          Align(alignment: Alignment.bottomRight, child: Icon(Icons.chevron_right, color: Colors.black26)),
        ]),
      ),
    );
  }

  // fuerza recarga del contador de mensajes no leídos
  void _refreshUnread() {
    setState(() {
      _unreadFuture = _fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.26;

    return Scaffold(
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(children: [
          _buildHeader(height),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  // search + unread messages badge
                  Row(children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                        child: Row(children: [
                          const Icon(Icons.search, color: Colors.black54),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(decoration: const InputDecoration.collapsed(hintText: 'Search users, services, ambassadors...'))),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // FutureBuilder en lugar de StreamBuilder
                    FutureBuilder<int>(
                      future: _unreadFuture,
                      builder: (context, snap) {
                        final unread = snap.data ?? 0;
                        return Stack(children: [
                          IconButton(
                            onPressed: () {
                              _refreshUnread();
                              Navigator.pushNamed(context, '/admin/messages');
                            },
                            icon: const Icon(Icons.mail_outline, size: 28),
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                                child: Text(unread > 99 ? '99+' : unread.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            )
                        ]);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshUnread,
                      tooltip: 'Refresh unread count',
                    ),
                  ]),
                  const SizedBox(height: 18),

                  // GRID (principal)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : (MediaQuery.of(context).size.width > 600 ? 3 : 2),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                      children: [
                        _buildGridTile('Users', 'Manage users & restrictions', Icons.people, '/admin/users'),
                        _buildGridTile('Providers', 'Approve & edit providers', Icons.store, '/admin/providers'),
                        _buildGridTile('Ambassadors', 'Manage ambassadors', Icons.person_search, '/admin/ambassadors'),
                        _buildGridTile('Services', 'Create / Edit / Disable', Icons.room_service, '/admin/services'),
                        _buildGridTile('Reviews', 'Moderate reviews & block', Icons.rate_review, '/admin/reviews'),
                        _buildGridTile('Map & Places', 'Add safe places & routes', Icons.map, '/map'),
                        _buildGridTile('Reports', 'View / Export reports', Icons.insert_drive_file, '/admin/reports'),
                        _buildGridTile('Tools', 'System utilities & jobs', Icons.build_circle, '/admin/tools'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx) {
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: _fetchProfileDoc(),
            builder: (context, snap) {
              final doc = snap.data;
              final data = doc?.data() ?? {};
              final name = (data['name'] ?? _auth.currentUser?.displayName ?? 'Admin').toString();
              final email = (data['email'] ?? _auth.currentUser?.email ?? _email).toString();
              final photo = (data['photoUrl'] ?? data['photo'] ?? _auth.currentUser?.photoURL) ?? '';

              return UserAccountsDrawerHeader(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [primary, accent])),
                currentAccountPicture: CircleAvatar(
                  backgroundImage: photo.toString().isNotEmpty ? NetworkImage(photo) : null,
                  backgroundColor: Colors.white24,
                  child: photo.toString().isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                accountEmail: Text(email),
              );
            },
          ),
          ListTile(leading: const Icon(Icons.notifications), title: const Text('Notifications'), onTap: () => Navigator.pushNamed(ctx, '/admin/notifications')),
          ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () => Navigator.pushNamed(ctx, '/admin/profile')),
          const Divider(),
          ListTile(leading: const Icon(Icons.group), title: const Text('Users'), onTap: () => Navigator.pushNamed(ctx, '/admin/users')),
          ListTile(leading: const Icon(Icons.room_service), title: const Text('Services'), onTap: () => Navigator.pushNamed(ctx, '/admin/services')),
          ListTile(leading: const Icon(Icons.person_search), title: const Text('Ambassadors'), onTap: () => Navigator.pushNamed(ctx, '/admin/ambassadors')),
          ListTile(leading: const Icon(Icons.store), title: const Text('Providers'), onTap: () => Navigator.pushNamed(ctx, '/admin/providers')),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sign out', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              await _auth.signOut();
              if (mounted) Navigator.pushNamedAndRemoveUntil(ctx, '/start', (route) => false);
            },
          ),
        ]),
      ),
    );
  }
}