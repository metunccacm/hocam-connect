// lib/view/product_detail_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

import '../models/product.dart';
import '../services/chat_service.dart';
import 'chat_view.dart';
import 'edit_product_view.dart';

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox();
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9ECEF),
      highlightColor: const Color(0xFFF8F9FA),
      child: Container(color: Colors.white),
    );
  }
}

class ProductDetailView extends StatefulWidget {
  final Product product;
  const ProductDetailView({super.key, required this.product});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  final _svc = ChatService();

  // ⬇️ pull-to-refresh kontrolü
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  PageController? _pager;
  VoidCallback? _pagerListener;
  int _pageIx = 0;
  bool _busy = false;

  // yerel state (edit sonrası güncellenecek)
  late String _title;
  late String _description;
  late double _price;
  late String _currency;
  late String _category;
  String? _sizeValue;
  late String _sellerId;
  late String _sellerName;
  late String _sellerImageUrl;
  late List<String> _imageUrls;

  @override
  void initState() {
    super.initState();
    _bindFromProduct(widget.product);
    _createPager(initialPage: 0);
    unawaited(_warmImages());
  }

  void _bindFromProduct(Product p) {
    _title = p.title;
    _description = p.description;
    _price = p.price;
    _currency = p.currency;
    _category = p.category;
    _sizeValue = p.sizeValue;
    _sellerId = p.sellerId;
    _sellerName = p.sellerName;
    _sellerImageUrl = p.sellerImageUrl;
    _imageUrls = List<String>.from(p.imageUrls);
  }

  void _createPager({int initialPage = 0}) {
    if (_pagerListener != null && _pager != null) {
      _pager!.removeListener(_pagerListener!);
    }
    _pager?.dispose();

    _pageIx = initialPage;
    final ctrl = PageController(initialPage: initialPage);
    _pagerListener = () {
      final ix = ctrl.hasClients ? (ctrl.page?.round() ?? 0) : 0;
      if (ix != _pageIx && mounted) setState(() => _pageIx = ix);
    };
    ctrl.addListener(_pagerListener!);
    _pager = ctrl;
  }

  @override
  void dispose() {
    if (_pagerListener != null && _pager != null) {
      _pager!.removeListener(_pagerListener!);
    }
    _pager?.dispose();
    super.dispose();
  }

  bool get _isMine {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me != null && me == _sellerId;
  }

  String _fmtPrice() {
    final symbol = _currency == 'TL'
        ? '₺'
        : _currency == 'USD'
            ? '\$'
            : '€';
    return '$symbol${_price.toStringAsFixed(2)}';
  }

  Future<void> _warmImages() async {
    for (final u in _imageUrls.skip(1)) {
      unawaited(DefaultCacheManager().getSingleFile(u));
    }
  }

  // ⬇️ TEK NOKTA: elle veya çek-bırak ile kullanılan yenileme
  Future<void> _manualRefresh() async {
    // indikatörü ekranda göster (opsiyonel)
    _refreshKey.currentState?.show();
    await _reloadFromServer();
  }

  /// Sunucudan ürünü tekrar oku
  Future<void> _reloadFromServer() async {
    try {
      final supa = Supabase.instance.client;
      final row = await supa
          .from('marketplace_products')
          .select('''
            title, description, price, currency, category, size_value,
            seller_id, seller_name, seller_image_url,
            marketplace_images ( url )
          ''')
          .eq('id', widget.product.id)
          .maybeSingle();

      if (row is Map<String, dynamic>) {
        final imgs = <String>[];
        final imagesRaw = row['marketplace_images'] as List<dynamic>?;
        if (imagesRaw != null) {
          for (final it in imagesRaw) {
            final u = (it as Map<String, dynamic>)['url']?.toString();
            if (u != null && u.isNotEmpty) imgs.add(u);
          }
        }

        setState(() {
          _title = (row['title'] as String?) ?? _title;
          _description = (row['description'] as String?) ?? _description;
          _price = (row['price'] as num?)?.toDouble() ?? _price;
          _currency = (row['currency'] as String?) ?? _currency;
          _category = (row['category'] as String?) ?? _category;
          _sizeValue = (row['size_value'] as String?) ?? _sizeValue;
          _sellerId = (row['seller_id'] as String?) ?? _sellerId;
          _sellerName = (row['seller_name'] as String?) ?? _sellerName;
          _sellerImageUrl =
              (row['seller_image_url'] as String?) ?? _sellerImageUrl;
          _imageUrls = imgs;
        });

        // görsel adedi değiştiyse PageController’ı güvenle yenile
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _createPager(initialPage: 0);
        });

        unawaited(_warmImages());
      }
    } catch (_) {
      // sessiz geç
    }
  }

  Future<void> _contactSeller() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me == null) throw Exception('Not authenticated');

      if (_isMine) {
        messenger.showSnackBar(
          const SnackBar(content: Text('This is your listing.')),
        );
        return;
      }

      await _svc.ensureMyLongTermKey();
      final convId = await _svc.createOrGetDm(_sellerId);

      final text = StringBuffer()
        ..writeln('👋 Interested in your listing:')
        ..writeln('• $_title')
        ..writeln('• ${_fmtPrice()}')
        ..writeln('• Category: $_category');
      if ((_sizeValue ?? '').isNotEmpty) {
        text.writeln('• Size: $_sizeValue');
      }

      await _svc.sendTextEncrypted(
        conversationId: convId,
        text: text.toString(),
      );

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatView(conversationId: convId, title: _sellerName),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to contact: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Edit’e git – kaydedilirse geri dön ve programatik refresh
  Future<void> _openEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProductView(
          productId: widget.product.id,
          initialTitle: widget.product.title,
          initialDescription: widget.product.description,
          initialPrice: widget.product.price,
          initialCurrency: widget.product.currency,
          initialCategory: widget.product.category,
          initialSizeValue: widget.product.sizeValue,
          initialImageUrls: widget.product.imageUrls,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _manualRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Listing updated')));
    }
  }

  Future<void> _markAsSold() async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as sold?'),
        content: const Text(
            'This will remove the product and its images permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark as sold')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final supa = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final imagesRows = await supa
          .from('marketplace_images')
          .select('url')
          .eq('product_id', widget.product.id);

      final urls = <String>[];
      if (imagesRows is List) {
        for (final r in imagesRows) {
          final u = (r as Map<String, dynamic>)['url']?.toString();
          if (u != null && u.isNotEmpty) urls.add(u);
        }
      } else {
        urls.addAll(_imageUrls);
      }

      await _tryDeleteFromUrls(urls);
      await supa.from('marketplace_images').delete().eq('product_id', widget.product.id);
      await supa.from('marketplace_products').delete().eq('id', widget.product.id);

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Listing marked as sold.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not mark as sold: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tryDeleteFromUrls(List<String> urls) async {
    final keys = <String>[];
    for (final u in urls) {
      final k = _extractStorageKey(u);
      if (k != null && k.isNotEmpty) keys.add(k);
    }
    if (keys.isEmpty) return;
    try {
      await Supabase.instance.client.storage.from('marketplace').remove(keys);
    } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    final imgs = _imageUrls;
    final hasImgs = imgs.isNotEmpty;
    final safePageIx = (_pageIx >= imgs.length) ? 0 : _pageIx;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          /*IconButton(
            tooltip: 'Refresh',
            onPressed: _manualRefresh,
            icon: const Icon(Icons.refresh),
          ),*/
          if (_isMine)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _openEdit,
            ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : (_isMine ? _markAsSold : _contactSeller),
              icon: Icon(
                _isMine ? Icons.check_circle_outline : Icons.send_rounded,
                size: 20,
              ),
              label: Text(
                _isMine ? 'Mark as sold' : 'Contact Hocam',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMine ? const Color(0xFFFF4D4F) : null,
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),

      // ⬇️ Pull-to-refresh
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _reloadFromServer,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImgs
                    ? Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          PageView.builder(
                            controller: _pager,
                            itemCount: imgs.length,
                            itemBuilder: (_, i) => CachedNetworkImage(
                              imageUrl: imgs[i],
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const _ShimmerBox(),
                              errorWidget: (_, __, ___) =>
                                  const Center(child: Icon(Icons.broken_image_outlined, size: 32)),
                            ),
                          ),
                          if (imgs.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(imgs.length, (i) {
                                  final active = i == safePageIx;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: active ? 10 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active ? Colors.white : Colors.white70,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      )
                    : Container(
                        color: const Color(0xFFEFF3F7),
                        child: const Center(child: Icon(Icons.image, size: 40)),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 6),

            Text(
              _fmtPrice(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (_description.isNotEmpty) Text(_description),

            const SizedBox(height: 16),

            Row(
              children: [
                CircleAvatar(
                  backgroundImage: _sellerImageUrl.isNotEmpty ? NetworkImage(_sellerImageUrl) : null,
                  child: _sellerImageUrl.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if ((_sizeValue ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Size: $_sizeValue', style: const TextStyle(color: Colors.black54)),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
