import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_helper.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  DatabaseHelper _dbHelper = DatabaseHelper();
  
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  
  AuthProvider() {
    _loadUserFromPrefs();
  }
  
  Future<void> _loadUserFromPrefs() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? userId = prefs.getInt('user_id');
      
      if (userId != null) {
        _currentUser = await _dbHelper.getUserById(userId);
      }
    } catch (e) {
      print('Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> register(String email, String password, String username, String profileImage) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Cek apakah email sudah terdaftar
      User? existingUser = await _dbHelper.getUserByEmail(email);
      if (existingUser != null) {
        return false;
      }
      
      // Hash password
      String hashedPassword = _dbHelper.hashPassword(password);
      
      // Buat user baru
      User newUser = User(
        email: email,
        passwordHash: hashedPassword,
        username: username,
        profileImage: profileImage, // Foto profil yang dipilih user
        coins: 100, // Berikan 100 koin gratis untuk pengguna baru
      );
      
      // Simpan user ke database
      int userId = await _dbHelper.insertUser(newUser);
      _currentUser = await _dbHelper.getUserById(userId);
      
      // Simpan user ID ke shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);
      
      return true;
    } catch (e) {
      print('Registration error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      User? user = await _dbHelper.authenticateUser(email, password);
      
      if (user != null) {
        _currentUser = user;
        
        // Simpan user ID ke shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', user.id!);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _currentUser = null;
      
      // Hapus user ID dari shared preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> updateProfile(String username, String profileImage) async {
    if (_currentUser == null) return false;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      User updatedUser = _currentUser!.copyWith(
        username: username,
        profileImage: profileImage,
      );
      
      await _dbHelper.updateUser(updatedUser);
      _currentUser = updatedUser;
      
      return true;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateUserCoins(int coins) async {
    if (_currentUser == null) return;
    
    try {
      await _dbHelper.updateUserCoins(_currentUser!.id!, coins);
      _currentUser = _currentUser!.copyWith(coins: coins);
      notifyListeners();
    } catch (e) {
      print('Update coins error: $e');
    }
  }
}