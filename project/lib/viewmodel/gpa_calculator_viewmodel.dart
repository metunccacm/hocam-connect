// gpa_viewmodel.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your models from the view file you shared
// (SemesterModel and Course are defined there)
import '../view/gpa_calculator_view.dart';

/// ViewModel to load/save semester/course data from Supabase.
/// Expected table schema:
/// - id: bigint
/// - created_at: timestamptz
/// - record: json (shape shown below)
/// - user_id: uuid
///
/// record JSON shape:
/// {
///   "semesters": [
///     { "courses": [ { "name": "MAT 119", "grade": "AA", "credits": 5 }, ... ] },
///     ...
///   ]
/// }
class GpaViewModel extends ChangeNotifier {
  GpaViewModel({
    SupabaseClient? client,
    this.tableName = 'courses', // <-- set your table name
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String tableName;

  // ----- state
  bool _isLoading = false;
  String? _error;
  List<SemesterModel> _semesters = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SemesterModel> get semesters => _semesters;

  // Optionally keep the last loaded row id if you need it later
  int? _lastRowId;
  int? get lastRowId => _lastRowId;

  // ----------------- Public API -----------------

  /// Load the most recent GPA record for the currently signed-in user.
  Future<void> loadLatestForCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _setError('Not authenticated');
      return;
    }
    await loadLatestForUser(uid);
  }

  /// Load the most recent GPA record for a specific user id (uuid).
  Future<void> loadLatestForUser(String userId) async {
    _setLoading(true);
    try {
      final rows = await _client
          .from(tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1) as List<dynamic>;

      if (rows.isEmpty) {
        // No data yet: provide one empty semester with one empty course
        _semesters = [SemesterModel(courses: [Course.empty()])];
        _lastRowId = null;
        _clearError();
        _setLoading(false);
        return;
      }

      final row = rows.first as Map<String, dynamic>;
      _lastRowId = _asInt(row['id']);

      final record = row['record'];
      final Map<String, dynamic> recordMap =
          (record is String) ? jsonDecode(record) as Map<String, dynamic>
                             : (record as Map<String, dynamic>? ?? <String, dynamic>{});

      _semesters = _semestersFromRecord(recordMap);

      // Ensure at least one editable row exists
      if (_semesters.isEmpty) {
        _semesters = [SemesterModel(courses: [Course.empty()])];
      } else {
        for (final s in _semesters) {
          if (s.courses.isEmpty) s.courses.add(Course.empty());
        }
      }

      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Replace the ViewModel semesters from the UI (e.g., after user edits).
  /// Call this before `saveNewSnapshot()` if you keep UI state separately.
  void setSemestersFromUi(List<SemesterModel> updated) {
    _semesters = updated;
    notifyListeners();
  }

  /// Insert a NEW snapshot row for the current user with the current semesters.
  /// This does not overwrite older rows; it appends a new one.
  Future<void> saveNewSnapshot() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _setError('Not authenticated');
      return;
    }

    _setLoading(true);
    try {
      final payload = {
        'user_id': uid,
        'record': _semestersToRecordJson(_semesters),
      };

      final inserted = await _client
          .from(tableName)
          .insert(payload)
          .select()
          .single();

      _lastRowId = _asInt(inserted['id']);
      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ----------------- JSON (de)serialization helpers -----------------

  List<SemesterModel> _semestersFromRecord(Map<String, dynamic> record) {
    final list = (record['semesters'] as List? ?? const []);
    return list.map((s) {
      final sMap = (s as Map<String, dynamic>);
      final courseList = (sMap['courses'] as List? ?? const []);
      final courses = courseList.map<Course>((c) {
        final m = (c as Map<String, dynamic>);
        final name = (m['name'] ?? '').toString();
        final grade = m['grade'] as String?;
        final credits = _asInt(m['credits']) ?? 0;
        return Course(
          nameCtrl: TextEditingController(text: name),
          creditCtrl: TextEditingController(text: credits == 0 ? '' : '$credits'),
          grade: grade,
          credits: credits,
        );
      }).toList();

      return SemesterModel(courses: courses);
    }).toList();
  }

  Map<String, dynamic> _semestersToRecordJson(List<SemesterModel> semesters) {
    return {
      'semesters': semesters.map((s) {
        return {
          'courses': s.courses.map((c) {
            // pull values from controllers so UI text is persisted
            final name = c.nameCtrl.text.trim();
            final grade = c.grade;
            final credits = c.credits; // already kept in sync in your UI
            return {
              'name': name,
              'grade': grade,
              'credits': credits,
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  // ----------------- state helpers -----------------

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void _clearError() => _setError(null);

  // ----------------- utils -----------------

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
