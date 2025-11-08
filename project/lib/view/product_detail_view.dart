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
    final cs = Theme.of(context).colorScheme;
    final base = cs.surfaceContainerHighest.withOpacity(0.6);
    final highlight = cs.surfaceContainerHighest.withOpacity(0.85);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(color: cs.surfaceContainerHighest),
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

  final TextEditingController _reportDetailsCtrl = TextEditingController();

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
    _reportDetailsCtrl.dispose();
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

  // Report User
  Future<void> _reportUser() async {
    if (_busy) return;
    if (_isMine) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot report your own listing.')),
      );
      return;
    }

    final reasons = const [
      'Scam / Fraud',
      'Harassment / Abuse',
      'Fake or Misleading',
      'Prohibited Item',
      'Spam',
      'Other',
    ];
    String selected = reasons.first;
    _reportDetailsCtrl.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: selected,
              items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => selected = v ?? selected,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reportDetailsCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Add any useful info/screenshots links, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _busy = true);
    final supa = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final me = supa.auth.currentUser?.id;
      if (me == null) throw Exception('Not authenticated');

      final payload = {
        'product_id': widget.product.id,
        'reporter_id': me,
        'reported_user_id': _sellerId,
        'reason': selected,
        'details': _reportDetailsCtrl.text.trim().isEmpty ? null : _reportDetailsCtrl.text.trim(),
      };

      await supa.from('abuse_reports').insert(payload);

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.')));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        messenger.showSnackBar(const SnackBar(content: Text('You already reported this listing.')));
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Could not submit: ${e.message}')));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // elle veya çek-bırak ile kullanılan yenileme
  Future<void> _manualRefresh() async {
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
          _sellerImageUrl = (row['seller_image_url'] as String?) ?? _sellerImageUrl;
          _imageUrls = imgs;
        });

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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark as sold?'),
        content: const Text('This will remove the product and its images permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Sold'),
          ),
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
      for (final r in imagesRows) {
        final u = r['url']?.toString();
        if (u != null && u.isNotEmpty) urls.add(u);
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

  Color _dotsColor({required bool active}) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return active ? Colors.white.withOpacity(0.95) : Colors.white70;
    } else {
      return active ? Colors.black87 : Colors.black45;
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgs = _imageUrls;
    final hasImgs = imgs.isNotEmpty;
    final safePageIx = (_pageIx >= imgs.length) ? 0 : _pageIx;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          _title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
        elevation: 1,
        actions: [
          if (!_isMine)
            IconButton(
              tooltip: 'Report',
              icon: const Icon(Icons.flag_outlined),
              onPressed: _busy ? null : _reportUser,
            ),
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
              icon: Icon(_isMine ? Icons.check_circle_outline : Icons.send_rounded, size: 20),
              label: Text(
                _isMine ? 'Mark as sold' : 'Contact Hocam',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isMine ? cs.error : cs.primary,
                foregroundColor: _isMine ? cs.onError : cs.onPrimary,
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
        color: cs.primary,
        backgroundColor: cs.surface,
        onRefresh: _reloadFromServer,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImgs
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _FullscreenImageViewer(
                                imageUrls: imgs,
                                initialIndex: safePageIx,
                              ),
                            ),
                          );
                        },
                        child: Stack(
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
                                    Center(child: Icon(Icons.broken_image_outlined, size: 32, color: onSurfaceVariant)),
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
                                        color: _dotsColor(active: active),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.image, size: 40, color: onSurfaceVariant),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _fmtPrice(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: onSurface,
              ),
            ),

            const SizedBox(height: 12),

            if (_description.isNotEmpty)
              Text(
                _description,
                style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
              ),

            const SizedBox(height: 16),

            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: _sellerImageUrl.isNotEmpty ? NetworkImage(_sellerImageUrl) : null,
                  child: _sellerImageUrl.isEmpty
                      ? Icon(Icons.person, color: onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sellerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                  ),
                ),
              ],
            ),

            if ((_sizeValue ?? '').isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Size: $_sizeValue',
                style: theme.textTheme.bodyMedium?.copyWith(color: onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen image viewer with swipe support
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Listen to zoom changes
    _transformationController.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.0;
    if (zoomed != _isZoomed) {
      setState(() {
        _isZoomed = zoomed;
      });
    }
  }

  // Handle double-tap to zoom in/out
  // ignore: unused_element
  void _handleDoubleTap(TapDownDetails details, BuildContext context) {
    // Get the position where user tapped
    final position = details.localPosition;
    
    // Check current scale
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    
    if (currentScale > 1.0) {
      // If zoomed in, reset to normal
      _transformationController.value = Matrix4.identity();
    } else {
      // If not zoomed, zoom to 2.5x at tap position
      final double scale = 2.5;
      
      // Calculate the focal point for zoom
      final x = -position.dx * (scale - 1);
      final y = -position.dy * (scale - 1);
      
      _transformationController.value = Matrix4.identity()
        ..translate(x, y, 0)
        ..scale(scale, scale, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.imageUrls.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: hasMultiple
            ? Text(
                '${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: const TextStyle(color: Colors.white),
              )
            : null,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            physics: _isZoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                // Reset zoom when changing pages
                _transformationController.value = Matrix4.identity();
              });
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onDoubleTapDown: (details) => _handleDoubleTap(details, context),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  panEnabled: true,
                  scaleEnabled: true,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Page indicator dots (only if multiple images)
          if (hasMultiple)
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) {
                    final isActive = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.white54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
