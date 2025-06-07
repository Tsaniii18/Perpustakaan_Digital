import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../book/book_detail_screen.dart';
import 'coin_transaction_screen.dart';
import 'transaction_history_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  static const routeName = '/profile';

  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingFavorites = false;
  bool _isLoadingPurchased = false;
  bool _hasFetchedData = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Load data only once when screen initializes
    if (!_hasFetchedData) {
      _loadUserData();
      _hasFetchedData = true;
    }
  }

  Future<void> _loadUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    
    if (authProvider.currentUser != null) {
      try {
        setState(() {
          _isLoadingFavorites = true;
          _isLoadingPurchased = true;
        });
        
        // Load favorites
        await bookProvider.fetchFavorites(authProvider.currentUser!.id!);
        
        if (mounted) {
          setState(() {
            _isLoadingFavorites = false;
          });
        }
        
        // Load purchased books
        await bookProvider.fetchPurchasedBooks(authProvider.currentUser!.id!);
        
        if (mounted) {
          setState(() {
            _isLoadingPurchased = false;
          });
        }
        
        print("Loaded ${bookProvider.favorites.length} favorites and ${bookProvider.purchasedBooks.length} purchased books");
      } catch (e) {
        print("Error loading user data: $e");
        if (mounted) {
          setState(() {
            _isLoadingFavorites = false;
            _isLoadingPurchased = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final bookProvider = Provider.of<BookProvider>(context);
    
    if (authProvider.currentUser == null) {
      return const Center(
        child: Text('Anda belum login'),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadUserData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              child: Column(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage(authProvider.currentUser!.profileImage),
                  ),
                  const SizedBox(height: 16),
                  // Username
                  Text(
                    authProvider.currentUser!.username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    authProvider.currentUser!.email,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Coins
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.black87),
                        const SizedBox(width: 8),
                        Text(
                          '${authProvider.currentUser!.coins} Koin',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profil'),
                        onPressed: () {
                          Navigator.of(context).pushNamed(EditProfileScreen.routeName)
                            .then((_) => _loadUserData()); // Reload data after editing profile
                        },
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Beli Koin'),
                        onPressed: () {
                          Navigator.of(context).pushNamed(CoinTransactionScreen.routeName)
                            .then((_) => _loadUserData()); // Reload data after buying coins
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Transaction History Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed(TransactionHistoryScreen.routeName);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 30),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Riwayat Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.grey[700]),
                    ],
                  ),
                ),
              ),
            ),
            
            // Favorite Books
            _buildFavoriteBooksSection(bookProvider),
            
            // Purchased Books
            _buildPurchasedBooksSection(bookProvider),
            
            // Spacer at bottom for better scrolling experience
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileImage(String profileImage) {
    // Ekstrak angka dari nama file (misalnya profile_1.png -> 1)
    final profileNumber = int.tryParse(
      profileImage.replaceAll(RegExp(r'[^0-9]'), '')
    ) ?? 1;
    
    // Untuk sementara kita tampilkan nomor profil saja
    return Text(
      '$profileNumber',
      style: const TextStyle(
        fontSize: 40,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildFavoriteBooksSection(BookProvider bookProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buku Favorit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingFavorites 
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : bookProvider.favorites.isEmpty
                  ? Container(
                      height: 100,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada buku favorit',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bookProvider.favorites.length,
                      itemBuilder: (ctx, index) {
                        final favorite = bookProvider.favorites[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: favorite.coverImage != null
                                ? Image.network(
                                    favorite.coverImage!,
                                    width: 40,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, error, _) => const Icon(
                                      Icons.book,
                                      size: 40,
                                    ),
                                  )
                                : const Icon(Icons.book, size: 40),
                            title: Text(
                              favorite.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(favorite.author),
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                BookDetailScreen.routeName,
                                arguments: favorite.bookId,
                              ).then((_) => _loadUserData()); // Reload after returning from detail
                            },
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
  
  Widget _buildPurchasedBooksSection(BookProvider bookProvider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buku yang Dibeli',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _isLoadingPurchased
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : bookProvider.purchasedBooks.isEmpty
                  ? Container(
                      height: 100,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada buku yang dibeli',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bookProvider.purchasedBooks.length,
                      itemBuilder: (ctx, index) {
                        final purchasedBook = bookProvider.purchasedBooks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.book, size: 40),
                            title: Text(
                              purchasedBook.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Dibeli pada ${purchasedBook.purchaseDate.day}/${purchasedBook.purchaseDate.month}/${purchasedBook.purchaseDate.year}',
                            ),
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                BookDetailScreen.routeName,
                                arguments: purchasedBook.bookId,
                              ).then((_) => _loadUserData()); // Reload after returning from detail
                            },
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}