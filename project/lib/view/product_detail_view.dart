// lib/view/product_detail_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

import '../models/product.dart';
import '../viewmodel/product_detail_viewmodel.dart';
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
  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final TextEditingController _reportDetailsCtrl = TextEditingController();

  PageController? _pager;
  VoidCallback? _pagerListener;
  int _pageIx = 0;

  late final ProductDetailViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ProductDetailViewModel(widget.product);
    _createPager(initialPage: 0);
    unawaited(_warmImages(widget.product.imageUrls));
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
    _viewModel.dispose();
    _reportDetailsCtrl.dispose();
    if (_pagerListener != null && _pager != null) {
      _pager!.removeListener(_pagerListener!);
    }
    _pager?.dispose();
    super.dispose();
  }

  Future<void> _warmImages(List<String> urls) async {
    for (final u in urls.skip(1)) {
      unawaited(DefaultCacheManager().getSingleFile(u));
    }
  }

  Future<void> _reportUser(ProductDetailViewModel vm) async {
    if (vm.isBusy) return;
    if (vm.isMine) {
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      await vm.reportUser(context, selected, _reportDetailsCtrl.text.trim().isEmpty ? null : _reportDetailsCtrl.text.trim());
    }
  }

  Future<void> _openEdit(ProductDetailViewModel vm) async {
    final p = vm.product;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProductView(
          productId: p.id,
          initialTitle: p.title,
          initialDescription: p.description,
          initialPrice: p.price,
          initialCurrency: p.currency,
          initialCategory: p.category,
          initialSizeValue: p.sizeValue,
          initialImageUrls: p.imageUrls,
        ),
      ),
    );

    if (changed == true && mounted) {
      _refreshKey.currentState?.show();
      await vm.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Listing updated')));
    }
  }

  Future<void> _markAsSold(ProductDetailViewModel vm) async {
    if (vm.isBusy) return;
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
    if (ok == true && mounted) {
      await vm.deleteProduct(context);
    }
  }

  Future<void> _contactSeller(ProductDetailViewModel vm) async {
    final convId = await vm.contactSeller(context);
    if (convId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatView(conversationId: convId, title: vm.product.sellerName),
        ),
      );
    }
  }

  Color _dotsColor({required bool active}) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return active ? Colors.white.withValues(alpha: 0.95) : Colors.white70;
    } else {
      return active ? Colors.black87 : Colors.black45;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ProductDetailViewModel>.value(
      value: _viewModel,
      child: Consumer<ProductDetailViewModel>(
        builder: (context, vm, _) {
          final p = vm.product;
          final imgs = p.imageUrls;
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
                p.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
              foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
              elevation: 1,
              actions: [
                if (!vm.isMine)
                  IconButton(
                    tooltip: 'Report',
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: vm.isBusy ? null : () => _reportUser(vm),
                  ),
                if (vm.isMine)
                  IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: vm.isBusy ? null : () => _openEdit(vm),
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
                    onPressed: vm.isBusy
                        ? null
                        : (vm.isMine ? () => _markAsSold(vm) : () => _contactSeller(vm)),
                    icon: Icon(
                        vm.isMine ? Icons.check_circle_outline : Icons.send_rounded,
                        size: 20),
                    label: Text(
                      vm.isMine ? 'Mark as sold' : 'Contact Hocam',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: vm.isMine ? cs.error : cs.primary,
                      foregroundColor: vm.isMine ? cs.onError : cs.onPrimary,
                      minimumSize: const Size(double.infinity, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),

            body: RefreshIndicator(
              key: _refreshKey,
              color: cs.primary,
              backgroundColor: cs.surface,
              onRefresh: vm.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
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
                    p.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vm.formattedPrice,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (p.description.isNotEmpty)
                    Text(
                      p.description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.surfaceContainerHighest,
                        backgroundImage: p.sellerImageUrl.isNotEmpty ? NetworkImage(p.sellerImageUrl) : null,
                        child: p.sellerImageUrl.isEmpty
                            ? Icon(Icons.person, color: onSurfaceVariant)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                        ),
                      ),
                    ],
                  ),
                  if ((p.sizeValue ?? '').isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Size: ${p.sizeValue}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
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
