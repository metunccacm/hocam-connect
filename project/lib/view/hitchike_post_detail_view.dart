// lib/view/hitchhike_detail_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'chat_view.dart';

/// View-only model (no driver fields here; service will resolve owner->driver)
class HitchhikePost {
  final String id;
  final String fromLocation; // Where the car is leaving from
  final String toLocation;   // Where the car is headed to 
  final DateTime dateTime;
  final int seats;
  final int fuelShared; // 0 or 1

  HitchhikePost({
    required this.id,
    required this.fromLocation,
    required this.toLocation,
    required this.dateTime,
    required this.seats,
    required this.fuelShared,
  });
}

class HitchhikeDetailView extends StatefulWidget {
  final HitchhikePost post;
  const HitchhikeDetailView({super.key, required this.post});

  @override
  State<HitchhikeDetailView> createState() => _HitchhikeDetailViewState();
}

class _HitchhikeDetailViewState extends State<HitchhikeDetailView> {
  final _svc = ChatService();
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  bool _busy = false;

  // local state (refresh can update these)
  late String _from;
  late String _to;
  late DateTime _dateTime;
  late int _seats;
  late int _fuelShared; // 0/1

  // Resolved via service join (owner -> profile). Not part of constructor.
  String? _driverUserId;
  String? _driverName;

  @override
  void initState() {
    super.initState();
    _bindFromPost(widget.post);
    // Optionally preload fresh owner/profile info
    unawaited(_reloadFromServer());
  }

  void _bindFromPost(HitchhikePost p) {
    _from = p.fromLocation;
    _to = p.toLocation;
    _dateTime = p.dateTime;
    _seats = p.seats;
    _fuelShared = p.fuelShared;
  }

  bool get _isMine {
    final me = Supabase.instance.client.auth.currentUser?.id;
    return me != null && me == _driverUserId;
  }

  bool get _isExpired => DateTime.now().isAfter(_dateTime);

  String _fmtDateTime(BuildContext ctx) {
    final t = TimeOfDay.fromDateTime(_dateTime).format(ctx);
    final dd = _dateTime.day.toString().padLeft(2, '0');
    final mm = _dateTime.month.toString().padLeft(2, '0');
    final yyyy = _dateTime.year.toString();
    return "$dd.$mm.$yyyy, $t";
  }

  Future<void> _manualRefresh() async {
    _refreshKey.currentState?.show();
    await _reloadFromServer();
  }

  /// TODO (Service later): owner join + auto-expire delete at DB level
  Future<void> _reloadFromServer() async {
    try {
      final supa = Supabase.instance.client;

      // NOTE: Adjust table/columns to your schema.
      // Expecting a view or select that already joins owner -> profile
      // and can optionally auto-delete expired rows via trigger/RPC (to be done in Service/DB).
      final row = await supa
          .from('hitchhike_posts') // TODO: replace with your table/view
          .select('''
            from_location,
            to_location,
            date_time,
            seats,
            fuel_shared,
            owner_id,         -- profile/user id of the post owner
            owner_name        -- resolved name from profiles (service/DB side)
          ''')
          .eq('id', widget.post.id)
          .maybeSingle();

      if (row is Map<String, dynamic>) {
        setState(() {
          _from = (row['from_location'] as String?) ?? _from;
          _to = (row['to_location'] as String?) ?? _to;

          final dtRaw = row['date_time'];
          if (dtRaw != null) {
            if (dtRaw is String) {
              _dateTime = DateTime.tryParse(dtRaw) ?? _dateTime;
            } else if (dtRaw is DateTime) {
              _dateTime = dtRaw;
            }
          }

          _seats = (row['seats'] as num?)?.toInt() ?? _seats;
          _fuelShared = (row['fuel_shared'] as num?)?.toInt() ?? _fuelShared;

          _driverUserId = row['owner_id'] as String?;
          _driverName = (row['owner_name'] as String?) ?? _driverName;
        });
      }

      // Optional: if expired, you might navigate back. We will only hint in UI here.
      // Actual deletion (DB + app) will be implemented in Service/DB.
    } catch (_) {
      // silent
    }
  }

  Future<void> _contactDriver() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me == null) throw Exception('Not authenticated');

      if (_isMine) {
        messenger.showSnackBar(const SnackBar(content: Text('This is your post.')));
        return;
      }

      if (_driverUserId == null) {
        throw Exception('Driver could not be resolved yet. Try refreshing.');
      }

      await _svc.ensureMyLongTermKey();
      final convId = await _svc.createOrGetDm(_driverUserId!);

      final sb = StringBuffer()
        ..writeln('👋 Interested in your ride:')
        ..writeln('• From: $_from')
        ..writeln('• To: $_to')
        ..writeln('• When: ${_fmtDateTime(context)}')
        ..writeln('• Empty seats: $_seats');
      if (_fuelShared == 1) sb.writeln('• Fuel will be shared');
      else if (_fuelShared == 0) sb.writeln('• Fuel will NOT be shared');
      
      await _svc.sendTextEncrypted(conversationId: convId, text: sb.toString());

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatView(conversationId: convId, title: _driverName ?? 'Driver'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to contact: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final whenText = _fmtDateTime(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hitchhike'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          // IconButton(
          //   tooltip: 'Refresh',
          //   onPressed: _manualRefresh,
          //   icon: const Icon(Icons.refresh),
          // ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy || _isMine || _isExpired ? null : _contactDriver,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isMine
                    ? 'This is your post'
                    : _isExpired
                        ? 'Post expired'
                        : 'Contact Hocam',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _reloadFromServer,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            // From / To
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: $_from', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('To: $_to'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // When
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 8),
                Text(whenText),
              ],
            ),
            const SizedBox(height: 8),

            // Seats
            Row(
              children: [
                const Icon(Icons.event_seat, size: 18),
                const SizedBox(width: 8),
                Text('Empty seats: $_seats'),
              ],
            ),

            // Fuel shared
            if (_fuelShared == 1) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.local_gas_station, size: 18),
                  SizedBox(width: 8),
                  Text('Fuel will be shared'),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Driver (resolved via service on refresh)
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _driverName ?? 'Driver',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            if (_isExpired) ...[
              const SizedBox(height: 16),
              Text(
                'This post has expired.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            const SizedBox(height: 16),
            Text(
              '• This system is not designed for and cannot be used as a money earning system!',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }
}
