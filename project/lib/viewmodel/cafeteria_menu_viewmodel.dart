import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeteriaMenu {
  CafeteriaMenu({
    required this.day,
    required this.lunch,
    required this.dinner,
  });

  final DateTime day;
  final List<String> lunch;
  final List<String> dinner;

  factory CafeteriaMenu.fromMap(Map<String, dynamic> row) {
    // Supabase date comes as String 'YYYY-MM-DD' or DateTime depending on driver
    final dynamic dayRaw = row['day'];
    final DateTime day = switch (dayRaw) {
      DateTime d => DateTime(d.year, d.month, d.day),
      String s => DateTime.parse(s),
      _ => DateTime.now(),
    };

    List<String> castList(dynamic v) {
      if (v == null) return const <String>[];
      if (v is List) return v.map((e) => e.toString()).toList();
      // if stored as {"items": [...] } by mistake, try best-effort
      if (v is Map && v['items'] is List) {
        return (v['items'] as List).map((e) => e.toString()).toList();
      }
      return const <String>[];
    }

    return CafeteriaMenu(
      day: DateTime(day.year, day.month, day.day),
      lunch: castList(row['lunch']),
      dinner: castList(row['dinner']),
    );
  }
}

class CafeteriaMenuViewModel extends ChangeNotifier {
  CafeteriaMenuViewModel({
    SupabaseClient? client,
    this.tableName = 'cafeteria_menu',
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String tableName;

  bool isLoading = false;
  String? errorMessage;

  /// Monday=0 … Sunday=6
  final Map<int, CafeteriaMenu> _byWeekday = {};

  /// The Monday of the currently loaded ISO week (no timezone issues)
  late DateTime _weekStart;

  RealtimeChannel? _channel;

  Map<int, CafeteriaMenu> get menusByWeekday => _byWeekday;
  DateTime get weekStart => _weekStart;

  /// Public API --------------------------------------------------------------

  Future<void> loadCurrentWeek() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: (now.weekday - 1))); // Mon-based
    await loadWeek(startOfWeekMonday(monday));
  }

  Future<void> loadWeek(DateTime monday) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    _weekStart = startOfWeekMonday(monday);
    final startStr = _yyyyMmDd(_weekStart);
    final endStr = _yyyyMmDd(_weekStart.add(const Duration(days: 6)));

    print('Debug - Loading week from $startStr to $endStr');
    print('Debug - Table name: $tableName');

    try {
      
      final rows = await _client
          .from(tableName)
          .select()
          .gte('day', startStr)
          .lte('day', endStr)
          .order('day', ascending: true);
      
      _byWeekday.clear();
      for (final r in rows as List) {
        final menu = CafeteriaMenu.fromMap(r as Map<String, dynamic>);
        final idx = (menu.day.weekday - 1); // 0..6
        _byWeekday[idx] = menu;
      }

      // set up realtime once (or recreate for safety)
      await _setupRealtime();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  CafeteriaMenu? menuForIndex(int weekdayIndex) => _byWeekday[weekdayIndex];

  List<String> lunchFor(int weekdayIndex) =>
      _byWeekday[weekdayIndex]?.lunch ?? const <String>[];

  List<String> dinnerFor(int weekdayIndex) =>
      _byWeekday[weekdayIndex]?.dinner ?? const <String>[];

  Future<void> refresh() => loadWeek(_weekStart);

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  // Helpers -----------------------------------------------------------------

  DateTime startOfWeekMonday(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  String _yyyyMmDd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _setupRealtime() async {
    _channel?.unsubscribe();
    _channel = _client.channel('cafeteria-menu-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: tableName,
        callback: (payload) {
          // If change touches our loaded week, minimally merge it, else ignore.
          try {
            final newRow = payload.newRecord;
            final oldRow = payload.oldRecord;
            Map<String, dynamic>? row;
            if (newRow.isNotEmpty) {
              row = Map<String, dynamic>.from(newRow);
            } else if (oldRow.isNotEmpty) {
              row = Map<String, dynamic>.from(oldRow);
            }
            if (row == null) return;

            final menu = CafeteriaMenu.fromMap(row);
            final inWeek = !menu.day.isBefore(_weekStart) &&
                !menu.day.isAfter(_weekStart.add(const Duration(days: 6)));
            if (!inWeek) return;

            final idx = menu.day.weekday - 1;
            if (payload.eventType == PostgresChangeEvent.delete) {
              _byWeekday.remove(idx);
            } else {
              _byWeekday[idx] = menu;
            }
            notifyListeners();
          } catch (_) {
            // swallow – realtime is best-effort
          }
        },
      )
      ..subscribe();
  }
}
