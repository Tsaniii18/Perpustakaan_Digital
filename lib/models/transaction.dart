import 'package:intl/intl.dart';

enum TransactionType {
  coinPurchase,
  bookPurchase,
}

class BookTransaction {
  final int? id;
  final int userId;
  final TransactionType transactionType;
  final double amount;
  final String currency;
  final int coins;
  final DateTime timestamp;

  BookTransaction({
    this.id,
    required this.userId,
    required this.transactionType,
    required this.amount,
    required this.currency,
    required this.coins,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'transaction_type': transactionType.toString().split('.').last,
      'amount': amount,
      'currency': currency,
      'coins': coins,
      'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp),
    };
  }

  factory BookTransaction.fromMap(Map<String, dynamic> map) {
    return BookTransaction(
      id: map['id'],
      userId: map['user_id'],
      transactionType: map['transaction_type'] == 'coinPurchase'
          ? TransactionType.coinPurchase
          : TransactionType.bookPurchase,
      amount: map['amount'],
      currency: map['currency'],
      coins: map['coins'],
      timestamp: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['timestamp']),
    );
  }

  // Method yang disederhanakan untuk mendapatkan timestamp dalam zona waktu berbeda
  String getFormattedTimestamp(String timezone) {
    DateTime adjustedTime = timestamp;
    
    // Asumsi timestamp sudah dalam WIB (UTC+7)
    // Kita adjust relatif terhadap WIB
    switch (timezone) {
      case 'WIB': // UTC+7 - baseline
        // Tidak perlu adjustment
        break;
      case 'WITA': // UTC+8 - 1 jam lebih cepat dari WIB
        adjustedTime = timestamp.add(const Duration(hours: 1));
        break;
      case 'WIT': // UTC+9 - 2 jam lebih cepat dari WIB
        adjustedTime = timestamp.add(const Duration(hours: 2));
        break;
      case 'London': // UTC+0/+1 - 7/6 jam lebih lambat dari WIB
        // Sederhana: anggap London UTC+0 (tanpa DST)
        adjustedTime = timestamp.subtract(const Duration(hours: 7));
        break;
      default:
        // Default tetap WIB
        break;
    }
    
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(adjustedTime);
  }

  // Helper method untuk mendapatkan tanggal saja (selalu dalam WIB)
  String getFormattedDate() {
    return DateFormat('dd MMM yyyy').format(timestamp);
  }
  
  // Helper method untuk mendapatkan waktu saja
  String getFormattedTime(String timezone) {
    String fullTimestamp = getFormattedTimestamp(timezone);
    List<String> parts = fullTimestamp.split(' ');
    return parts.length > 1 ? parts[1] : fullTimestamp;
  }
}