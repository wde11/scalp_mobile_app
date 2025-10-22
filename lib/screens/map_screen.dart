import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _currentLocationController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  LatLng? _currentLocationLatLng;
  LatLng? _destinationLatLng;

  @override
  void initState() {
    super.initState();
    _currentLocationController.text = 'Father Selga, Bangkerohan, Davao City';
    _destinationController.text = 'Malvar St, Davao City';
    
    // Set initial locations
    _currentLocationLatLng = const LatLng(10.3157, 123.8854);
    _destinationLatLng = const LatLng(10.3165, 123.8889);
  }

  @override
  void dispose() {
    _currentLocationController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _getCurrentLocation() {
    // Placeholder: In a real app, you'd use geolocator package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Getting current location...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map with a light theme
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(10.3157, 123.8854),
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // Markers for current location and destination
              MarkerLayer(
                markers: [
                  if (_currentLocationLatLng != null)
                    Marker(
                      point: _currentLocationLatLng!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E88E5),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                      ),
                    ),
                  if (_destinationLatLng != null)
                    Marker(
                      point: _destinationLatLng!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF6B6B),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top Elements: Location Info Card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current Location
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E88E5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Current Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _currentLocationController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.my_location, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          onPressed: _getCurrentLocation,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Destination
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6B6B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Destination',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom-Right Elements: Zoom buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}