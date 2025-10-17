// gpa_calculator_viewmodel.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/network_error_handler.dart';

// Import your SemesterModel / Course definitions (from your view file)
import '../view/gpa_calculator_view.dart' show SemesterModel, Course;

class GpaViewModel extends ChangeNotifier {
  GpaViewModel({
    SupabaseClient? client,
    this.tableName = 'courses', // your table
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String tableName;

  // ---- state
  bool _isLoading = false;
  String? _error;
  bool _hasNetworkError = false;
  List<SemesterModel> _semesters = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasNetworkError => _hasNetworkError;
  List<SemesterModel> get semesters => _semesters;

  // ----------------- Public API -----------------

  /// Load the user's single row (by user_id PK). If none, provide one editable semester.
  Future<void> loadLatestForCurrentUser() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _setError('Not authenticated');
      return;
    }
    _setLoading(true);
    try {
      final rows = await NetworkErrorHandler.handleNetworkCall(
        () async {
          return await _client
              .from(tableName)
              .select()
              .eq('user_id', uid)
              .limit(1);
        },
        context: 'Failed to load GPA data',
      );

      if (rows.isEmpty) {
        _semesters = [SemesterModel(courses: [Course.empty()])];
        _clearError();
      } else {
        final row = rows.first;
        final record = row['record'];
        final Map<String, dynamic> recordMap =
            (record is String) ? jsonDecode(record) as Map<String, dynamic>
                               : (record as Map<String, dynamic>? ?? <String, dynamic>{});
        _semesters = _semestersFromRecord(recordMap);

        if (_semesters.isEmpty) {
          _semesters = [SemesterModel(courses: [Course.empty()])];
        } else {
          for (final s in _semesters) {
            if (s.courses.isEmpty) s.courses.add(Course.empty());
          }
        }
        _clearError();
      }
    } on HC50Exception catch (e) {
      _setError(e.message);
      _hasNetworkError = true;
    } catch (e) {
      _setError(e.toString());
      _hasNetworkError = false;
    } finally {
      _setLoading(false);
    }
  }

  /// Replace VM semesters from current UI prior to saving.
  void setSemestersFromUi(List<SemesterModel> updated) {
    _semesters = updated;
    notifyListeners();
  }

  /// Save with **upsert on user_id** (works because user_id is PRIMARY KEY).
  Future<void> saveSnapshot() async {
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

      await NetworkErrorHandler.handleNetworkCall(
        () async {
          // onConflict by 'user_id' ensures single row per user
          await _client
              .from(tableName)
              .upsert(payload, onConflict: 'user_id')
              .select() // return the row for sanity
              .single();
        },
        context: 'Failed to save GPA data',
      );

      _clearError();
    } on HC50Exception catch (e) {
      _setError(e.message);
      _hasNetworkError = true;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ----------------- JSON helpers -----------------

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

    // NEW: pick semester name if present
    final semName = (sMap['name'] ?? '').toString();

    return SemesterModel(courses: courses, name: semName);
  }).toList();
}

Map<String, dynamic> _semestersToRecordJson(List<SemesterModel> semesters) {
  return {
    'semesters': semesters.map((s) {
      return {
        'name': s.name, // NEW
        'courses': s.courses.map((c) {
          return {
            'name': c.nameCtrl.text.trim(),
            'grade': c.grade,
            'credits': c.credits,
          };
        }).toList(),
      };
    }).toList(),
  };
}

  // ----------------- state utils -----------------
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  void _clearError() => _setError(null);

  // ----------------- misc utils -----------------
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
