// gpa_calculator_viewmodel.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your SemesterModel / Course definitions (from your view file)
import '../view/gpa_calculator_view.dart' show SemesterModel, Course;
import '../view/profile_view.dart';

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
  List<SemesterModel> _semesters = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
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
      final rows = await _client
          .from(tableName)
          .select()
          .eq('user_id', uid)
          .limit(1);

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
    } catch (e) {
      _setError(e.toString());
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

      // onConflict by 'user_id' ensures single row per user
      await _client
          .from(tableName)
          .upsert(payload, onConflict: 'user_id')
          .select() // return the row for sanity
          .single();

      _clearError();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Sync courses from department_courses table based on user's department.
  Future<List<SemesterModel>> syncFromDepartmentCourses(BuildContext context) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      _setError('Not authenticated');
      return [];
    }

    _setLoading(true);
    try {
      // 1. Fetch user's department from profiles table
      final profileData = await _client
          .from('profiles')
          .select('department')
          .eq('id', uid)
          .maybeSingle();

      if (profileData == null) {
        _setError('Profile not found');
        return [];
      }

      final department = (profileData['department'] ?? '').toString().trim();
      if (department.isEmpty) {
        _setError('Department not set in profile');
        // Show dialog prompting user to update department
        if (context.mounted) {
          await _showDepartmentNotSetDialog(context);
        }
        return [];
      }

      // Debug: print what we're searching for
      debugPrint('GPA Sync: Searching for department="$department" (length: ${department.length})');

      // 2. Fetch department courses filtered by department (case-insensitive)
      final coursesData = await _client
          .from('department_courses')
          .select('semester, course_code, credits, department')
          .ilike('department', department) // case-insensitive match
          .order('semester', ascending: true)
          .order('course_code', ascending: true);

      debugPrint('GPA Sync: Found ${coursesData.length} courses');

      if (coursesData.isEmpty) {
        // Try to get a sample of what departments exist for debugging
        try {
          final allCourses = await _client
              .from('department_courses')
              .select('department')
              .limit(10);
          
          debugPrint('GPA Sync: Total rows in sample: ${allCourses.length}');
          
          if (allCourses.isEmpty) {
            _setError('The department_courses table is empty. Please contact support.');
            return [];
          }
          
          final uniqueDepts = <String>{};
          for (final row in allCourses) {
            final dept = (row['department'] ?? '').toString();
            debugPrint('GPA Sync: Found department in table: "$dept" (length: ${dept.length})');
            if (dept.isNotEmpty) uniqueDepts.add(dept);
          }
          _setError('No courses found for department: "$department".');
        } catch (e) {
          _setError('No courses found for department: "$department". Could not fetch available departments: $e');
        }
        return [];
      }

      // 3. Group courses by semester
      final Map<int, List<Map<String, dynamic>>> semesterMap = {};
      for (final row in coursesData) {
        final sem = _asInt(row['semester']) ?? 0;
        semesterMap.putIfAbsent(sem, () => []).add(row);
      }

      // 4. Build SemesterModel list
      final List<SemesterModel> newSemesters = [];
      final sortedSemesters = semesterMap.keys.toList()..sort();

      for (final semNum in sortedSemesters) {
        final courses = semesterMap[semNum]!.map<Course>((c) {
          final courseCode = (c['course_code'] ?? '').toString();
          final credits = _asInt(c['credits']) ?? 0;
          return Course(
            nameCtrl: TextEditingController(text: courseCode),
            creditCtrl: TextEditingController(text: '$credits'),
            grade: null, // User will fill grade
            credits: credits,
          );
        }).toList();

        newSemesters.add(SemesterModel(
          courses: courses,
          name: 'Semester $semNum',
        ));
      }

      _clearError();
      return newSemesters;
    } catch (e) {
      _setError(e.toString());
      return [];
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
        creditCtrl: TextEditingController(text: '$credits'),
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

  // ----------------- Dialog utils -----------------
  Future<void> _showDepartmentNotSetDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Department Not Set'),
          content: const Text(
            'Please update your department in your profile to sync courses for your program.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileView(),
                  ),
                );
              },
              child: const Text('Go to Profile'),
            ),
          ],
        );
      },
    );
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
