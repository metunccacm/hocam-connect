import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../utils/network_error_handler.dart';

enum SortOption { priceAsc, priceDesc, newest }

class MarketplaceService {
  final supa = Supabase.instance.client;

  /// Ürünleri getir (left join). Arama/filtre/sıralama client-side.
  Future<List<Product>> fetchProducts({int limit = 200}) async {
    return NetworkErrorHandler.handleNetworkCall(
      () async {
        final rows = await supa.from('marketplace_products').select(r'''
          id,
          title,
          price,
          currency,
          description,
          category,
          size_type,
          size_value,
          seller_id,
          created_at,
          images:marketplace_images (
            url,
            idx
          ),
          seller:profiles (
            id,
            name,
            surname,
            avatar_url
          )
        ''').order('created_at', ascending: false).limit(limit);

        return (rows as List)
            .map((e) => Product.fromRow(Map<String, dynamic>.from(e as Map)))
            .toList();
      },
      context: 'Failed to load marketplace products',
    );
  }

  /// Tek ürün (detay)
  Future<Product> fetchProductById(String id) async {
    return NetworkErrorHandler.handleNetworkCall(
      () async {
        final row = await supa.from('marketplace_products').select(r'''
          id,
          title,
          price,
          currency,
          description,
          category,
          size_type,
          size_value,
          seller_id,
          created_at,
          images:marketplace_images (
            url,
            idx
          ),
          seller:profiles (
            id,
            name,
            surname,
            avatar_url
          )
        ''').eq('id', id).single();

        return Product.fromRow(Map<String, dynamic>.from(row as Map));
      },
      context: 'Failed to load product details',
    );
  }

  /// Kategorileri yalnızca tablodan oku.
  Future<List<String>> fetchCategories() async {
    return NetworkErrorHandler.handleNetworkCall(
      () async {
        final rows = await supa
            .from('marketplace_categories')
            .select('name')
            .order('name', ascending: true);

        if (rows.isEmpty) return <String>[];
        return (rows as List)
            .map((e) => (e['name'] ?? '').toString())
            .where((s) => s.trim().isNotEmpty)
            .cast<String>()
            .toList();
      },
      context: 'Failed to load categories',
    );
  }

  /// Ürün ekle + resimleri yükle + images tablosuna yaz.
  Future<String> addProduct({
    required String title,
    required String description,
    required String category,
    required double price,
    required String currency, // 'TL' | 'USD' | 'EUR'
    String? sizeType, // 'LETTER' | 'NUMERIC' | 'STANDARD'
    String? sizeValue, // 'M' | '44' | ...
    required List<({Uint8List bytes, String ext})> files,
  }) async {
    final user = supa.auth.currentUser;
    if (user == null) throw 'Not authenticated';

    // 1) Ürün kaydı
    final inserted = await supa
        .from('marketplace_products')
        .insert({
          'title': title.trim(),
          'description': description.trim(),
          'category': category.trim(),
          'price': price,
          'currency': currency,
          'size_type': sizeType,
          'size_value': sizeValue,
          'seller_id': user.id,
        })
        .select('id')
        .single();

    final productId = inserted['id'] as String;

    // 2) Storage upload
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final ext = _normalizeExt(f.ext);
      final path = 'products/${user.id}/$productId/$i.$ext';
      await supa.storage.from('marketplace').uploadBinary(
            path,
            f.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFromExt(ext),
            ),
          );
      urls.add(supa.storage.from('marketplace').getPublicUrl(path));
    }

    // 3) Resimleri DB’ye yaz
    if (urls.isNotEmpty) {
      await supa.from('marketplace_images').insert([
        for (var i = 0; i < urls.length; i++)
          {'product_id': productId, 'url': urls[i], 'idx': i}
      ]);
    }

    return productId;
  }

  /// Ürünü sil (resimler dahil)
  Future<void> deleteProduct(String productId) async {
    return NetworkErrorHandler.handleNetworkCall(
      () async {
        // 1. Resim URL'lerini al
        final imagesRows = await supa
            .from('marketplace_images')
            .select('url')
            .eq('product_id', productId);

        final urls = <String>[];
        for (final r in imagesRows) {
          final u = r['url']?.toString();
          if (u != null && u.isNotEmpty) urls.add(u);
        }

        // 2. Storage'dan sil
        if (urls.isNotEmpty) {
          final keys = <String>[];
          for (final u in urls) {
            final k = _extractStorageKey(u);
            if (k != null && k.isNotEmpty) keys.add(k);
          }
          if (keys.isNotEmpty) {
            try {
              await supa.storage.from('marketplace').remove(keys);
            } catch (_) {
              // Storage silme hatası kritik değil, devam et
            }
          }
        }

        // 3. DB'den sil (cascade varsa images otomatik silinir ama garanti olsun)
        await supa.from('marketplace_images').delete().eq('product_id', productId);
        await supa.from('marketplace_products').delete().eq('id', productId);
      },
      context: 'Failed to delete product',
    );
  }

  /// Kullanıcıyı raporla
  Future<void> reportProduct({
    required String productId,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    return NetworkErrorHandler.handleNetworkCall(
      () async {
        final me = supa.auth.currentUser?.id;
        if (me == null) throw 'Not authenticated';

        final payload = {
          'product_id': productId,
          'reporter_id': me,
          'reported_user_id': reportedUserId,
          'reason': reason,
          'details': details,
        };

        await supa.from('abuse_reports').insert(payload);
      },
      context: 'Failed to submit report',
    );
  }

  String? _extractStorageKey(String url) {
    const pub = '/object/public/marketplace/';
    const sig = '/object/sign/marketplace/';
    final iPub = url.indexOf(pub);
    if (iPub != -1) return url.substring(iPub + pub.length);
    final iSig = url.indexOf(sig);
    if (iSig != -1) {
      final rest = url.substring(iSig + sig.length);
      return rest.split('?').first;
    }
    return null;
  }

  // helpers
  String _normalizeExt(String ext) {
    final e = ext.toLowerCase().replaceAll('.', '');
    const allow = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    return allow.contains(e) ? e : 'jpg';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }
}
