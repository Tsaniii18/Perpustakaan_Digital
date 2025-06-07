import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../services/sensor_service.dart';
import '../../widgets/book_grid_item.dart';
import '../book/book_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../feedback/feedback_screen.dart';
import '../location/location_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _currentIndex = 0;
  String? _selectedCategory;
  bool? _isPremiumFilter; 
  Timer? _debounce;
  final SensorService _sensorService = SensorService();
  
  // Overlay notification
  bool _showShakeNotification = false;
  Timer? _notificationTimer;
  
  @override
  void initState() {
    super.initState();
    _loadData();
    _setupSensorListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sensorService.stopListening();
    _debounce?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (!bookProvider.hasLoadedInitialData) {
        bookProvider.fetchBooks(refresh: true);
        bookProvider.fetchCategories();
        
        if (authProvider.currentUser != null) {
          bookProvider.fetchFavorites(authProvider.currentUser!.id!);
          bookProvider.fetchPurchasedBooks(authProvider.currentUser!.id!);
        }
      }
    });
  }

  void _setupSensorListener() {
    if (_sensorService.isSensorSupported) {
      _sensorService.listenForShake(({bool showNotification = false}) {
        final bookProvider = Provider.of<BookProvider>(context, listen: false);
        bookProvider.refreshData();
        
        // Tampilkan notifikasi jika diminta
        if (showNotification && mounted) {
          setState(() {
            _showShakeNotification = true;
          });
          
          // Sembunyikan notifikasi setelah 5 detik jika tidak ditutup secara manual
          _notificationTimer?.cancel();
          _notificationTimer = Timer(const Duration(seconds: 5), () {
            if (mounted && _showShakeNotification) {
              setState(() {
                _showShakeNotification = false;
              });
            }
          });
        }
      });
    }
  }
  
  // Fungsi untuk menutup notifikasi
  void _closeNotification() {
    if (mounted) {
      setState(() {
        _showShakeNotification = false;
      });
      // Batalkan timer karena sudah ditutup manual
      _notificationTimer?.cancel();
    }
  }

  void _performSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      bookProvider.setSearchQuery(query);
      bookProvider.fetchBooks(refresh: true, showLoading: false);
    });
  }

  // Fungsi untuk mengatur filter kategori
  void _selectCategory(String? category) {
    setState(() => _selectedCategory = category);
    Provider.of<BookProvider>(context, listen: false).setSelectedCategory(category);
  }

  // Fungsi untuk mengatur filter premium/gratis
  void _selectPremiumFilter(bool? isPremium) {
    setState(() => _isPremiumFilter = isPremium);
    Provider.of<BookProvider>(context, listen: false).setIsPremiumFilter(isPremium);
  }
  
  // Metode untuk menerapkan semua filter sekaligus
  void _applyFilters() {
    Provider.of<BookProvider>(context, listen: false).fetchBooks(refresh: true);
  }

  void _logout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens for bottom navigation
    final List<Widget> screens = [
      _buildHomeContent(),
      const ProfileScreen(),
      const FeedbackScreen(),
    ];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perpustakaan Digital'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => Navigator.of(context).pushNamed(LocationScreen.routeName),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          screens[_currentIndex],
          
          // Shake notification overlay
          if (_showShakeNotification)
            Positioned.fill(
              child: GestureDetector(
                // Memungkinkan pengguna menutup dengan tap di luar notifikasi
                onTap: _closeNotification,
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 260,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header dengan tombol close
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Pemberitahuan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _closeNotification,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.screen_rotation,
                                      size: 36,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Gerakan Terdeteksi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Data buku sedang diperbarui...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback),
            label: 'Kesan',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Consumer<BookProvider>(
      builder: (ctx, bookProvider, _) {
        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari buku...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: _performSearch,
              ),
            ),
            
            // Filter Chips dan Apply Button
            _buildFilterRow(bookProvider),
            
            // Shake hint message
            if (_sensorService.isSensorSupported)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: const [
                    Icon(Icons.screen_rotation, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Goyang HP Anda untuk refresh otomatis',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Book Grid
            Expanded(
              child: _buildBookGrid(bookProvider),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildFilterRow(BookProvider bookProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Premium/Free Filter
          FilterChip(
            label: const Text('Semua Buku'),
            selected: _isPremiumFilter == null,
            onSelected: (selected) {
              if (selected) _selectPremiumFilter(null);
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Buku Gratis'),
            selected: _isPremiumFilter == false,
            onSelected: (selected) => _selectPremiumFilter(selected ? false : null),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Buku Premium'),
            selected: _isPremiumFilter == true,
            onSelected: (selected) => _selectPremiumFilter(selected ? true : null),
          ),
          const SizedBox(width: 16),
          
          // Category Filter
          FilterChip(
            label: const Text('Semua Kategori'),
            selected: _selectedCategory == null,
            onSelected: (selected) {
              if (selected) _selectCategory(null);
            },
          ),
          const SizedBox(width: 8),
          ...bookProvider.categories.map((category) => 
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(category),
                selected: _selectedCategory == category,
                onSelected: (selected) => _selectCategory(selected ? category : null),
              ),
            )
          ),
          
          // Apply Button
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _applyFilters,
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBookGrid(BookProvider bookProvider) {
    // Loading state
    if (bookProvider.isLoading && bookProvider.books.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    // Empty state
    if (bookProvider.books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tidak ada buku yang ditemukan'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => bookProvider.refreshData(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    // Books grid with loading indicator
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => bookProvider.refreshData(),
          child: GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: bookProvider.books.length,
            itemBuilder: (ctx, index) {
              final book = bookProvider.books[index];
              return BookGridItem(
                book: book,
                onTap: () => Navigator.of(context).pushNamed(
                  BookDetailScreen.routeName,
                  arguments: book.id,
                ),
              );
            },
          ),
        ),
        // Loading indicator overlay
        if (bookProvider.isLoading && bookProvider.books.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              child: const LinearProgressIndicator(),
            ),
          ),
      ],
    );
  }
}