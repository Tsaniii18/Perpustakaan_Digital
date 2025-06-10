import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_helper.dart';

class TransactionProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  List<BookTransaction> _transactions = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Exchange rates (contoh)
  final Map<String, double> _exchangeRates = {
    'USD': 1.0,    // 1 USD = 1 USD
    'EUR': 0.85,   // 1 USD = 0.85 EUR
    'IDR': 15500,  // 1 USD = 15500 IDR
  };
  
  // Conversion rate from currency to coins
  final int _coinsPerUSD = 10; // 1 USD = 10 coins
  
  List<BookTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  Map<String, double> get exchangeRates => _exchangeRates;
  int get coinsPerUSD => _coinsPerUSD;
  
  Future<void> fetchTransactions(int userId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _transactions = await _dbHelper.getTransactionsByUserId(userId);
    } catch (e) {
      _errorMessage = 'Error fetching transactions: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> purchaseCoins(int userId, double amount, String currency, int coins) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Buat transaksi dengan waktu sekarang (WIB)
      BookTransaction transaction = BookTransaction(
        userId: userId,
        transactionType: TransactionType.coinPurchase,
        amount: amount,
        currency: currency,
        coins: coins,
        timestamp: DateTime.now(), // PERBAIKAN: gunakan DateTime.now() langsung
      );
      
      // Simpan transaksi
      await _dbHelper.insertTransaction(transaction);
      
      // Refresh daftar transaksi
      await fetchTransactions(userId);
      
      return true;
    } catch (e) {
      _errorMessage = 'Error purchasing coins: $e';
      print(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<bool> purchaseBook(int userId, int bookId, String title, int coinPrice) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Buat transaksi dengan waktu sekarang (WIB)
      BookTransaction transaction = BookTransaction(
        userId: userId,
        transactionType: TransactionType.bookPurchase,
        amount: 0, // Tidak ada biaya uang
        currency: 'COIN', // Mata uang adalah koin
        coins: coinPrice,
        timestamp: DateTime.now(), // PERBAIKAN: gunakan DateTime.now() langsung
      );
      
      // Simpan transaksi
      await _dbHelper.insertTransaction(transaction);
      await fetchTransactions(userId);
      
      return true;
    } catch (e) {
      _errorMessage = 'Error recording book purchase: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}