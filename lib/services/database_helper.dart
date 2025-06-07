import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/transaction.dart';
import '../models/favorite.dart';
import '../models/purchased_book.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    try {
      print('Initializing database...');
      _database = await _initDatabase();
      print('Database initialized successfully');
      return _database!;
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'digital_library.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        username TEXT NOT NULL,
        profile_image TEXT NOT NULL,
        coins INTEGER DEFAULT 0
      )
    ''');

    // Tabel Favorites
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        book_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        cover_image TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tabel Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        coins INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tabel PurchasedBooks
    await db.execute('''
      CREATE TABLE purchased_books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        book_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        purchase_date TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Tabel Cached Books
    await db.execute('''
      CREATE TABLE cached_books (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        authors TEXT NOT NULL,
        subjects TEXT,
        bookshelves TEXT,
        formats TEXT,
        cover_image TEXT,
        is_premium INTEGER NOT NULL DEFAULT 0,
        coin_price INTEGER NOT NULL DEFAULT 0,
        cache_date TEXT NOT NULL
      )
    ''');
  }
  
  // User Methods
  Future<int> insertUser(User user) async {
    Database db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByEmail(String email) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    Database db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> updateUserCoins(int userId, int coins) async {
    Database db = await database;
    return await db.update(
      'users',
      {'coins': coins},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Authentication
  String hashPassword(String password) {
    List<int> bytes = utf8.encode(password);
    Digest digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> authenticateUser(String email, String password) async {
    User? user = await getUserByEmail(email);
    if (user != null) {
      String hashedPassword = hashPassword(password);
      if (user.passwordHash == hashedPassword) {
        return user;
      }
    }
    return null;
  }

  // Favorites Methods
  Future<int> insertFavorite(Favorite favorite) async {
    try {
      print('Inserting favorite: ${favorite.bookId} - ${favorite.title}');
      Database db = await database;
      int id = await db.insert('favorites', favorite.toMap());
      print('Favorite inserted with id: $id');
      return id;
    } catch (e) {
      print('Error inserting favorite: $e');
      rethrow;
    }
  }

  Future<List<Favorite>> getFavoritesByUserId(int userId) async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> result = await db.query(
        'favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return result.map((item) => Favorite.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  Future<bool> isFavorite(int userId, int bookId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'favorites',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
    return result.isNotEmpty;
  }

  Future<int> deleteFavorite(int userId, int bookId) async {
    Database db = await database;
    return await db.delete(
      'favorites',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
  }

  // Transaction Methods
  Future<int> insertTransaction(BookTransaction transaction) async {
    Database db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<BookTransaction>> getTransactionsByUserId(int userId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'transactions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return result.map((item) => BookTransaction.fromMap(item)).toList();
  }

  // Purchased Books Methods
  Future<int> insertPurchasedBook(PurchasedBook purchasedBook) async {
    try {
      print('Inserting purchased book: ${purchasedBook.bookId} - ${purchasedBook.title}');
      Database db = await database;
      int id = await db.insert('purchased_books', purchasedBook.toMap());
      print('Purchased book inserted with id: $id');
      return id;
    } catch (e) {
      print('Error inserting purchased book: $e');
      rethrow;
    }
  }

  Future<List<PurchasedBook>> getPurchasedBooksByUserId(int userId) async {
    try {
      Database db = await database;
      List<Map<String, dynamic>> result = await db.query(
        'purchased_books',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'purchase_date DESC',
      );
      return result.map((item) => PurchasedBook.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching purchased books: $e');
      return [];
    }
  }

  Future<bool> isPurchased(int userId, int bookId) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.query(
      'purchased_books',
      where: 'user_id = ? AND book_id = ?',
      whereArgs: [userId, bookId],
    );
    return result.isNotEmpty;
  }
}