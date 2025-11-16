import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ambassador_detail_screen.dart';

class AmbassadorScreen extends StatefulWidget {
  const AmbassadorScreen({super.key});

  @override
  State<AmbassadorScreen> createState() => _AmbassadorScreenState();
}

class _AmbassadorScreenState extends State<AmbassadorScreen> {
  final Color primary = const Color(0xFF007274);
  final Color accent = const Color(0xFF6CCCE4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tourist Ambassadors',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF6F9FB),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Mostrar solo embajadores con availability == 'Available' y verified == true
        stream: FirebaseFirestore.instance
            .collection('ambassadors')
            .where('availability', isEqualTo: 'Available')
            .where('verified', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No ambassadors available at the moment.",
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
            );
          }

          final ambassadors = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ambassadors.length,
            itemBuilder: (context, index) {
              final data = ambassadors[index].data();

              // seguridad: evitar castings directos que explotan si el campo no existe
              final photoUrl = (data['photoUrl'] ?? '').toString();
              final name = (data['name'] ?? 'Unnamed Ambassador').toString();
              final languages = (data['languages'] is List)
                  ? (data['languages'] as List).map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).join(', ')
                  : (data['languages']?.toString() ?? '—');
              final experience = (data['experience'] ?? '').toString();
              final rating = (data['rating'] ?? 0).toString();

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                margin: const EdgeInsets.symmetric(vertical: 12),
                elevation: 6,
                shadowColor: primary.withOpacity(0.3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AmbassadorDetailScreen(ambassadorData: data),
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.person, size: 80, color: Colors.grey),
                                ),
                              )
                            : Container(
                                height: 180,
                                width: double.infinity,
                                color: Colors.grey[200],
                                child: const Icon(Icons.person, size: 80, color: Colors.grey),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF004A50),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text("Languages: $languages", style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 6),
                            Text("Experience: $experience", style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      rating,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AmbassadorDetailScreen(ambassadorData: data),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Hire",
                                    style: TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}