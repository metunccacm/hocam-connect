// lib/view/hitchike_detail_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:project/models/hitchike_post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import 'chat_view.dart';

/// View-only model (no driver fields here; service will resolve owner->driver)
class HitchikeDetailView extends StatefulWidget {
  final HitchikePost post;
  const HitchikeDetailView({super.key, required this.post});

  @override
  State<HitchikeDetailView> createState() => _HitchikeDetailViewState();
}

class _HitchikeDetailViewState extends State<HitchikeDetailView> {
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
  String? _driverImageUrl;

  @override
  void initState() {
    super.initState();
    _bindFromPost(widget.post);
    unawaited(_reloadFromServer());
  }

  void _bindFromPost(HitchikePost p) {
    _from = p.fromLocation;
    _to = p.toLocation;
    _dateTime = p.dateTime;
    _seats = p.seats;
    _fuelShared = p.fuelShared;
    _driverUserId = p.ownerId;
    _driverName = p.ownerName;
    _driverImageUrl = p.ownerImageUrl;
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

  /// owner join + auto-expire handled elsewhere
  Future<void> _reloadFromServer() async {
    try {
      final supa = Supabase.instance.client;
      final row = await supa
          .from('hitchike_posts_view')
          .select('from_location,'
              'to_location,'
              'date_time,'
              'seats,'
              'fuel_shared,'
              'owner_id,'
              'owner_name,'
              'owner_image_url:owner_image')
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
          final img = row['owner_image_url'] as String?;
          if (img != null && img.isNotEmpty) _driverImageUrl = img;
        });
      }
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
        messenger
            .showSnackBar(const SnackBar(content: Text('This is your post.')));
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
      if (_fuelShared == 1) {
        sb.writeln('• Fuel will be shared');
      } else if (_fuelShared == 0) sb.writeln('• Fuel will NOT be shared');

      await _svc.sendTextEncrypted(conversationId: convId, text: sb.toString());

      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatView(conversationId: convId, title: _driverName ?? 'Driver'),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;
    final onSurfaceVariant = cs.onSurfaceVariant;
    final whenText = _fmtDateTime(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Hitchhike',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.appBarTheme.foregroundColor ?? cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor ?? cs.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? cs.onSurface,
        elevation: 1,
        actions: const [
          // Add refresh if you expose manual refresh later
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
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                disabledBackgroundColor: cs.surfaceContainerHighest,
                disabledForegroundColor: onSurfaceVariant,
                minimumSize: const Size(double.infinity, 48),
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
        onRefresh: _reloadFromServer,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            // From / To
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: $_from',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          )),
                      const SizedBox(height: 4),
                      Text('To: $_to',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSurface,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // When
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  whenText,
                  style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Seats
            Row(
              children: [
                Icon(Icons.event_seat, size: 18, color: onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Empty seats: $_seats',
                  style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                ),
              ],
            ),

            // Fuel shared
            if (_fuelShared == 1) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.local_gas_station,
                      size: 18, color: onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Fuel will be shared',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: onSurface),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Driver (resolved via service on refresh)
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: (_driverImageUrl != null && _driverImageUrl!.isNotEmpty)
                      ? NetworkImage(_driverImageUrl!)
                      : null,
                  child: (_driverImageUrl == null || _driverImageUrl!.isEmpty)
                      ? Icon(Icons.person, color: onSurfaceVariant)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _driverName ?? 'Driver',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: onSurface,
                    ),
                  ),
                ),
              ],
            ),

            if (_isExpired) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This post has expired.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onErrorContainer),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '• This system is not designed for and cannot be used as a money earning system!',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
