import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/favorite.dart';
import '../models/purchased_book.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';

class BookProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<Book> _books = [];
  List<Book> _filteredBooks = [];
  List<Favorite> _favorites = [];
  List<PurchasedBook> _purchasedBooks = [];
  List<String> _categories = [];
  
  bool _isLoading = false;
  bool _hasMoreBooks = true;
  String _errorMessage = '';
  int _currentPage = 1;
  
  String? _searchQuery;
  String? _selectedCategory;
  bool? _isPremiumFilter;
  
  // PERBAIKAN: Maps untuk tracking status dengan expiry time
  Map<int, Map<String, dynamic>> _favoriteStatusCache = {};
  Map<int, Map<String, dynamic>> _purchaseStatusCache = {};
  
  // Cache TTL dalam milidetik (5 menit)
  static const int _statusCacheTtl = 300000;
  
  List<Book> get books => _filteredBooks;
  List<Favorite> get favorites => _favorites;
  List<PurchasedBook> get purchasedBooks => _purchasedBooks;
  List<String> get categories => _categories;
  
  bool get isLoading => _isLoading;
  bool get hasMoreBooks => _hasMoreBooks;
  String get errorMessage => _errorMessage;
  
  String? get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  bool? get isPremiumFilter => _isPremiumFilter;
  
  // Penanda apakah sudah memuat data atau belum
  bool _hasLoadedInitialData = false;
  bool get hasLoadedInitialData => _hasLoadedInitialData;
  
  // METODE BARU: Cek apakah cache masih valid
  bool _isCacheValid(Map<String, dynamic> cacheEntry) {
    if (cacheEntry.isEmpty) return false;
    
    int timestamp = cacheEntry['timestamp'] ?? 0;
    int now = DateTime.now().millisecondsSinceEpoch;
    
    return (now - timestamp) < _statusCacheTtl;
  }
  
  // METODE BARU: Simpan status ke cache dengan timestamp
  void _setCacheStatus(Map<int, Map<String, dynamic>> cache, int key, bool status) {
    cache[key] = {
      'status': status,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  // METODE BARU: Ambil status dari cache
  bool? _getCacheStatus(Map<int, Map<String, dynamic>> cache, int key) {
    if (!cache.containsKey(key)) return null;
    
    Map<String, dynamic> cacheEntry = cache[key]!;
    if (!_isCacheValid(cacheEntry)) {
      cache.remove(key);
      return null;
    }
    
    return cacheEntry['status'] as bool?;
  }

  Future<void> fetchBooks({bool refresh = false, bool showLoading = true}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreBooks = true;
    }
    
    if (_isLoading || (!_hasMoreBooks && !refresh)) return;
    
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    
    _errorMessage = '';
    
    try {
      final Map<String, dynamic> data = await _apiService.fetchBooks(
        page: _currentPage,
        searchQuery: _searchQuery,
        category: _selectedCategory,
        isPremium: _isPremiumFilter,
      );
      
      List<dynamic> results = data['results'];
      List<Book> newBooks = [];
      
      for (var item in results) {
        // Convert each result to a Book object
        if (item is Book) {
          newBooks.add(item);
        } else {
          // If the result is not already a Book (e.g. it's a Map), convert it
          newBooks.add(Book.fromJson(item, forcePremium: item['isPremium'] ?? false));
        }
      }
      
      if (refresh) {
        _books = newBooks;
        // PERBAIKAN: Clear cache saat refresh
        _favoriteStatusCache.clear();
        _purchaseStatusCache.clear();
      } else {
        _books.addAll(newBooks);
      }
      
      _filteredBooks = List.from(_books);
      _hasMoreBooks = data['next'] != null;
      _currentPage++;
      _hasLoadedInitialData = true;
    } catch (e) {
      _errorMessage = 'Error fetching books: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> fetchCategories() async {
    if (_categories.isNotEmpty) return;
    
    try {
      _categories = await _apiService.fetchCategories();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching categories: $e';
      print(_errorMessage);
    }
  }
  
  // Debounced search
  void setSearchQuery(String? query) {
    _searchQuery = query;
    // Notifies listeners only, actual fetch happens in debounced fetch
    notifyListeners();
  }
  
  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    // Notifies listeners only, actual fetch happens in caller
    notifyListeners();
  }
  
  void setIsPremiumFilter(bool? isPremium) {
    _isPremiumFilter = isPremium;
    // Notifies listeners only, actual fetch happens in caller
    notifyListeners();
  }
  
  // Favorite Methods - DIPERBAIKI
  Future<void> fetchFavorites(int userId) async {
    try {
      print('📖 Fetching favorites for user $userId');
      List<Favorite> fetchedFavorites = await _dbHelper.getFavoritesByUserId(userId);
      print('❤️ Fetched ${fetchedFavorites.length} favorites');
      _favorites = fetchedFavorites;
      
      // PERBAIKAN: Update cache dengan timestamp
      _favoriteStatusCache.clear();
      for (var fav in _favorites) {
        _setCacheStatus(_favoriteStatusCache, fav.bookId, true);
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching favorites: $e';
      print(_errorMessage);
      // Return empty list instead of throwing
      _favorites = [];
      notifyListeners();
    }
  }
  
  Future<bool> toggleFavorite(int userId, Book book) async {
    try {
      print('💖 Toggling favorite for book ${book.id}');
      bool isFav = await isFavorite(userId, book.id);
      
      if (isFav) {
        print('🗑️ Removing from favorites');
        await _dbHelper.deleteFavorite(userId, book.id);
        _favorites.removeWhere((fav) => fav.bookId == book.id);
        _setCacheStatus(_favoriteStatusCache, book.id, false);
      } else {
        print('➕ Adding to favorites');
        Favorite newFavorite = Favorite(
          userId: userId,
          bookId: book.id,
          title: book.title,
          author: book.authors.isNotEmpty ? book.authors[0] : 'Unknown',
          coverImage: book.coverImage,
        );
        
        await _dbHelper.insertFavorite(newFavorite);
        _favorites.add(newFavorite);
        _setCacheStatus(_favoriteStatusCache, book.id, true);
      }
      
      notifyListeners();
      return !isFav;
    } catch (e) {
      _errorMessage = 'Error toggling favorite: $e';
      print(_errorMessage);
      return false;
    }
  }
  
  // DIPERBAIKI: Cek favorit dengan cache yang lebih baik
  Future<bool> isFavorite(int userId, int bookId) async {
    try {
      // Check cache first
      bool? cachedStatus = _getCacheStatus(_favoriteStatusCache, bookId);
      if (cachedStatus != null) {
        print('📋 Favorite status from cache for book $bookId: $cachedStatus');
        return cachedStatus;
      }
      
      // If not in cache or cache expired, check database
      print('🔍 Checking favorite status in database for book $bookId');
      bool status = await _dbHelper.isFavorite(userId, bookId);
      
      // Update cache
      _setCacheStatus(_favoriteStatusCache, bookId, status);
      
      print('💾 Cached favorite status for book $bookId: $status');
      return status;
    } catch (e) {
      _errorMessage = 'Error checking favorite status: $e';
      print('❌ Error checking favorite status: $e');
      return false;
    }
  }
  
  // Purchased Books Methods - DIPERBAIKI
  Future<void> fetchPurchasedBooks(int userId) async {
    try {
      print('🛒 Fetching purchased books for user $userId');
      List<PurchasedBook> fetchedBooks = await _dbHelper.getPurchasedBooksByUserId(userId);
      print('📚 Fetched ${fetchedBooks.length} purchased books');
      _purchasedBooks = fetchedBooks;
      
      // PERBAIKAN: Update cache dengan timestamp
      _purchaseStatusCache.clear();
      for (var book in _purchasedBooks) {
        _setCacheStatus(_purchaseStatusCache, book.bookId, true);
      }
      
      print('💾 Updated purchase cache with ${_purchaseStatusCache.length} entries');
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching purchased books: $e';
      print('❌ Error fetching purchased books: $e');
      // Return empty list instead of throwing
      _purchasedBooks = [];
      notifyListeners();
    }
  }
  
  Future<bool> purchaseBook(int userId, Book book) async {
    try {
      print('💳 Processing purchase for book ${book.id}');
      
      // PERBAIKAN: Double-check dengan database sebelum purchase
      bool isAlreadyPurchased = await _checkPurchaseInDatabase(userId, book.id);
      
      if (isAlreadyPurchased) {
        print('✅ Book ${book.id} already purchased');
        _setCacheStatus(_purchaseStatusCache, book.id, true);
        return true;
      }
      
      PurchasedBook newPurchase = PurchasedBook(
        userId: userId,
        bookId: book.id,
        title: book.title,
        purchaseDate: DateTime.now(),
      );
      
      print('💾 Inserting new purchase record');
      await _dbHelper.insertPurchasedBook(newPurchase);
      _purchasedBooks.add(newPurchase);
      
      // PERBAIKAN: Update cache dengan timestamp
      _setCacheStatus(_purchaseStatusCache, book.id, true);
      
      print('✅ Purchase completed for book ${book.id}');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error purchasing book: $e';
      print('❌ Error purchasing book: $e');
      return false;
    }
  }
  
  // METODE BARU: Cek pembelian langsung di database
  Future<bool> _checkPurchaseInDatabase(int userId, int bookId) async {
    try {
      bool status = await _dbHelper.isPurchased(userId, bookId);
      print('🔍 Database check for book $bookId: $status');
      return status;
    } catch (e) {
      print('❌ Error checking database: $e');
      return false;
    }
  }
  
  // DIPERBAIKI: Cek pembelian dengan cache yang lebih baik
  Future<bool> isPurchased(int userId, int bookId) async {
    try {
      // Check cache first
      bool? cachedStatus = _getCacheStatus(_purchaseStatusCache, bookId);
      if (cachedStatus != null) {
        print('📋 Purchase status from cache for book $bookId: $cachedStatus');
        
        // PERBAIKAN: Untuk buku premium, lakukan double-check sesekali
        if (cachedStatus == false && ApiService.isPremiumBookStatic(bookId)) {
          // 10% chance untuk double-check database untuk buku premium
          if (DateTime.now().millisecond % 10 == 0) {
            print('🔄 Double-checking premium book $bookId in database');
            bool dbStatus = await _checkPurchaseInDatabase(userId, bookId);
            if (dbStatus != cachedStatus) {
              print('⚠️ Cache mismatch! Updating cache for book $bookId');
              _setCacheStatus(_purchaseStatusCache, bookId, dbStatus);
              return dbStatus;
            }
          }
        }
        
        return cachedStatus;
      }
      
      // If not in cache or cache expired, check database
      print('🔍 Checking purchase status in database for book $bookId');
      bool status = await _checkPurchaseInDatabase(userId, bookId);
      
      // Update cache
      _setCacheStatus(_purchaseStatusCache, bookId, status);
      
      print('💾 Cached purchase status for book $bookId: $status');
      return status;
    } catch (e) {
      _errorMessage = 'Error checking purchase status: $e';
      print('❌ Error checking purchase status: $e');
      return false;
    }
  }
  
  // METODE BARU: Force refresh status untuk buku tertentu
  Future<void> refreshBookStatus(int userId, int bookId) async {
    print('🔄 Force refreshing status for book $bookId');
    
    // Remove from cache
    _favoriteStatusCache.remove(bookId);
    _purchaseStatusCache.remove(bookId);
    
    // Fetch fresh status
    await Future.wait([
      isFavorite(userId, bookId),
      isPurchased(userId, bookId),
    ]);
    
    print('✅ Status refreshed for book $bookId');
  }
  
  // METODE BARU: Clear expired cache entries
  void cleanupExpiredCache() {
    int now = DateTime.now().millisecondsSinceEpoch;
    
    // Clean favorite cache
    _favoriteStatusCache.removeWhere((key, value) {
      int timestamp = value['timestamp'] ?? 0;
      return (now - timestamp) >= _statusCacheTtl;
    });
    
    // Clean purchase cache
    _purchaseStatusCache.removeWhere((key, value) {
      int timestamp = value['timestamp'] ?? 0;
      return (now - timestamp) >= _statusCacheTtl;
    });
    
    print('🧹 Cleaned up expired cache entries');
  }
  
  // Refresh data dengan invalidate cache
  Future<void> refreshData() async {
    // PERBAIKAN: Clear semua cache
    _favoriteStatusCache.clear();
    _purchaseStatusCache.clear();
    
    await _apiService.invalidateCache();
    fetchBooks(refresh: true);
  }
  
  // Clear caches
  void clearBookDetailCache(int bookId) {
    _apiService.clearBookDetailCache(bookId);
    
    // PERBAIKAN: Clear status cache untuk buku ini juga
    _favoriteStatusCache.remove(bookId);
    _purchaseStatusCache.remove(bookId);
  }
  
  // METODE BARU: Debug info
  void printCacheInfo() {
    print('🔍 Cache Info:');
    print('📖 Favorite cache entries: ${_favoriteStatusCache.length}');
    print('🛒 Purchase cache entries: ${_purchaseStatusCache.length}');
    
    cleanupExpiredCache();
    
    print('📖 Favorite cache after cleanup: ${_favoriteStatusCache.length}');
    print('🛒 Purchase cache after cleanup: ${_purchaseStatusCache.length}');
  }
}