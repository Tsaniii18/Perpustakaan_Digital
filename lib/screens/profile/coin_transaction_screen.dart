import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/coin_package.dart';

class CoinTransactionScreen extends StatefulWidget {
  static const routeName = '/coin-transaction';

  const CoinTransactionScreen({Key? key}) : super(key: key);

  @override
  _CoinTransactionScreenState createState() => _CoinTransactionScreenState();
}

class _CoinTransactionScreenState extends State<CoinTransactionScreen> {
  String _selectedCurrency = 'USD';
  CoinPackage? _selectedPackage;
  
  // List paket koin
  final List<CoinPackage> _coinPackages = CoinPackage.getPackages();
  
  @override
  void initState() {
    super.initState();
    // Pilih paket default (Basic)
    _selectedPackage = _coinPackages.firstWhere((package) => package.name == 'Basic');
  }

  Future<void> _processPurchase() async {
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih paket koin terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    
    if (authProvider.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus login untuk membeli koin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Hitung harga dalam mata uang yang dipilih
    double price = _selectedPackage!.getPriceInCurrency(
      _selectedCurrency, 
      transactionProvider.exchangeRates
    );
    
    // Konfirmasi pembelian
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembelian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paket: ${_selectedPackage!.name}'),
            Text('Jumlah koin: ${_selectedPackage!.coins}'),
            const SizedBox(height: 8),
            Text(
              'Total: $_selectedCurrency ${price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Apakah Anda yakin ingin membeli paket koin ini?'),
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
      print('Processing coin purchase');
      
      // Rekam transaksi
      await transactionProvider.purchaseCoins(
        authProvider.currentUser!.id!,
        price,
        _selectedCurrency,
        _selectedPackage!.coins,
      );
      
      // Tambahkan koin ke pengguna
      final newCoins = authProvider.currentUser!.coins + _selectedPackage!.coins;
      await authProvider.updateUserCoins(newCoins);
      
      // Removed notification call
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembelian koin berhasil!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error during coin purchase: $e');
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

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beli Koin'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Coins
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        size: 40,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Koin Anda',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${authProvider.currentUser?.coins ?? 0} Koin',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Currency Selection
              Text(
                'Pilih Mata Uang',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCurrency,
                    isExpanded: true,
                    items: transactionProvider.exchangeRates.keys
                        .map((currency) {
                      return DropdownMenuItem<String>(
                        value: currency,
                        child: Row(
                          children: [
                            _getCurrencyFlag(currency),
                            const SizedBox(width: 8),
                            Text(currency),
                            const Spacer(),
                            Text(
                              _getCurrencySymbol(currency),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Coin Packages
              Text(
                'Pilih Paket Koin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Determine grid crossAxisCount based on screen width
                  final screenWidth = MediaQuery.of(context).size.width;
                  final crossAxisCount = screenWidth > 600 ? 4 : 2;
                  
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _coinPackages.length,
                    itemBuilder: (context, index) {
                      final package = _coinPackages[index];
                      final isSelected = _selectedPackage?.id == package.id;
                      final price = package.getPriceInCurrency(
                        _selectedCurrency, 
                        transactionProvider.exchangeRates
                      );
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPackage = package;
                          });
                        },
                        child: Card(
                          elevation: isSelected ? 4 : 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                // Badge (jika ada)
                                if (package.isMostPopular || package.isBestValue)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      color: package.isMostPopular 
                                          ? Colors.blue 
                                          : Colors.purple,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      package.isMostPopular 
                                          ? 'MOST POPULAR' 
                                          : 'BEST VALUE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                
                                const SizedBox(height: 8),
                                
                                // Nama paket
                                Text(
                                  package.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // Ikon koin
                                const Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                  size: 35,
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Jumlah koin
                                Text(
                                  '${package.coins}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                
                                const SizedBox(height: 4),
                                const Text(
                                  'Koin',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                                
                                const Spacer(),
                                
                                // Harga
                                Text(
                                  '${_getCurrencySymbol(_selectedCurrency)}${price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? Theme.of(context).primaryColor 
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
              
              const SizedBox(height: 32),
              
              // Purchase Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: transactionProvider.isLoading ? null : _processPurchase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.amber,
                  ),
                  child: transactionProvider.isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'BELI KOIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Small disclaimer
              Center(
                child: Text(
                  'Harga dalam ${_selectedCurrency == 'USD' ? 'Dolar Amerika' : _selectedCurrency == 'EUR' ? 'Euro' : 'Rupiah Indonesia'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _getCurrencyFlag(String currency) {
    switch (currency) {
      case 'USD':
        return const Text('🇺🇸', style: TextStyle(fontSize: 16));
      case 'EUR':
        return const Text('🇪🇺', style: TextStyle(fontSize: 16));
      case 'IDR':
        return const Text('🇮🇩', style: TextStyle(fontSize: 16));
      default:
        return const SizedBox();
    }
  }
  
  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'IDR':
        return 'Rp';
      default:
        return '';
    }
  }
}