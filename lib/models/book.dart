class Book {
  final int id;
  final String title;
  final List<String> authors;
  final List<String> subjects;
  final List<String> bookshelves;
  final List<Map<String, String>> formats;
  final String? coverImage;
  final bool isPremium;
  final int coinPrice;
  final int downloadCount;

  Book({
    required this.id,
    required this.title,
    required this.authors,
    required this.subjects,
    required this.bookshelves,
    required this.formats,
    this.coverImage,
    this.isPremium = false,
    this.coinPrice = 0,
    this.downloadCount = 0,
  });

  // Format URL dari API Gutendex yang menyediakan cover image
  String? get smallCoverUrl => coverImage;
  
  // Format URL untuk HTML text dari API Gutendex
  String? get textUrl {
    if (formats.isNotEmpty) {
      for (var format in formats) {
        if (format.containsKey('text/html')) {
          return format['text/html'];
        }
      }
    }
    return null;
  }

  // Mendapatkan nama penulis untuk ditampilkan
  String get authorDisplay {
    if (authors.isEmpty) return 'Unknown Author';
    if (authors.length == 1) return authors.first;
    return "${authors.first} & ${authors.length - 1} more";
  }

  factory Book.fromJson(Map<String, dynamic> json, {bool forcePremium = false}) {
    // Harga buku premium akan bervariasi antara 10, 20, atau 30 koin
    int coinPrice = forcePremium ? ((json['id'] % 3) + 1) * 10 : 0;
    
    // Ekstrak format buku
    List<Map<String, String>> formats = [];
    if (json['formats'] != null) {
      (json['formats'] as Map<String, dynamic>).forEach((key, value) {
        formats.add({key: value.toString()});
      });
    }

    // Cari cover image jika ada
    String? coverImage;
    if (json['formats'] != null && json['formats']['image/jpeg'] != null) {
      coverImage = json['formats']['image/jpeg'];
    }
    
    // Download count (kalau ada) atau random value untuk simulasi
    int downloadCount = json['download_count'] ?? (json['id'] * 7) % 1000 + 50;

    return Book(
      id: json['id'],
      title: json['title'] ?? 'Unknown Title',
      authors: json['authors'] != null 
          ? List<String>.from(json['authors'].map((author) => author['name']))
          : ['Unknown Author'],
      subjects: json['subjects'] != null 
          ? List<String>.from(json['subjects'])
          : [],
      bookshelves: json['bookshelves'] != null 
          ? List<String>.from(json['bookshelves'])
          : [],
      formats: formats,
      coverImage: coverImage,
      isPremium: forcePremium,
      coinPrice: coinPrice,
      downloadCount: downloadCount,
    );
  }
}