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
  
  // Maps untuk tracking status favorit dan pembelian (cache in-memory)
  Map<int, bool> _favoriteStatus = {};
  Map<int, bool> _purchaseStatus = {};
  
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
  
  // Favorite Methods
  Future<void> fetchFavorites(int userId) async {
    try {
      print('Fetching favorites for user $userId');
      List<Favorite> fetchedFavorites = await _dbHelper.getFavoritesByUserId(userId);
      print('Fetched ${fetchedFavorites.length} favorites');
      _favorites = fetchedFavorites;
      
      // Update the in-memory cache
      _favoriteStatus.clear();
      for (var fav in _favorites) {
        _favoriteStatus[fav.bookId] = true;
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
      print('Toggling favorite for book ${book.id}');
      bool isFav = await isFavorite(userId, book.id);
      
      if (isFav) {
        print('Removing from favorites');
        await _dbHelper.deleteFavorite(userId, book.id);
        _favorites.removeWhere((fav) => fav.bookId == book.id);
        _favoriteStatus[book.id] = false;
      } else {
        print('Adding to favorites');
        Favorite newFavorite = Favorite(
          userId: userId,
          bookId: book.id,
          title: book.title,
          author: book.authors.isNotEmpty ? book.authors[0] : 'Unknown',
          coverImage: book.coverImage,
        );
        
        await _dbHelper.insertFavorite(newFavorite);
        _favorites.add(newFavorite);
        _favoriteStatus[book.id] = true;
      }
      
      notifyListeners();
      return !isFav;
    } catch (e) {
      _errorMessage = 'Error toggling favorite: $e';
      print(_errorMessage);
      return false;
    }
  }
  
  Future<bool> isFavorite(int userId, int bookId) async {
    try {
      // Check in-memory cache first
      if (_favoriteStatus.containsKey(bookId)) {
        return _favoriteStatus[bookId]!;
      }
      
      // If not in cache, check database
      bool status = await _dbHelper.isFavorite(userId, bookId);
      
      // Update cache
      _favoriteStatus[bookId] = status;
      
      return status;
    } catch (e) {
      _errorMessage = 'Error checking favorite status: $e';
      return false;
    }
  }
  
  // Purchased Books Methods
  Future<void> fetchPurchasedBooks(int userId) async {
    try {
      print('Fetching purchased books for user $userId');
      List<PurchasedBook> fetchedBooks = await _dbHelper.getPurchasedBooksByUserId(userId);
      print('Fetched ${fetchedBooks.length} purchased books');
      _purchasedBooks = fetchedBooks;
      
      // Update the in-memory cache
      _purchaseStatus.clear();
      for (var book in _purchasedBooks) {
        _purchaseStatus[book.bookId] = true;
      }
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error fetching purchased books: $e';
      print(_errorMessage);
      // Return empty list instead of throwing
      _purchasedBooks = [];
      notifyListeners();
    }
  }
  
  Future<bool> purchaseBook(int userId, Book book) async {
    try {
      print('Purchasing book ${book.id}');
      bool isAlreadyPurchased = await isPurchased(userId, book.id);
      
      if (isAlreadyPurchased) {
        print('Book already purchased');
        return true;
      }
      
      PurchasedBook newPurchase = PurchasedBook(
        userId: userId,
        bookId: book.id,
        title: book.title,
        purchaseDate: DateTime.now(),
      );
      
      print('Inserting new purchase record');
      await _dbHelper.insertPurchasedBook(newPurchase);
      _purchasedBooks.add(newPurchase);
      _purchaseStatus[book.id] = true;
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error purchasing book: $e';
      print(_errorMessage);
      return false;
    }
  }
  
  Future<bool> isPurchased(int userId, int bookId) async {
    try {
      // Check in-memory cache first
      if (_purchaseStatus.containsKey(bookId)) {
        return _purchaseStatus[bookId]!;
      }
      
      // If not in cache, check database
      bool status = await _dbHelper.isPurchased(userId, bookId);
      
      // Update cache
      _purchaseStatus[bookId] = status;
      
      return status;
    } catch (e) {
      _errorMessage = 'Error checking purchase status: $e';
      return false;
    }
  }
  
  // Refresh data dengan invalidate cache
  Future<void> refreshData() async {
    await _apiService.invalidateCache();
    fetchBooks(refresh: true);
  }
  
  // Clear caches
  void clearBookDetailCache(int bookId) {
    _apiService.clearBookDetailCache(bookId);
  }
}