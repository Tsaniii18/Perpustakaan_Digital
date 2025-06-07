class CoinPackage {
  final int id;
  final String name;
  final int coins;
  final double basePrice; // Harga dalam USD
  final bool isMostPopular;
  final bool isBestValue;

  CoinPackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.basePrice,
    this.isMostPopular = false,
    this.isBestValue = false,
  });

  // Menghitung harga berdasarkan mata uang
  double getPriceInCurrency(String currency, Map<String, double> exchangeRates) {
    if (currency == 'USD') {
      return basePrice;
    }
    
    // Konversi dari USD ke mata uang target
    double rate = exchangeRates[currency] ?? 1.0;
    return basePrice * rate;
  }

  // Paket-paket koin standar
  static List<CoinPackage> getPackages() {
    return [
      CoinPackage(
        id: 1,
        name: 'Starter',
        coins: 10,
        basePrice: 1.0,
      ),
      CoinPackage(
        id: 2,
        name: 'Basic',
        coins: 50,
        basePrice: 4.5, // Diskon
        isMostPopular: true,
      ),
      CoinPackage(
        id: 3,
        name: 'Premium',
        coins: 100,
        basePrice: 8.0, // Diskon lebih besar
      ),
      CoinPackage(
        id: 4,
        name: 'Ultimate',
        coins: 500,
        basePrice: 35.0, // Diskon terbesar
        isBestValue: true,
      ),
    ];
  }
}