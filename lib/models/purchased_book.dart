import 'package:intl/intl.dart';

class PurchasedBook {
  final int? id;
  final int userId;
  final int bookId;
  final String title;
  final DateTime purchaseDate;

  PurchasedBook({
    this.id,
    required this.userId,
    required this.bookId,
    required this.title,
    required this.purchaseDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'title': title,
      'purchase_date': DateFormat('yyyy-MM-dd HH:mm:ss').format(purchaseDate),
    };
  }

  factory PurchasedBook.fromMap(Map<String, dynamic> map) {
    return PurchasedBook(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      title: map['title'],
      purchaseDate: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['purchase_date']),
    );
  }
}