import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services_screen.dart'; // Ajusta la ruta si tu archivo está en otra carpeta

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController; // nullable
  final LatLng _initialPosition = const LatLng(10.3910, -75.4794); // Cartagena

  String selectedMode = "routes"; // 'routes' | 'risk' | 'services'
  final TextEditingController startController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();

  // Caches
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _riskCircles = {};

  // Resultado de búsqueda (muestra solo cuando el usuario presiona Search Route)
  Polyline? _searchedPolyline;
  final Set<Marker> _searchedMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadRiskZones();
    _loadServices();
    // NOTA: no cargamos rutas globalmente para que no aparezcan hasta buscar
  }

  // ---------------------------
  // Load risk zones -> markers + circles
  // ---------------------------
  Future<void> _loadRiskZones() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('risk_zones').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final loc = data['location'];
        if (loc is GeoPoint) {
          final level = (data['level'] ?? 'Medium').toString().toLowerCase();
          double hue = BitmapDescriptor.hueOrange;
          Color fill = Colors.orange.withOpacity(0.25);
          if (level == 'high') {
            hue = BitmapDescriptor.hueRed;
            fill = Colors.red.withOpacity(0.22);
          } else if (level == 'low') {
            hue = BitmapDescriptor.hueGreen;
            fill = Colors.green.withOpacity(0.18);
          }

          final marker = Marker(
            markerId: MarkerId('risk_${doc.id}'),
            position: LatLng(loc.latitude, loc.longitude),
            infoWindow: InfoWindow(title: data['name'] ?? 'Risk Zone', snippet: 'Level: ${data['level'] ?? 'Medium'}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          );

          final dynamic radiusRaw = data['radius'] ?? data['rad'] ?? 250;
          double radius = 250;
          if (radiusRaw is num) radius = radiusRaw.toDouble();
          else radius = double.tryParse(radiusRaw.toString()) ?? 250;

          final circle = Circle(
            circleId: CircleId('risk_circle_${doc.id}'),
            center: LatLng(loc.latitude, loc.longitude),
            radius: radius,
            fillColor: fill,
            strokeColor: fill.withOpacity(0.9),
            strokeWidth: 2,
          );

          _markers.add(marker);
          _riskCircles.add(circle);
        }
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error loading risk zones: $e');
    }
  }

  // ---------------------------
  // Load services (solo servicios verificados) -> crea markers con onTap que abren ServiceDetailScreen
  // ---------------------------
  Future<void> _loadServices() async {
    try {
      // Solo obtener servicios con verified == true (maneja varios nombres posibles)
      final snapshot = await FirebaseFirestore.instance.collection('services').get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Determinar flag verified de forma tolerante
        final ver = data['verified'] ?? data['isVerified'] ?? data['verifiedService'];
        bool isVerified = false;
        if (ver is bool) isVerified = ver;
        else if (ver is String) isVerified = ver.toLowerCase() == 'true';

        if (!isVerified) continue; // SALTAR servicios no verificados

        LatLng? pos;
        final loc = data['location'];
        if (loc is GeoPoint) {
          pos = LatLng(loc.latitude, loc.longitude);
        } else {
          final latRaw = data['latitude'] ?? data['lat'] ?? data['location_lat'];
          final lngRaw = data['longitude'] ?? data['lng'] ?? data['location_lng'];
          if (latRaw != null && lngRaw != null) {
            final lat = (latRaw is num) ? latRaw.toDouble() : double.tryParse(latRaw.toString());
            final lng = (lngRaw is num) ? lngRaw.toDouble() : double.tryParse(lngRaw.toString());
            if (lat != null && lng != null) pos = LatLng(lat, lng);
          }
        }

        if (pos == null) continue;

        final id = doc.id;
        final name = (data['name'] ?? 'Service').toString();
        final type = (data['type'] ?? '').toString();

        final marker = Marker(
          markerId: MarkerId('service_$id'),
          position: pos,
          infoWindow: InfoWindow(title: name, snippet: type, onTap: () async {
            try {
              final docSnap = await FirebaseFirestore.instance.collection('services').doc(id).get();
              if (docSnap.exists) {
                final dataMap = docSnap.data() as Map<String, dynamic>;
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceData: dataMap)),
                  );
                }
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not found')));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading service: $e')));
            }
          }),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          onTap: () async {
            try {
              final docSnap = await FirebaseFirestore.instance.collection('services').doc(id).get();
              if (docSnap.exists) {
                final dataMap = docSnap.data() as Map<String, dynamic>;
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceData: dataMap)),
                  );
                }
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service not found')));
              }
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading service: $e')));
            }
          },
        );

        _markers.add(marker);
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error loading services: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  // ---------------------------
  // Búsqueda de ruta (solo cuando el usuario presiona Search Route)
  // ---------------------------
  Future<void> _searchRoute() async {
    final origin = startController.text.trim();
    final dest = destinationController.text.trim();

    if (origin.isEmpty || dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter both origin and destination.')));
      return;
    }

    try {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('routes')
          .where('name_origin', isEqualTo: origin)
          .where('name_destine', isEqualTo: dest)
          .get();

      Map<String, dynamic>? routeData;
      String? foundDocId;

      if (query.docs.isNotEmpty) {
        routeData = query.docs.first.data() as Map<String, dynamic>;
        foundDocId = query.docs.first.id;
      } else {
        final all = await FirebaseFirestore.instance.collection('routes').get();
        for (var d in all.docs) {
          final dat = d.data();
          if (_routeMatchesNames(dat, origin, dest)) {
            routeData = dat;
            foundDocId = d.id;
            break;
          }
        }
      }

      if (routeData == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No routes found for those locations.')));
        return;
      }

      final rawPath = routeData['path'];
      final List<LatLng> points = [];
      if (rawPath is List) {
        for (var p in rawPath) {
          if (p is GeoPoint) {
            points.add(LatLng(p.latitude, p.longitude));
          } else if (p is Map) {
            final lat = (p['latitude'] is num) ? (p['latitude'] as num).toDouble() : double.tryParse(p['latitude'].toString());
            final lng = (p['longitude'] is num) ? (p['longitude'] as num).toDouble() : double.tryParse(p['longitude'].toString());
            if (lat != null && lng != null) points.add(LatLng(lat, lng));
          }
        }
      }

      if (points.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The route has no stored coordinates.')));
        return;
      }

      final risk = (routeData['riskLevel'] ?? routeData['risk'] ?? 'Low').toString().toLowerCase();
      Color color = Colors.green;
      if (risk == 'medium') color = Colors.orange;
      if (risk == 'high') color = Colors.red;

      final polyId = PolylineId('searched_${foundDocId ?? DateTime.now().millisecondsSinceEpoch}');
      final polyline = Polyline(polylineId: polyId, points: points, color: color, width: 6);

      final originName = (routeData['name_origin'] ?? routeData['origin'] ?? origin).toString();
      final destName = (routeData['name_destine'] ?? routeData['destine'] ?? dest).toString();
      final price = (routeData['price'] ?? '').toString();
      final distance = (routeData['distance'] ?? '').toString();

      final endPoint = points.last;
      final searchMarker = Marker(
        markerId: MarkerId('searched_marker_${polyId.value}'),
        position: endPoint,
        infoWindow: InfoWindow(title: '$originName → $destName', snippet: 'Price: $price  •  Dist: $distance'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );

      setState(() {
        _searchedPolyline = polyline;
        _searchedMarkers
          ..clear()
          ..add(searchMarker);
        selectedMode = 'routes';
      });

      if (_mapController != null) {
        try {
          await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(_calculateBounds(points), 80));
        } catch (e) {
          debugPrint('animateCamera error: $e');
        }
      }

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$originName → $destName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Price: $price'),
                Text('Distance: $distance'),
                Text('Risk: ${risk[0].toUpperCase()}${risk.substring(1)}'),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error searching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
    }
  }

  bool _routeMatchesNames(Map<String, dynamic> dat, String origin, String dest) {
    final lowerOrigin = origin.toLowerCase();
    final lowerDest = dest.toLowerCase();

    final possibleOriginFields = ['name_origin', 'nameOrigin', 'origin', 'origin_name'];
    final possibleDestFields = ['name_destine', 'nameDestine', 'destine', 'destination', 'destination_name'];

    String getFieldLower(List<String> keys) {
      for (var k in keys) {
        final v = dat[k];
        if (v != null) return v.toString().toLowerCase();
      }
      return '';
    }

    final oVal = getFieldLower(possibleOriginFields);
    final dVal = getFieldLower(possibleDestFields);

    if (oVal.isEmpty || dVal.isEmpty) return false;

    if (oVal == lowerOrigin && dVal == lowerDest) return true;
    if (oVal.contains(lowerOrigin) && dVal.contains(lowerDest)) return true;
    return false;
  }

  LatLngBounds _calculateBounds(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (var p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  Set<Marker> _getVisibleMarkers() {
    if (selectedMode == 'risk') {
      return _markers.where((m) => m.markerId.value.startsWith('risk_')).toSet();
    } else if (selectedMode == 'services') {
      return _markers.where((m) => m.markerId.value.startsWith('service_')).toSet();
    } else if (selectedMode == 'routes') {
      return _searchedMarkers;
    }
    return {};
  }

  Set<Polyline> _getVisiblePolylines() {
    if (selectedMode == 'routes') {
      return _searchedPolyline != null ? {_searchedPolyline!} : {};
    }
    return {};
  }

  Set<Circle> _getVisibleCircles() {
    if (selectedMode == 'risk') {
      return _riskCircles;
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF007274);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Map', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _initialPosition, zoom: 12),
            markers: _getVisibleMarkers(),
            polylines: _getVisiblePolylines(),
            circles: _getVisibleCircles(),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          Positioned(
            top: 18,
            left: 14,
            right: 14,
            child: Column(
              children: [
                _buildSearchField(startController, 'Origin name', Icons.place),
                const SizedBox(height: 8),
                _buildSearchField(destinationController, 'Destination name', Icons.flag),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _searchRoute,
                        style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                        child: const Text('Search Route'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _searchedPolyline = null;
                          _searchedMarkers.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
                      child: const Icon(Icons.clear, color: Colors.black54),
                    )
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 18,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10)
              ]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildModeButton(Icons.route, 'Routes', 'routes'),
                  _buildModeButton(Icons.shield, 'Risks', 'risk'),
                  _buildModeButton(Icons.storefront, 'Services', 'services'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: const Color(0xFF007274)),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildModeButton(IconData icon, String label, String mode) {
    final isActive = selectedMode == mode;
    return InkWell(
      onTap: () => setState(() => selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF007274) : Colors.grey, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: isActive ? const Color(0xFF007274) : Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}