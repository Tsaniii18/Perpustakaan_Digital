import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/location_service.dart';

class LocationScreen extends StatefulWidget {
  static const routeName = '/location';
  const LocationScreen({Key? key}) : super(key: key);

  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  bool _isLoading = true;
  bool _isLoadingPlaces = false;
  bool _showLibraries = true;
  bool _showCafes = false;
  String _errorMessage = '';
  bool _mapInitialized = false;
  
  // Default position (Jakarta)
  final LatLng _defaultPosition = const LatLng(-6.2088, 106.8456);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _getCurrentLocation());
  }
  
  @override
  void dispose() {
    _mapController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _mapController != null) {
      _mapController?.dispose();
      _mapController = null;
      _mapInitialized = false;
      setState(() {});
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check location services and permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Layanan lokasi tidak diaktifkan. Mohon aktifkan di pengaturan perangkat.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Izin lokasi ditolak. Aplikasi memerlukan izin lokasi untuk peta.';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Izin lokasi ditolak secara permanen. Silakan aktifkan di pengaturan.';
        });
        return;
      }

      // Get position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          if (mounted) setState(() {
            _isLoading = false;
            _currentPosition = null;
          });
          _updateMarkersWithDefault();
          return;
        }
      }
      
      if (mounted) setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
      
      _fetchNearbyPlaces();
    } catch (e) {
      if (mounted) setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak dapat mengakses lokasi: $e';
      });
      _updateMarkersWithDefault();
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    if (!mounted) return;
    setState(() => _isLoadingPlaces = true);
    
    try {
      final position = _currentPosition ?? Position(
        longitude: _defaultPosition.longitude,
        latitude: _defaultPosition.latitude,
        timestamp: DateTime.now(),
        accuracy: 0, altitude: 0, heading: 0, speed: 0,
        speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
      );
      
      if (_showLibraries) await _locationService.fetchNearbyLibraries(position);
      if (_showCafes) await _locationService.fetchNearbyCafes(position);
      
      _updateMarkers();
    } catch (e) {
      print('Error fetching places: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPlaces = false);
    }
  }

  void _updateMarkers() {
    final position = _currentPosition ?? Position(
      longitude: _defaultPosition.longitude,
      latitude: _defaultPosition.latitude,
      timestamp: DateTime.now(),
      accuracy: 0, altitude: 0, heading: 0, speed: 0,
      speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
    );
    
    _updateMarkersWithPosition(position);
  }
  
  void _updateMarkersWithDefault() => _updateMarkersWithPosition(
    Position(
      longitude: _defaultPosition.longitude,
      latitude: _defaultPosition.latitude,
      timestamp: DateTime.now(),
      accuracy: 0, altitude: 0, heading: 0, speed: 0,
      speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
    )
  );
  
  void _updateMarkersWithPosition(Position position) {
    if (!mounted) return;
    
    Set<Marker> markers = {
      // Current location marker
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(position.latitude, position.longitude),
        infoWindow: const InfoWindow(title: 'Lokasi Anda'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      )
    };
    
    // Add library markers
    if (_showLibraries) {
      final libraries = _locationService.getNearbyLibraries(position);
      
      for (int i = 0; i < libraries.length; i++) {
        final place = libraries[i];
        markers.add(
          Marker(
            markerId: MarkerId('library_$i'),
            position: LatLng(place['lat'], place['lng']),
            infoWindow: InfoWindow(
              title: place['name'],
              snippet: '${place['distance']} • ${place['address']}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    }
    
    // Add cafe markers
    if (_showCafes) {
      final cafes = _locationService.getNearbyCafes(position);
      
      for (int i = 0; i < cafes.length; i++) {
        final cafe = cafes[i];
        markers.add(
          Marker(
            markerId: MarkerId('cafe_$i'),
            position: LatLng(cafe['lat'], cafe['lng']),
            infoWindow: InfoWindow(
              title: cafe['name'],
              snippet: '${cafe['distance']} • ${cafe['address']}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }
    }
    
    setState(() => _markers = markers);
  }

  void _moveToCurrentLocation() {
    if (_mapController == null) return;
    
    final target = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultPosition;
        
    _mapController!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: 14),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lokasi Membaca'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _moveToCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : Column(
                  children: [
                    // Title and description
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      width: double.infinity,
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Temukan Tempat Membaca Favorit Anda',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Berikut daftar perpustakaan dan cafe terdekat untuk menikmati buku favorit Anda.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    
                    // Filter Options
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilterChip(
                              label: const Text('Perpustakaan'),
                              selected: _showLibraries,
                              onSelected: (selected) {
                                setState(() => _showLibraries = selected);
                                if (selected) _fetchNearbyPlaces();
                                else _updateMarkers();
                              },
                              avatar: const Icon(Icons.local_library),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilterChip(
                              label: const Text('Cafe Literasi'),
                              selected: _showCafes,
                              onSelected: (selected) {
                                setState(() => _showCafes = selected);
                                if (selected) _fetchNearbyPlaces();
                                else _updateMarkers();
                              },
                              avatar: const Icon(Icons.local_cafe),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (_isLoadingPlaces) const LinearProgressIndicator(),
                    
                    // Map
                    Expanded(child: _buildGoogleMap()),
                    
                    // Legend
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Text(
                              'Legenda Peta:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildLegendItem('Lokasi Anda', BitmapDescriptor.hueAzure),
                              if (_showLibraries) _buildLegendItem('Perpustakaan', BitmapDescriptor.hueGreen),
                              if (_showCafes) _buildLegendItem('Cafe Literasi', BitmapDescriptor.hueOrange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildGoogleMap() {
    try {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentPosition != null
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : _defaultPosition,
          zoom: 14,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (GoogleMapController controller) {
          setState(() {
            _mapController = controller;
            _mapInitialized = true;
          });
          
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _markers.isEmpty) _updateMarkers();
          });
        },
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('Tidak dapat menampilkan peta'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _mapController = null;
                  _mapInitialized = false;
                });
                _getCurrentLocation();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              onPressed: _getCurrentLocation,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _errorMessage = '';
                  _currentPosition = null;
                });
                _updateMarkersWithDefault();
              },
              child: const Text('Gunakan Lokasi Default'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, double hue) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: HSLColor.fromAHSL(1.0, hue, 1.0, 0.5).toColor(),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}