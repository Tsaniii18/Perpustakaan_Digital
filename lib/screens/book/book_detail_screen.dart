import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../services/api_service.dart';
import 'book_reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  static const routeName = '/book-detail';

  const BookDetailScreen({Key? key}) : super(key: key);

  @override
  _BookDetailScreenState createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Book? _book;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _isPurchased = false;
  bool _isValidatingPurchase = false; // Flag untuk validasi tambahan
  final ApiService _apiService = ApiService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBookDetails();
  }

  Future<void> _loadBookDetails() async {
    final bookId = ModalRoute.of(context)!.settings.arguments as int;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('🔍 Loading details for book ID: $bookId');
      
      // Parallel fetch untuk book detail dan status favorit/pembelian
      final bookFuture = _apiService.fetchBookDetail(bookId);
      
      bool isFav = false;
      bool isPurchased = false;
      
      if (authProvider.currentUser != null) {
        // PERBAIKAN: Gunakan sequential loading untuk memastikan konsistensi
        final book = await bookFuture;
        
        // Validasi ulang status premium
        print('📚 Book loaded: ${book.title}');
        print('💰 Is Premium: ${book.isPremium}');
        print('🪙 Coin Price: ${book.coinPrice}');
        
        if (book.isPremium) {
          // Double-check status pembelian untuk buku premium
          await _validatePurchaseStatus(authProvider.currentUser!.id!, book.id);
          isPurchased = await bookProvider.isPurchased(
            authProvider.currentUser!.id!,
            book.id,
          );
        }
        
        isFav = await bookProvider.isFavorite(
          authProvider.currentUser!.id!,
          book.id,
        );
        
        print('❤️ Is Favorite: $isFav');
        print('🛒 Is Purchased: $isPurchased');
        
        if (mounted) {
          setState(() {
            _book = book;
            _isFavorite = isFav;
            _isPurchased = isPurchased;
            _isLoading = false;
          });
        }
      } else {
        // Jika user belum login, cukup fetch detail buku
        final book = await bookFuture;
        
        if (mounted) {
          setState(() {
            _book = book;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading book details: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // METODE BARU: Validasi status pembelian dengan double-check
  Future<void> _validatePurchaseStatus(int userId, int bookId) async {
    setState(() => _isValidatingPurchase = true);
    
    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      
      // Force refresh status pembelian dari database
      await bookProvider.fetchPurchasedBooks(userId);
      
      // Cek ulang status pembelian
      bool isPurchased = await bookProvider.isPurchased(userId, bookId);
      
      if (mounted) {
        setState(() {
          _isPurchased = isPurchased;
          _isValidatingPurchase = false;
        });
      }
      
      print('✅ Purchase validation complete: $isPurchased');
    } catch (e) {
      print('❌ Error validating purchase: $e');
      setState(() => _isValidatingPurchase = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_book == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      final newFavoriteStatus = await bookProvider.toggleFavorite(
        authProvider.currentUser!.id!,
        _book!,
      );
      
      setState(() {
        _isFavorite = newFavoriteStatus;
      });
    }
  }

  Future<void> _purchaseBook() async {
    if (_book == null) return;
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus login untuk membeli buku'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // VALIDASI ULANG: Pastikan buku benar-benar premium dan belum dibeli
    if (!_book!.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku ini bukan buku premium'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Double-check status pembelian
    await _validatePurchaseStatus(authProvider.currentUser!.id!, _book!.id);
    
    if (_isPurchased) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buku ini sudah dibeli sebelumnya'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    
    // Cek apakah user memiliki cukup koin
    if (authProvider.currentUser!.coins < _book!.coinPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Koin tidak cukup. Silakan beli koin terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Konfirmasi pembelian
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin membeli "${_book!.title}"?'),
            const SizedBox(height: 8),
            Text('💰 Harga: ${_book!.coinPrice} koin'),
            Text('🪙 Koin Anda: ${authProvider.currentUser!.coins} koin'),
            Text('💳 Sisa: ${authProvider.currentUser!.coins - _book!.coinPrice} koin'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Beli'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Proses pembelian
    try {
      print('💳 Processing book purchase');
      
      // PERBAIKAN: Lakukan validasi sekali lagi sebelum transaksi
      bool isStillAvailable = !await bookProvider.isPurchased(
        authProvider.currentUser!.id!,
        _book!.id,
      );
      
      if (!isStillAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Buku sudah dibeli oleh akun ini'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isPurchased = true);
        return;
      }
      
      // Paralel operation untuk semua operasi pembelian
      await Future.wait([
        // Rekam transaksi
        transactionProvider.purchaseBook(
          authProvider.currentUser!.id!,
          _book!.id,
          _book!.title,
          _book!.coinPrice,
        ),
        
        // Catat buku yang dibeli
        bookProvider.purchaseBook(
          authProvider.currentUser!.id!,
          _book!,
        ),
        
        // Kurangi koin pengguna
        authProvider.updateUserCoins(
          authProvider.currentUser!.coins - _book!.coinPrice
        ),
      ]);
      
      setState(() {
        _isPurchased = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Pembelian berhasil! Selamat membaca!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error during book purchase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // METODE PERBAIKAN: Validasi ketat sebelum membuka reader
  void _openBookReader() {
    if (_book == null) return;
    
    print('📖 Attempting to open book reader');
    print('📚 Book: ${_book!.title}');
    print('💰 Is Premium: ${_book!.isPremium}');
    print('🛒 Is Purchased: $_isPurchased');
    
    // VALIDASI KETAT: Cek untuk buku premium
    if (_book!.isPremium) {
      if (!_isPurchased) {
        print('🚫 BLOCKED: Premium book not purchased');
        
        // Tampilkan dialog konfirmasi pembelian
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('🔒 Buku Premium'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ini adalah buku premium yang memerlukan pembelian.'),
                const SizedBox(height: 8),
                Text('💰 Harga: ${_book!.coinPrice} koin'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _purchaseBook();
                },
                child: const Text('Beli Sekarang'),
              ),
            ],
          ),
        );
        return;
      }
    }
    
    // VALIDASI TAMBAHAN: Cek URL buku
    if (_book!.textUrl == null || _book!.textUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Konten buku tidak tersedia'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('✅ Opening book reader');
    
    Navigator.of(context).pushNamed(
      BookReaderScreen.routeName,
      arguments: {
        'title': _book!.title,
        'url': _book!.textUrl,
        'isPremium': _book!.isPremium,
        'isPurchased': _isPurchased,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_book?.title ?? 'Detail Buku'),
        actions: [
          if (_book != null && Provider.of<AuthProvider>(context).currentUser != null)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _book == null
              ? const Center(child: Text('Buku tidak ditemukan'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TAMBAHAN: Status validasi
                      if (_isValidatingPurchase)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          color: Colors.blue.shade50,
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Memvalidasi status pembelian...'),
                            ],
                          ),
                        ),
                      
                      // Book Cover and Basic Info
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Book Cover with Hero Animation
                            Hero(
                              tag: 'book-cover-${_book!.id}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 120,
                                  height: 180,
                                  child: _book!.coverImage != null
                                      ? CachedNetworkImage(
                                          imageUrl: _book!.coverImage!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Colors.grey[200],
                                            child: const Center(
                                              child: SizedBox(
                                                width: 30,
                                                height: 30,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.book, size: 50),
                                          ),
                                          // Optimasi cache
                                          memCacheWidth: 240, // 2x untuk high DPI
                                          memCacheHeight: 360, // 2x untuk high DPI
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.book, size: 50),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Book Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _book!.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_book!.authors.isNotEmpty) ...[
                                    Text(
                                      'Penulis: ${_book!.authors.join(", ")}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_book!.isPremium) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Premium: ${_book!.coinPrice} koin',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_isPurchased)
                                    const Chip(
                                      avatar: Icon(Icons.check_circle, color: Colors.white, size: 18),
                                      label: Text('Sudah Dibeli'),
                                      backgroundColor: Colors.green,
                                      labelStyle: TextStyle(color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(_book!.isPremium && !_isPurchased ? Icons.lock : Icons.book),
                                label: Text(_book!.isPremium && !_isPurchased ? 'Buka Kunci' : 'Baca Buku'),
                                onPressed: _openBookReader,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: _book!.isPremium && !_isPurchased 
                                      ? Colors.orange 
                                      : Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            if (_book!.isPremium && !_isPurchased) ...[
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.shopping_cart),
                                  label: const Text('Beli Buku'),
                                  onPressed: _purchaseBook,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Book Details - Lazy Loaded
                      _buildLazyLoadedDetails(),
                    ],
                  ),
                ),
    );
  }
  
  // Membuat widget detail buku yang lazy loaded
  Widget _buildLazyLoadedDetails() {
    if (_book == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _book!.subjects.isEmpty
                ? [const Chip(label: Text('Umum'))]
                : _book!.subjects
                    .take(5)
                    .map((subject) => Chip(
                          label: Text(subject),
                        ))
                    .toList(),
          ),
          const SizedBox(height: 16),
          if (_book!.bookshelves.isNotEmpty) ...[
            const Text(
              'Rak Buku',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _book!.bookshelves
                  .map((shelf) => Chip(
                        label: Text(shelf),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Format',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _book!.formats.isEmpty
                ? [const Chip(label: Text('Tidak ada'))]
                : _book!.formats
                    .map((format) => Chip(
                          label: Text(
                            format.keys.first.split('/').last,
                          ),
                        ))
                    .toList(),
          ),
        ],
      ),
    );
  }
}