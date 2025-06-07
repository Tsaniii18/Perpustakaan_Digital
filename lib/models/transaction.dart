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

  // Mendapatkan timestamp dalam zona waktu yang berbeda
  String getFormattedTimestamp(String timezone) {
    DateTime localTime;
    
    // Menerapkan offset berdasarkan zona waktu
    switch (timezone) {
      case 'WIB': // UTC+7
        localTime = DateTime.utc(timestamp.year, timestamp.month, timestamp.day, 
          timestamp.hour, timestamp.minute, timestamp.second)
          .add(const Duration(hours: 7));
        break;
      case 'WITA': // UTC+8
        localTime = DateTime.utc(timestamp.year, timestamp.month, timestamp.day, 
          timestamp.hour, timestamp.minute, timestamp.second)
          .add(const Duration(hours: 8));
        break;
      case 'WIT': // UTC+9
        localTime = DateTime.utc(timestamp.year, timestamp.month, timestamp.day, 
          timestamp.hour, timestamp.minute, timestamp.second)
          .add(const Duration(hours: 9));
        break;
      case 'London': // UTC+0/1 (tergantung DST)
        // Menghitung apakah saat ini DST (Daylight Saving Time) di London
        bool isDST = _isLondonDST(timestamp);
        localTime = DateTime.utc(timestamp.year, timestamp.month, timestamp.day, 
          timestamp.hour, timestamp.minute, timestamp.second)
          .add(Duration(hours: isDST ? 1 : 0));
        break;
      default:
        // Default to local time
        localTime = timestamp.toLocal();
        break;
    }
    
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(localTime);
  }

  // Fungsi untuk menentukan apakah tanggal saat ini DST di London
  bool _isLondonDST(DateTime date) {
    // DST di Eropa biasanya dimulai pada hari Minggu terakhir bulan Maret 
    // dan berakhir pada hari Minggu terakhir bulan Oktober
    int year = date.year;
    
    // Temukan hari Minggu terakhir bulan Maret
    DateTime marchStart = DateTime(year, 3, 31);
    while (marchStart.weekday != DateTime.sunday) {
      marchStart = marchStart.subtract(const Duration(days: 1));
    }
    
    // Temukan hari Minggu terakhir bulan Oktober
    DateTime octoberEnd = DateTime(year, 10, 31);
    while (octoberEnd.weekday != DateTime.sunday) {
      octoberEnd = octoberEnd.subtract(const Duration(days: 1));
    }
    
    // DST dimulai pada 01:00 GMT dan berakhir pada 01:00 GMT
    DateTime dstStart = DateTime.utc(marchStart.year, marchStart.month, marchStart.day, 1, 0, 0);
    DateTime dstEnd = DateTime.utc(octoberEnd.year, octoberEnd.month, octoberEnd.day, 1, 0, 0);
    
    return date.isAfter(dstStart) && date.isBefore(dstEnd);
  }
}