import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../services/chat_service.dart';
import '../services/marketplace_service.dart';

class ProductDetailViewModel extends ChangeNotifier {
  final MarketplaceService _marketSvc = MarketplaceService();
  final ChatService _chatSvc = ChatService();

  Product _product;
  bool _busy = false;

  ProductDetailViewModel(this._product);

  Product get product => _product;
  bool get isBusy => _busy;

  bool get isMine {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me != null && me == _product.sellerId;
  }

  String get formattedPrice {
    final symbol = _product.currency == 'TL'
        ? '₺'
        : _product.currency == 'USD'
            ? '\$'
            : '€';
    return '$symbol${_product.price.toStringAsFixed(2)}';
  }

  Future<void> refresh() async {
    try {
      final updated = await _marketSvc.fetchProductById(_product.id);
      _product = updated;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing product: $e');
      // Still notify listeners so UI can respond to the failed refresh
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(BuildContext context) async {
    if (_busy) return;
    _setBusy(true);
    try {
      await _marketSvc.deleteProduct(_product.id);
      if (context.mounted) {
        Navigator.of(context).pop(); // Close dialog if open (handled in view)
        Navigator.of(context).pop(); // Close detail view
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing marked as sold.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not mark as sold: $e')),
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> reportUser(BuildContext context, String reason, String? details) async {
    if (_busy) return;
    _setBusy(true);
    try {
      await _marketSvc.reportProduct(
        productId: _product.id,
        reportedUserId: _product.sellerId,
        reason: reason,
        details: details,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
      }
    } on PostgrestException catch (e) {
      if (context.mounted) {
        if (e.code == '23505') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already reported this listing.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $e')),
        );
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> contactSeller(BuildContext context) async {
    if (_busy) return null;
    _setBusy(true);
    try {
      if (isMine) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This is your listing.')),
        );
        return null;
      }

      await _chatSvc.ensureMyLongTermKey();
      final convId = await _chatSvc.createOrGetDm(_product.sellerId);

      final text = StringBuffer()
        ..writeln('👋 Interested in your listing:')
        ..writeln('• ${_product.title}')
        ..writeln('• $formattedPrice')
        ..writeln('• Category: ${_product.category}');
      if ((_product.sizeValue ?? '').isNotEmpty) {
        text.writeln('• Size: ${_product.sizeValue}');
      }

      await _chatSvc.sendTextEncrypted(
        conversationId: convId,
        text: text.toString(),
      );
      
      return convId;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to contact: $e')),
        );
      }
      return null;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
