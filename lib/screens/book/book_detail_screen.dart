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
      print('Loading details for book ID: $bookId');
      
      // Parallel fetch untuk book detail dan status favorit/pembelian
      final bookFuture = _apiService.fetchBookDetail(bookId);
      
      bool isFav = false;
      bool isPurchased = false;
      
      if (authProvider.currentUser != null) {
        final favFuture = bookProvider.isFavorite(
          authProvider.currentUser!.id!,
          bookId,
        );
        
        final purchasedFuture = bookProvider.isPurchased(
          authProvider.currentUser!.id!,
          bookId,
        );
        
        // Tunggu semua hasil
        final results = await Future.wait([
          bookFuture,
          favFuture,
          purchasedFuture,
        ]);
        
        final book = results[0] as Book;
        isFav = results[1] as bool;
        isPurchased = results[2] as bool;
        
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
      print('Error loading book details: $e');
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
        content: Text(
          'Apakah Anda yakin ingin membeli "${_book!.title}" dengan ${_book!.coinPrice} koin?',
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
      print('Processing book purchase');
      
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
            content: Text('Pembelian berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error during book purchase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openBookReader() {
    if (_book == null) return;
    
    // Pastikan untuk mengecek apakah buku premium dan belum dibeli
    if (_book!.isPremium && !_isPurchased) {
      print('Trying to open premium book that has not been purchased');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus membeli buku ini untuk membacanya'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.of(context).pushNamed(
      BookReaderScreen.routeName,
      arguments: {
        'title': _book!.title,
        'url': _book!.textUrl,
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
                                    Row(
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
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_isPurchased)
                                    const Chip(
                                      label: Text('Dibeli'),
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
                                icon: const Icon(Icons.book),
                                label: const Text('Baca Buku'),
                                onPressed: _book!.isPremium && !_isPurchased ? null : _openBookReader,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: _book!.isPremium && !_isPurchased 
                                      ? Colors.grey 
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