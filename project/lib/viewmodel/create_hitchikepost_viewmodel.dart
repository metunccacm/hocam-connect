// lib/viewmodel/create_hitchhike_viewmodel.dart
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import '../services/hitchhike_service.dart';

class CreateHitchhikeViewModel extends ChangeNotifier {
  final _svc = HitchhikeService();

  bool _isListing = false;
  bool get isListing => _isListing;

  // Fixed options for the dropdowns
  final List<String> locationOptions = const [
    'Campus'
    'Kalkanlı',
    'Güzelyurt',
    'Lefkoşa',
    'Girne',
    'Mağusa',
    'İskele',
    'Lapta',
  ];

  // UI state (optional to bind spinners, etc.)
  void _setListing(bool v) {
    _isListing = v;
    notifyListeners();
  }

  /// Create (list) a hitchhike post.
  ///
  /// Expected form fields:
  /// - from_location: String (required)
  /// - to_location: String (required)
  /// - date_time: DateTime (preferred)  OR  date: DateTime + time: TimeOfDay
  /// - seats: int (1..5) (required)
  /// - fuel_shared: bool (optional; default false)
  Future<void> createPost(
    BuildContext context,
    GlobalKey<FormBuilderState> formKey,
  ) async {
    if (_isListing) return;
    _setListing(true);

    final form = formKey.currentState!;
    if (!form.saveAndValidate()) {
      _setListing(false);
      return;
    }

    try {
      final v = form.value;

      final String fromLoc = (v['from_location'] as String? ?? '').trim();
      final String toLoc = (v['to_location'] as String? ?? '').trim();

      // Prefer a single date_time field if the UI provides it
      DateTime? dateTime = v['date_time'] as DateTime?;

      // Otherwise combine separate date + time fields if present
      if (dateTime == null) {
        final DateTime? d = v['date'] as DateTime?;
        final TimeOfDay? t = v['time'] as TimeOfDay?;
        if (d != null && t != null) {
          dateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
        }
      }

      final int? seats = (v['seats'] is int)
          ? v['seats'] as int
          : int.tryParse((v['seats']?.toString() ?? '').trim());

      final bool fuelSharedBool = (v['fuel_shared'] as bool?) ?? false;
      final int fuelShared = fuelSharedBool ? 1 : 0;

      // ---------- Client-side validations ----------
      if (fromLoc.isEmpty) {
        _snack(context, 'Please choose the "From" location.');
        _setListing(false);
        return;
      }
      if (toLoc.isEmpty) {
        _snack(context, 'Please choose the "To" location.');
        _setListing(false);
        return;
      }
      if (fromLoc == toLoc) {
        _snack(context, 'From and To cannot be the same.');
        _setListing(false);
        return;
      }
      if (dateTime == null) {
        _snack(context, 'Please select a date and time.');
        _setListing(false);
        return;
      }
      if (dateTime.isBefore(DateTime.now())) {
        _snack(context, 'Date & time must be in the future.');
        _setListing(false);
        return;
      }
      if (seats == null || seats < 1 || seats > 5) {
        _snack(context, 'Please choose seats between 1 and 5.');
        _setListing(false);
        return;
      }

      // ---------- Service call ----------
      // Service will:
      // - attach driver (owner) from auth
      // - persist from/to/dateTime/seats/fuelShared
      // - ensure auto-deletion after date_time at DB level (trigger/RPC)
      await _svc.createHitchhikePost(
        fromLocation: fromLoc,
        toLocation: toLoc,
        dateTime: dateTime,
        seats: seats,
        fuelShared: fuelShared,
      );

      if (context.mounted) {
        _snack(context, 'Ride listed successfully.');
        Navigator.of(context).pop(); // close the create screen
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Listing failed: $e');
      }
    } finally {
      _setListing(false);
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
