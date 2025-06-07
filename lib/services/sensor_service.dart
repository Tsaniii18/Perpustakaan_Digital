import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isListening = false;
  DateTime? _lastShakeTime;
  
  // Cek apakah platform mendukung sensor
  bool get isSensorSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  void listenForShake(Function({bool showNotification}) onShake) {
    if (_isListening || !isSensorSupported) return;
    
    _isListening = true;
    _lastShakeTime = DateTime.now();
    
    try {
      const double shakeThreshold = 200.0;
      // Interval minimum antar shake detection (ms)
      const int cooldownMs = 2000;
      
      // Variabel untuk mendeteksi gerakan tertentu
      int shakeCount = 0;
      DateTime? shakeStartTime;
      
      _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        // Hitung total akselerasi dari 3 sumbu
        double acceleration = event.x * event.x + event.y * event.y + event.z * event.z;
        
        // Cek jika akselerasi melebihi threshold
        if (acceleration > shakeThreshold) {
          DateTime now = DateTime.now();
          
          // Jika belum ada shake start time, buat baru
          if (shakeStartTime == null) {
            shakeStartTime = now;
            shakeCount = 1;
          } 
          // Jika ada shake start time dan masih dalam window waktu 1 detik
          else if (now.difference(shakeStartTime!).inMilliseconds < 1000) {
            shakeCount++;
            
            // Hanya trigger shake jika sudah ada minimal 2 shake dalam 1 detik
            // dan jeda dari shake terakhir sudah cukup
            if (shakeCount >= 4 && 
                (_lastShakeTime == null || 
                 now.difference(_lastShakeTime!).inMilliseconds > cooldownMs)) {
              _lastShakeTime = now;
              // Reset shake tracking
              shakeStartTime = null;
              shakeCount = 0;
              
              // Panggil callback dengan parameter showNotification=true
              onShake(showNotification: true);
            }
          } 
          // Jika shake terlalu lama, reset counter
          else {
            shakeStartTime = now;
            shakeCount = 1;
          }
        }
      });
    } catch (e) {
      _isListening = false;
    }
  }

  void stopListening() {
    _accelerometerSubscription?.cancel();
    _isListening = false;
  }
}