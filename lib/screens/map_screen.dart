import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:scalp_mobile_app/models/location_data.dart';
import 'package:scalp_mobile_app/models/transaction.dart';
import 'package:scalp_mobile_app/services/directions_service.dart';
import 'package:scalp_mobile_app/services/scavenger_hunt_service.dart';
import 'package:scalp_mobile_app/models/scavenger_hunt_item.dart';
import 'package:scalp_mobile_app/globals.dart';

class MapScreen extends StatefulWidget {
  final Transaction? activeTransaction;
  final LocationData? sharedLocation;
  
  const MapScreen({super.key, this.activeTransaction, this.sharedLocation});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng _currentLocation = const LatLng(7.0779, 125.5997);
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _currentLocationName = '';
  String _destinationName = '';
  bool _mapReady = false;
  String? _routeDistance;
  String? _routeDuration;
  final DirectionsService _directionsService = DirectionsService();
  final ScavengerHuntService _scavengerHuntService = ScavengerHuntService();
  List<ScavengerHuntItem> _scavengerHuntItems = [];
  bool _showScavengerHunt = true; // Toggle to show/hide scavenger hunt items

  @override
  void initState() {
    super.initState();
    _loadScavengerHuntItems();
    
    // Check if there's a shared location to show
    if (widget.sharedLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSharedLocation();
      });
    }
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeTransaction != oldWidget.activeTransaction) {
      _handleTransactionUpdate();
    }
  }

  Future<void> _handleTransactionUpdate() async {
    if (widget.activeTransaction != null && 
        widget.activeTransaction!.sellerLocation != null &&
        widget.activeTransaction!.locationSharingEnabled) {
      await _drawRoute(widget.activeTransaction!.sellerLocation!);
    } else {
      _clearRoute();
    }
  }

  void _loadScavengerHuntItems() {
    _scavengerHuntService.getActiveItems().listen((items) {
      if (mounted) {
        setState(() {
          _scavengerHuntItems = items;
          _updateScavengerHuntMarkers();
        });
      }
    });
  }

  Future<void> _handleSharedLocation() async {
    if (widget.sharedLocation == null || !_mapReady) return;
    
    final sharedLoc = widget.sharedLocation!;
    final sharedLatLng = LatLng(sharedLoc.latitude, sharedLoc.longitude);
    
    // Get street address for the shared location
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        sharedLoc.latitude,
        sharedLoc.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks.first;
        final street = place.street ?? '';
        final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
        
        String address;
        if (street.isNotEmpty && locality.isNotEmpty) {
          address = '$street, $locality';
        } else if (locality.isNotEmpty) {
          address = locality;
        } else if (street.isNotEmpty) {
          address = street;
        } else {
          address = sharedLoc.address;
        }
        
        setState(() {
          _destinationName = address;
        });
      }
    } catch (e) {
      // Fall back to the provided address
      if (mounted) {
        setState(() {
          _destinationName = sharedLoc.address;
        });
      }
    }
    
    // Add marker for the shared location
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'shared_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('shared_location'),
          position: sharedLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Shared Location',
            snippet: _destinationName,
          ),
        ),
      );
    });
    
    // Animate camera to the shared location
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(sharedLatLng, 15),
    );
    
    // Clear the global state after handling
    SharedLocationState.clearSharedLocation();
  }

  void _updateScavengerHuntMarkers() async {
    if (!_showScavengerHunt || !_mapReady) return;

    // Remove old scavenger hunt markers
    _markers.removeWhere((marker) => 
      marker.markerId.value.startsWith('scavenger_'));

    // Add new scavenger hunt markers
    for (var item in _scavengerHuntItems) {
      final isClaimedByMe = _scavengerHuntService.isClaimedByCurrentUser(item);
      final isClaimed = item.isClaimed;
      
      // Determine marker color based on status
      BitmapDescriptor markerIcon;
      if (isClaimedByMe) {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (isClaimed) {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      } else {
        markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }

      _markers.add(
        Marker(
          markerId: MarkerId('scavenger_${item.id}'),
          position: LatLng(item.latitude, item.longitude),
          icon: markerIcon,
          infoWindow: InfoWindow(
            title: item.title,
            snippet: '₱${item.price.toStringAsFixed(0)} - ${isClaimed ? "Claimed" : "Available"}',
          ),
          onTap: () => _showScavengerHuntItemDetails(item),
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _showScavengerHuntItemDetails(ScavengerHuntItem item) {
    final isClaimedByMe = _scavengerHuntService.isClaimedByCurrentUser(item);
    final isClaimed = item.isClaimed;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image
            if (item.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, size: 50),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Price
            Text(
              '₱${item.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              item.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Status and action button
            if (isClaimedByMe)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'You claimed this item!',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else if (isClaimed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Already Claimed',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: () => _claimItem(item),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: const Color(0xFF3864FF),
                ),
                child: const Text(
                  'Claim Item',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _claimItem(ScavengerHuntItem item) async {
    Navigator.pop(context); // Close bottom sheet

    final success = await _scavengerHuntService.claimItem(item.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '🎉 Item claimed successfully!'
                : 'Failed to claim item. It may have been claimed by someone else.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_mapReady) {
      _mapController.dispose();
    }
    super.dispose();
  }

  Future<void> _getUserLocation() async {
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
        final street = place.street ?? '';
        final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
        
        String address;
        if (street.isNotEmpty && locality.isNotEmpty) {
          address = '$street, $locality';
        } else if (locality.isNotEmpty) {
          address = locality;
        } else if (street.isNotEmpty) {
          address = street;
        } else {
          address = 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
        }
        
        setState(() {
          _currentLocationName = address;
        });
      }
    } catch (e) {
      // Silently fall back to coordinates if geocoding fails
      if (mounted) {
        setState(() {
          _currentLocationName = 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
        });
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

  Future<void> _drawRoute(LocationData destination) async {
    final LatLng destinationLatLng = LatLng(destination.latitude, destination.longitude);
    
    try {
      // Get street address for the destination
      String destinationAddress = destination.address;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          destination.latitude,
          destination.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          final street = place.street ?? '';
          final locality = place.locality ?? place.subLocality ?? place.administrativeArea ?? '';
          
          if (street.isNotEmpty && locality.isNotEmpty) {
            destinationAddress = '$street, $locality';
          } else if (locality.isNotEmpty) {
            destinationAddress = locality;
          } else if (street.isNotEmpty) {
            destinationAddress = street;
          }
        }
      } catch (e) {
        // Use the provided address if geocoding fails
      }
      
      final directionsData = await _directionsService.getDirections(
        origin: _currentLocation,
        destination: destinationLatLng,
      );

      if (directionsData != null && mounted) {
        final polylineCoordinates = directionsData['polylineCoordinates'] as List<LatLng>;
        
        setState(() {
          _polylines.clear();
          
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylineCoordinates,
              color: Colors.blue,
              width: 5,
            ),
          );

          _routeDistance = directionsData['distance'] as String?;
          _routeDuration = directionsData['duration'] as String?;
          _destinationName = destinationAddress;

          _markers.removeWhere((marker) => marker.markerId.value == 'destination');
          _markers.add(
            Marker(
              markerId: const MarkerId('destination'),
              position: destinationLatLng,
              infoWindow: InfoWindow(
                title: 'Destination',
                snippet: destinationAddress,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            ),
          );
        });

        _fitMapToBounds(polylineCoordinates);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error drawing route: $e')),
        );
      }
    }
  }

  void _fitMapToBounds(List<LatLng> coordinates) {
    if (coordinates.isEmpty || !_mapReady) return;

    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (var coord in coordinates) {
      if (coord.latitude < minLat) minLat = coord.latitude;
      if (coord.latitude > maxLat) maxLat = coord.latitude;
      if (coord.longitude < minLng) minLng = coord.longitude;
      if (coord.longitude > maxLng) maxLng = coord.longitude;
    }

    _mapController.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100,
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _polylines.clear();
      _routeDistance = null;
      _routeDuration = null;
      _destinationName = '';
      _markers.removeWhere((marker) => marker.markerId.value == 'destination');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveTransaction = widget.activeTransaction != null && 
                                      widget.activeTransaction!.sellerLocation != null &&
                                      widget.activeTransaction!.locationSharingEnabled;
    
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _mapReady = true;
              _mapController.animateCamera(
                CameraUpdate.newLatLngZoom(_currentLocation, 15),
              );
              _getUserLocation().then((_) {
                if (hasActiveTransaction) {
                  _handleTransactionUpdate();
                }
                if (_showScavengerHunt) {
                  _updateScavengerHuntMarkers();
                }
                // Handle shared location if any
                if (widget.sharedLocation != null) {
                  _handleSharedLocation();
                }
              });
            },
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          if (hasActiveTransaction)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Current Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentLocationName.isNotEmpty
                                      ? _currentLocationName
                                      : 'Getting location...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Destination
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _destinationName.isNotEmpty
                                      ? _destinationName
                                      : widget.activeTransaction!.sellerLocation!.address,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_routeDistance != null && _routeDuration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDistance!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.grey[300],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDuration!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else if (widget.sharedLocation != null && _destinationName.isNotEmpty)
            // Shared location info card
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Current Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _currentLocationName.isNotEmpty
                                      ? _currentLocationName
                                      : 'Getting location...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Destination
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3864FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _destinationName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      if (_routeDistance != null && _routeDuration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDistance!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: Colors.grey[300],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: Color(0xFF3864FF)),
                                    const SizedBox(width: 6),
                                    Text(
                                      _routeDuration!,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Only current location (no destination)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3864FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentLocationName.isNotEmpty
                                  ? _currentLocationName
                                  : 'Getting location...',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Scavenger hunt legend
          if (_showScavengerHunt && _scavengerHuntItems.isNotEmpty)
            Positioned(
              bottom: 150,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Scavenger Hunt',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _legendItem(Colors.orange, 'Available'),
                    const SizedBox(height: 4),
                    _legendItem(Colors.green, 'Yours'),
                    const SizedBox(height: 4),
                    _legendItem(Colors.red, 'Claimed'),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              children: [
                // Scavenger hunt toggle button
                FloatingActionButton(
                  heroTag: 'toggleScavengerHunt',
                  backgroundColor: _showScavengerHunt ? const Color(0xFF3864FF) : Colors.white,
                  mini: true,
                  child: Icon(
                    Icons.card_giftcard,
                    color: _showScavengerHunt ? Colors.white : Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _showScavengerHunt = !_showScavengerHunt;
                      if (_showScavengerHunt) {
                        _updateScavengerHuntMarkers();
                      } else {
                        // Remove scavenger hunt markers
                        _markers.removeWhere((marker) => 
                          marker.markerId.value.startsWith('scavenger_'));
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoomIn',
                  backgroundColor: Colors.white,
                  mini: true,
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
                  mini: true,
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
                  mini: true,
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

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

