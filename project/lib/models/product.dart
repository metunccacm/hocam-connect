class Product {
  final String id;
  final String title;
  final double price;
  final String currency; // 'TL' | 'USD' | 'EUR'
  final List<String> imageUrls;
  final DateTime createdAt;
  final String category;
  final String sellerId;
  final String sellerName;      // name + surname'dan üretilecek
  final String sellerImageUrl;  // profiles.avatar_url
  final String description;
  final String? sizeType;       // 'LETTER' | 'NUMERIC' | 'STANDARD'
  final String? sizeValue;

  const Product({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    required this.imageUrls,
    required this.createdAt,
    required this.category,
    required this.sellerId,
    required this.sellerName,
    required this.sellerImageUrl,
    required this.description,
    this.sizeType,
    this.sizeValue,
  });

  factory Product.fromRow(Map<String, dynamic> row) {
    final imgs = (row['images'] as List<dynamic>? ?? [])
        .map((e) => (e as Map)['url'] as String)
        .toList();

    final prof = (row['seller'] as Map<String, dynamic>? ?? {});
    final first = (prof['name'] ?? '').toString().trim();
    final last  = (prof['surname'] ?? '').toString().trim();
    final displayName =
        (first.isEmpty && last.isEmpty) ? 'User' : ('$first $last').trim();

    return Product(
      id: row['id'] as String,
      title: row['title'] as String,
      price: (row['price'] as num).toDouble(),
      currency: row['currency'] as String,
      imageUrls: imgs,
      createdAt: DateTime.parse(row['created_at'] as String),
      category: row['category'] as String,
      sellerId: row['seller_id'] as String,
      sellerName: displayName,
      sellerImageUrl: (prof['avatar_url'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      sizeType: row['size_type'] as String?,
      sizeValue: row['size_value'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
