import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Cache variables
  Position? _lastPosition;
  DateTime? _lastPositionTime;
  List<Map<String, dynamic>>? _cachedLibraries;
  List<Map<String, dynamic>>? _cachedCafes;
  DateTime? _librariesCacheTime;
  DateTime? _cafesCacheTime;
  
  static const String _apiKey = 'AIzaSyAeNfe1EDwsUnHaaoTMBcv1oysltaJDR5U';
  static const int _cacheTtlMinutes = 60;

  Future<bool> requestPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      
      if (permission == LocationPermission.deniedForever) return false;
      
      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  Future<Position?> getCurrentLocation({bool useCache = true}) async {
    final now = DateTime.now();
    if (useCache && _lastPosition != null && _lastPositionTime != null &&
        now.difference(_lastPositionTime!).inMinutes < 5) {
      return _lastPosition;
    }

    try {
      if (!await requestPermission()) return null;
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      
      _lastPosition = position;
      _lastPositionTime = now;
      return position;
    } catch (e) {
      print('Error getting current location: $e');
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _lastPosition = lastKnown;
          _lastPositionTime = now;
          return lastKnown;
        }
      } catch (e2) {}
      return null;
    }
  }

  // Fetch libraries from Google Places API or dummy data
  Future<void> fetchNearbyLibraries(Position position) async {
    final now = DateTime.now();
    if (_cachedLibraries != null && _librariesCacheTime != null &&
        now.difference(_librariesCacheTime!).inMinutes < _cacheTtlMinutes) {
      return;
    }
    
    try {
      if (_apiKey == 'YOUR_API_KEY_HERE') {
        _cachedLibraries = _getDummyLibraries(position);
        _librariesCacheTime = now;
        return;
      }
      
      final libraries = await _fetchFromPlacesApi(position, 'library', 3000);
      
      if (libraries.isNotEmpty) {
        _cachedLibraries = libraries;
      } else {
        _cachedLibraries = _getDummyLibraries(position);
      }
      _librariesCacheTime = now;
    } catch (e) {
      print('Error fetching libraries: $e');
      _cachedLibraries = _getDummyLibraries(position);
      _librariesCacheTime = now;
    }
  }

  // Fetch cafes from Google Places API or dummy data
  Future<void> fetchNearbyCafes(Position position) async {
    final now = DateTime.now();
    if (_cachedCafes != null && _cafesCacheTime != null &&
        now.difference(_cafesCacheTime!).inMinutes < _cacheTtlMinutes) {
      return;
    }
    
    try {
      if (_apiKey == 'YOUR_API_KEY_HERE') {
        _cachedCafes = _getDummyCafes(position);
        _cafesCacheTime = now;
        return;
      }
      
      final cafes = await _fetchFromPlacesApi(position, 'cafe', 3000);
      
      if (cafes.isNotEmpty) {
        _cachedCafes = cafes;
      } else {
        _cachedCafes = _getDummyCafes(position);
      }
      _cafesCacheTime = now;
    } catch (e) {
      print('Error fetching cafes: $e');
      _cachedCafes = _getDummyCafes(position);
      _cafesCacheTime = now;
    }
  }

  // Fetch data from Google Places API
  Future<List<Map<String, dynamic>>> _fetchFromPlacesApi(
    Position position, 
    String type, 
    int radius
  ) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=${position.latitude},${position.longitude}'
      '&radius=$radius'
      '&type=$type'
      '&key=$_apiKey'
    );
    
    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          List<dynamic> results = data['results'];
          List<Map<String, dynamic>> places = [];
          
          for (var place in results) {
            final lat = place['geometry']['location']['lat'];
            final lng = place['geometry']['location']['lng'];
            final distanceKm = _calculateDistance(
              position.latitude, position.longitude, lat, lng
            );
            
            places.add({
              'name': place['name'],
              'distance': '${distanceKm.toStringAsFixed(1)} km',
              'address': place['vicinity'] ?? 'Alamat tidak tersedia',
              'rating': place['rating'] ?? 4.0,
              'lat': lat,
              'lng': lng,
            });
          }
          
          places.sort((a, b) {
            final distanceA = double.parse(a['distance'].split(' ')[0]);
            final distanceB = double.parse(b['distance'].split(' ')[0]);
            return distanceA.compareTo(distanceB);
          });
          
          return places;
        }
      }
    } catch (e) {
      print('Places API error: $e');
    }
    
    return [];
  }

  // Get nearby libraries (cached or dummy)
  List<Map<String, dynamic>> getNearbyLibraries(Position position) {
    return _cachedLibraries != null 
        ? _updateDistances(_cachedLibraries!, position)
        : _getDummyLibraries(position);
  }

  // Get nearby cafes (cached or dummy)
  List<Map<String, dynamic>> getNearbyCafes(Position position) {
    return _cachedCafes != null 
        ? _updateDistances(_cachedCafes!, position)
        : _getDummyCafes(position);
  }
  
  // Dummy data for libraries
  List<Map<String, dynamic>> _getDummyLibraries(Position position) {
    return [
      {
        'name': 'Perpustakaan Nasional',
        'distance': '1.2 km',
        'address': 'Jl. Merdeka No. 11',
        'rating': 4.5,
        'lat': position.latitude + 0.01,
        'lng': position.longitude + 0.01,
      },
      {
        'name': 'Perpustakaan Kota',
        'distance': '2.3 km',
        'address': 'Jl. Pemuda No. 45',
        'rating': 4.2,
        'lat': position.latitude - 0.01,
        'lng': position.longitude - 0.01,
      },
      {
        'name': 'Taman Bacaan Masyarakat',
        'distance': '3.7 km',
        'address': 'Jl. Pendidikan No. 78',
        'rating': 4.0,
        'lat': position.latitude + 0.02,
        'lng': position.longitude - 0.02,
      },
      {
        'name': 'Reading Corner',
        'distance': '1.8 km',
        'address': 'Jl. Literasi No. 25',
        'rating': 4.3,
        'lat': position.latitude - 0.015,
        'lng': position.longitude + 0.025,
      },
    ];
  }
  
  // Dummy data for cafes
  List<Map<String, dynamic>> _getDummyCafes(Position position) {
    return [
      {
        'name': 'Book Cafe',
        'distance': '0.8 km',
        'address': 'Jl. Sudirman No. 321',
        'rating': 4.4,
        'lat': position.latitude - 0.008,
        'lng': position.longitude + 0.008,
      },
      {
        'name': 'Literasi Coffee',
        'distance': '1.5 km',
        'address': 'Jl. Gajah Mada No. 654',
        'rating': 4.6,
        'lat': position.latitude + 0.015,
        'lng': position.longitude + 0.015,
      },
      {
        'name': 'Reader\'s Spot',
        'distance': '2.2 km',
        'address': 'Jl. Ahmad Yani No. 987',
        'rating': 4.1,
        'lat': position.latitude - 0.022,
        'lng': position.longitude - 0.022,
      },
      {
        'name': 'Page & Brew',
        'distance': '1.9 km',
        'address': 'Jl. Diponegoro No. 112',
        'rating': 4.7,
        'lat': position.latitude + 0.018,
        'lng': position.longitude - 0.012,
      },
    ];
  }
  
  // Update distances based on current position
  List<Map<String, dynamic>> _updateDistances(
    List<Map<String, dynamic>> places, 
    Position position
  ) {
    for (var place in places) {
      final distanceKm = _calculateDistance(
        position.latitude, position.longitude, 
        place['lat'], place['lng']
      );
      place['distance'] = '${distanceKm.toStringAsFixed(1)} km';
    }
    
    places.sort((a, b) {
      final distanceA = double.parse(a['distance'].split(' ')[0]);
      final distanceB = double.parse(b['distance'].split(' ')[0]);
      return distanceA.compareTo(distanceB);
    });
    
    return places;
  }
  
  // Calculate distance using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.sin(dLon / 2) * math.sin(dLon / 2) * 
              math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2));
    final c = 2 * math.asin(math.sqrt(a));
    
    return (radius * c).toDouble();
  }
  
  double _toRadians(double degree) => degree * (math.pi / 180);
  
  void resetCache() {
    _lastPosition = null;
    _lastPositionTime = null;
    _cachedLibraries = null;
    _cachedCafes = null;
    _librariesCacheTime = null;
    _cafesCacheTime = null;
  }
}