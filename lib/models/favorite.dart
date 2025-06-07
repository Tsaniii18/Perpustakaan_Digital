class Favorite {
  final int? id;
  final int userId;
  final int bookId;
  final String title;
  final String author;
  final String? coverImage;

  Favorite({
    this.id,
    required this.userId,
    required this.bookId,
    required this.title,
    required this.author,
    this.coverImage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'title': title,
      'author': author,
      'cover_image': coverImage,
    };
  }

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      title: map['title'],
      author: map['author'],
      coverImage: map['cover_image'],
    );
  }
}