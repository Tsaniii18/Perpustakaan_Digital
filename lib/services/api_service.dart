import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class ApiService {
  final String baseUrl = 'https://gutendex.com/books';
  static const int TOTAL_BOOKS_LIMIT = 40; 
  static const int PREMIUM_BOOKS_COUNT = 20;
  
  // Memory cache untuk data dan kategori
  static Map<String, dynamic>? _cachedData;
  static List<String>? _cachedCategories;
  
  // Cache keys
  static const String BOOKS_CACHE_KEY = 'books_cache';
  static const String BOOKS_CACHE_TIMESTAMP_KEY = 'books_cache_timestamp';
  static const String CATEGORIES_CACHE_KEY = 'categories_cache';
  static const String DETAIL_CACHE_PREFIX = 'book_detail_';
  
  // Cache TTL (1 jam)
  static const int CACHE_TTL = 3600000;
  
  // Map untuk menyimpan cache detail buku di memory
  static Map<int, Book> _bookDetailsCache = {};
  
  // Fetch books dengan caching dan parameter
  Future<Map<String, dynamic>> fetchBooks({
    int page = 1,
    String? searchQuery,
    String? category,
    bool? isPremium,
  }) async {
    try {
      // Cache key yang unik berdasarkan parameter
      String cacheKey = '$BOOKS_CACHE_KEY-$page-${searchQuery ?? ''}-${category ?? ''}-${isPremium?.toString() ?? ''}';
      
      // Cek cache di memory terlebih dahulu
      if (_cachedData != null) {
        return _cachedData!;
      }
      
      // Cek cache di SharedPreferences
      bool shouldUseCache = await _shouldUseCache(cacheKey);
      if (shouldUseCache) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        String? cachedJson = prefs.getString(cacheKey);
        
        if (cachedJson != null) {
          Map<String, dynamic> cachedData = json.decode(cachedJson);
          // Simpan di memory cache
          _cachedData = cachedData;
          return cachedData;
        }
      }
      
      // Jika tidak ada cache atau cache expired, fetch dari API
      final int itemsPerPage = 30;
      
      // Buat URL dengan parameter
      String url = '$baseUrl?page=$page&limit=$itemsPerPage';
      
      // Tambahkan parameter pencarian jika ada
      if (searchQuery != null && searchQuery.isNotEmpty) {
        url += '&search=$searchQuery';
      }
      
      // Tambahkan parameter kategori jika ada
      if (category != null && category.isNotEmpty) {
        url += '&topic=$category';
      }
      
      // Lakukan request API
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        List<dynamic> results = data['results'];
        
        // Tentukan buku mana yang premium (20% dari setiap halaman)
        int premiumCount = (results.length * 0.2).round();
        for (int i = 0; i < results.length; i++) {
          // Buku terakhir dalam hasil adalah premium
          bool isPremiumBook = i >= (results.length - premiumCount);
          
          // Tambahkan flag isPremium ke hasil
          results[i]['isPremium'] = isPremiumBook;
          
          // Tambahkan harga koin jika premium
          if (isPremiumBook) {
            results[i]['coinPrice'] = ((results[i]['id'] % 3) + 1) * 10;
          }
        }
        
        // Filter buku premium jika parameter isPremium ada
        if (isPremium != null) {
          results = results.where((book) => book['isPremium'] == isPremium).toList();
        }
        
        // Update data dengan hasil yang sudah difilter
        data['results'] = results;
        
        // Cache data ke SharedPreferences
        _saveCache(cacheKey, data);
        
        // Simpan di memory cache
        _cachedData = Map.from(data);
        
        return data;
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching books: $e');
      throw Exception('Error fetching books: $e');
    }
  }
  
  Future<Book> fetchBookDetail(int bookId) async {
    try {
      // Cek cache di memory terlebih dahulu
      if (_bookDetailsCache.containsKey(bookId)) {
        return _bookDetailsCache[bookId]!;
      }
      
      // Cek cache di SharedPreferences
      String cacheKey = '$DETAIL_CACHE_PREFIX$bookId';
      bool shouldUseCache = await _shouldUseCache(cacheKey);
      
      if (shouldUseCache) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        String? cachedJson = prefs.getString(cacheKey);
        
        if (cachedJson != null) {
          Map<String, dynamic> cachedData = json.decode(cachedJson);
          Book book = Book.fromJson(cachedData, forcePremium: cachedData['isPremium'] ?? false);
          
          // Simpan di memory cache
          _bookDetailsCache[bookId] = book;
          
          return book;
        }
      }
      
      // Jika tidak ada cache atau cache expired, fetch dari API
      final response = await http.get(Uri.parse('$baseUrl/$bookId'));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Tentukan apakah buku ini premium berdasarkan ID
        bool isPremium = bookId % 5 == 0;
        data['isPremium'] = isPremium;
        
        // Tambahkan harga koin jika premium
        if (isPremium) {
          data['coinPrice'] = ((bookId % 3) + 1) * 10;
        }
        
        // Cache data ke SharedPreferences
        _saveCache(cacheKey, data);
        
        Book book = Book.fromJson(data, forcePremium: isPremium);
        
        // Simpan di memory cache
        _bookDetailsCache[bookId] = book;
        
        return book;
      } else {
        throw Exception('Failed to load book details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching book details: $e');
      throw Exception('Error fetching book details: $e');
    }
  }
  
  Future<List<String>> fetchCategories() async {
    // Gunakan cache jika sudah ada di memory
    if (_cachedCategories != null && _cachedCategories!.isNotEmpty) {
      return _cachedCategories!;
    }
    
    // Cek cache di SharedPreferences
    bool shouldUseCache = await _shouldUseCache(CATEGORIES_CACHE_KEY);
    if (shouldUseCache) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedJson = prefs.getString(CATEGORIES_CACHE_KEY);
      
      if (cachedJson != null) {
        List<dynamic> cachedData = json.decode(cachedJson);
        List<String> categories = cachedData.map((e) => e.toString()).toList();
        
        // Simpan di memory cache
        _cachedCategories = categories;
        
        return categories;
      }
    }
    
    try {
      final response = await http.get(Uri.parse('$baseUrl?languages=en'));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        List<dynamic> results = data['results'];
        
        // Kumpulkan semua subject dari hasil
        Set<String> categories = {};
        for (var book in results) {
          if (book['subjects'] != null) {
            for (var subject in book['subjects']) {
              if (subject.toString().length > 3 && subject.toString().length < 20) {
                categories.add(subject.toString());
              }
            }
          }
        }
        
        // Ambil 8 kategori teratas
        final categoriesList = categories.take(8).toList();
        
        // Cache data ke SharedPreferences
        _saveCache(CATEGORIES_CACHE_KEY, categoriesList);
        
        // Simpan di memory cache
        _cachedCategories = categoriesList;
        
        return categoriesList;
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching categories: $e');
      throw Exception('Error fetching categories: $e');
    }
  }
  
  // Invalidate cache untuk refresh data
  Future<void> invalidateCache() async {
    _cachedData = null;
    _bookDetailsCache.clear();
    
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Clear cache data
    List<String> keys = prefs.getKeys().where((key) => 
      key.startsWith(BOOKS_CACHE_KEY) || 
      key.startsWith(DETAIL_CACHE_PREFIX)
    ).toList();
    
    for (String key in keys) {
      prefs.remove(key);
      prefs.remove('${key}_timestamp');
    }
  }
  
  // Helper untuk memeriksa apakah cache masih valid
  Future<bool> _shouldUseCache(String cacheKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int? timestamp = prefs.getInt('${cacheKey}_timestamp');
    
    if (timestamp == null) return false;
    
    int now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) < CACHE_TTL;
  }
  
  // Helper untuk menyimpan data ke cache
  Future<void> _saveCache(String key, dynamic data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Simpan data
    await prefs.setString(key, json.encode(data));
    
    // Simpan timestamp
    int now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('${key}_timestamp', now);
  }
  
  // Clear specific book detail cache
  void clearBookDetailCache(int bookId) {
    _bookDetailsCache.remove(bookId);
  }
}