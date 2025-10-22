import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng _currentLocation = const LatLng(10.3157, 123.8854); // Cebu City default
  Set<Marker> _markers = {};
  String _currentLocationName = '';
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    // Don't call _getUserLocation here - wait for map to be ready
  }

  @override
  void dispose() {
    if (_mapReady) {
      _mapController.dispose();
    }
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    // Guard: only proceed if map controller is ready
    if (!_mapReady) {
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied forever')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted && _mapReady) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_currentLocation, 15),
        );

        // Get address from coordinates
        _getAddressFromCoordinates(position.latitude, position.longitude);
        _updateUserMarker();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        setState(() {
          _currentLocationName = '${place.street}, ${place.locality}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting address: $e')),
        );
      }
    }
  }

  void _updateUserMarker() {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'user_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentLocation,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _mapReady = true;
              _mapController.animateCamera(
                CameraUpdate.newLatLngZoom(_currentLocation, 15),
              );
              // Get location after map is ready
              _getUserLocation();
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // Top Elements: Location info
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Current Location',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentLocationName.isNotEmpty
                                  ? _currentLocationName
                                  : 'Lat: ${_currentLocation.latitude.toStringAsFixed(4)}, Lng: ${_currentLocation.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
                    _mapController.animateCamera(
                      CameraUpdate.zoomIn(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomOut',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                  onPressed: () {
                    _mapController.animateCamera(
                      CameraUpdate.zoomOut(),
                    );
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'centerLocation',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.my_location, color: Colors.black),
                  onPressed: _getUserLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}