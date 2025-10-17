// gpa_calculator_view.dart
import 'dart:async'; // for unawaited
import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'package:flutter/services.dart';
import 'package:project/viewmodel/gpa_calculator_viewmodel.dart';
import 'package:project/models/gpa_models.dart'; // Use shared models
import 'package:project/view/profile_view.dart'; // For navigation to profile

class GpaCalculatorView extends StatefulWidget {
  const GpaCalculatorView({super.key});

  @override
  State<GpaCalculatorView> createState() => _GpaCalculatorViewState();
}

class _GpaCalculatorViewState extends State<GpaCalculatorView> {
  late final GpaViewModel vm;
  bool _isLoading = true;
  bool _isSaving = false;

  // --- inline semester-name editing (no dialog)
  final Map<int, TextEditingController> _semNameCtrls = {};
  final Set<int> _editingSemesters = {};

  // Generate a light, faded color for each semester based on index
  Color _getSemesterColor(int index, BuildContext context) {
    // Predefined pastel/light colors that work well with both light and dark themes
    final lightColors = [
      const Color(0xFFBBDEFB), // Light blue (more vibrant)
      const Color(0xFFE1BEE7), // Light purple (more vibrant)
      const Color(0xFFC8E6C9), // Light green (more vibrant)
      const Color(0xFFFFE0B2), // Light orange (more vibrant)
      const Color(0xFFF8BBD0), // Light pink (more vibrant)
      const Color(0xFFDCEDC8), // Light lime (more vibrant)
      const Color(0xFFB2EBF2), // Light cyan (more vibrant)
      const Color(0xFFFFF59D), // Light yellow (more vibrant)
      const Color(0xFFD1C4E9), // Light deep purple (more vibrant)
      const Color(0xFFFFE082), // Light amber (more vibrant)
    ];

    final darkColors = [
      const Color(0xFF1E3A5F), // Dark blue
      const Color(0xFF4A148C), // Dark purple
      const Color(0xFF1B5E20), // Dark green
      const Color(0xFFE65100), // Dark orange
      const Color(0xFF880E4F), // Dark pink
      const Color(0xFF33691E), // Dark lime
      const Color(0xFF006064), // Dark cyan
      const Color(0xFFF57F17), // Dark yellow
      const Color(0xFF311B92), // Dark deep purple
      const Color(0xFFFF6F00), // Dark amber
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? darkColors : lightColors;
    final baseColor = colors[index % colors.length];

    // Make it even more faded/lighter for light theme
    if (!isDark) {
      return Color.alphaBlend(
        baseColor.withValues(alpha: 0.5),
        Theme.of(context).colorScheme.surface,
      );
    } else {
      // For dark theme, make it more subtle
      return Color.alphaBlend(
        baseColor.withValues(alpha: 0.15),
        Theme.of(context).colorScheme.surface,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    vm = GpaViewModel(tableName: 'courses'); // using your chosen table

    vm.loadLatestForCurrentUser().then((_) {
      if (!mounted) return;
      setState(() {
        semesters
          ..clear()
          ..addAll(vm.semesters.isEmpty
              ? [SemesterModel(courses: [Course.empty()], colorIndex: 0)]
              : vm.semesters);
        _isLoading = false;
      });
      if (vm.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading GPA data: ${vm.error}')),
        );
      }
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading GPA data: $e')),
      );
    });
  }

  @override
  void deactivate() {
    // Save state when widget is about to be removed from the tree
    // Using unawaited() to explicitly mark this as intentional fire-and-forget
    unawaited(_autoSave().catchError((e) {
      // Log error silently, don't show to user during deactivate
      debugPrint('Auto-save error during deactivate: $e');
      return; // Return void to satisfy catchError
    }));
    super.deactivate();
  }

  @override
  void dispose() {
    // dispose semester-name controllers used for inline editing
    for (final ctrl in _semNameCtrls.values) {
      ctrl.dispose();
    }
    // dispose course controllers
    for (final s in semesters) {
      for (final c in s.courses) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // Editable grade scale
  static const Map<String, double> gradeToPoint = {
    'AA': 4.0,
    'BA': 3.5,
    'BB': 3.0,
    'CB': 2.5,
    'CC': 2.0,
    'DC': 1.5,
    'DD': 1.0,
    'FD': 0.5,
    'FF': 0.0,
  };

  // Non-Credit grade scale
  static const Map<String, double> nonCreditGradeToPoint = {
    'EX': 0.0,
    'S': 0.0,
    'U': 0.0,
  };

  final List<SemesterModel> semesters = [
    SemesterModel(courses: [Course.empty(), Course.empty()], colorIndex: 0),
    SemesterModel(courses: [Course.empty()], colorIndex: 1),
  ];

  // ---- helpers --------------------------------------------------------------

  // Get the next available color index that's not currently used
  int _getNextColorIndex() {
    final usedIndices = semesters.map((s) => s.colorIndex).toSet();
    // Find the first index (0-9) not in use, or use the count as fallback
    for (var i = 0; i < 10; i++) {
      if (!usedIndices.contains(i)) return i;
    }
    return semesters.length % 10; // Fallback if all 10 colors are used
  }

  bool _isActive(Course c) =>
      c.nameCtrl.text.trim().isNotEmpty && c.grade != null && c.credits >= 0;

  // Normalize a course name for duplicate detection
  String _norm(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  // Build occurrences map for active courses: name -> list of (sIdx,cIdx)
  Map<String, List<(int sIdx, int cIdx)>> _activeOccurrences() {
    final map = <String, List<(int, int)>>{};
    for (int si = 0; si < semesters.length; si++) {
      for (int ci = 0; ci < semesters[si].courses.length; ci++) {
        final c = semesters[si].courses[ci];
        if (!_isActive(c)) continue;
        final key = _norm(c.nameCtrl.text);
        map.putIfAbsent(key, () => []).add((si, ci));
      }
    }
    return map;
  }

  // For CGPA until sIdx: return a set of (si,ci) to EXCLUDE
  Set<(int, int)> _excludedForCgpaPrefix(int sIdx) {
    final ex = <(int, int)>{};
    final occ = _activeOccurrences();
    for (final entries in occ.values) {
      final prefix = entries.where((t) => t.$1 <= sIdx).toList();
      if (prefix.length <= 1) continue;
      for (int i = 0; i < prefix.length - 1; i++) {
        ex.add(prefix[i]);
      }
    }
    return ex;
  }

  bool _isLatestOverall(int sIdx, int cIdx) {
    final c = semesters[sIdx].courses[cIdx];
    if (!_isActive(c)) return false;
    final key = _norm(c.nameCtrl.text);
    final occ = _activeOccurrences()[key] ?? const [];
    if (occ.isEmpty) return false;
    final last = occ.last;
    return last.$1 == sIdx && last.$2 == cIdx;
  }

  // Which prior semester *names* does this latest attempt replace?
  List<String> _replacesSemestersOverall(int sIdx, int cIdx) {
    final c = semesters[sIdx].courses[cIdx];
    if (!_isActive(c)) return const [];
    final key = _norm(c.nameCtrl.text);
    final occ = _activeOccurrences()[key] ?? const [];
    if (occ.isEmpty) return const [];
    final last = occ.last;
    if (last.$1 != sIdx || last.$2 != cIdx) return const [];
    final priorNames = occ.take(occ.length - 1).map((t) {
      final sem = semesters[t.$1];
      return sem.name.isNotEmpty ? sem.name : 'Semester #${t.$1 + 1}';
    }).toList();
    return priorNames;
  }

  // NEW: if a course row is not the latest, return the later semester's name
  String? _laterSemesterNameFor(int sIdx, int cIdx) {
    final c = semesters[sIdx].courses[cIdx];
    if (!_isActive(c)) return null;
    final key = _norm(c.nameCtrl.text);
    final occ = _activeOccurrences()[key] ?? const [];
    if (occ.isEmpty) return null;
    final last = occ.last;
    if (last.$1 == sIdx && last.$2 == cIdx) return null; // this row is latest
    final sem = semesters[last.$1];
    return sem.name.isNotEmpty ? sem.name : 'Semester #${last.$1 + 1}';
  }

  double _semesterGpa(int sIdx) {
    // semester GPA keeps all active courses that term
    // Non-credit courses (credits = 0) are excluded from GPA calculation
    final active = semesters[sIdx].courses.where(_isActive);
    double qp = 0, cr = 0;
    for (final c in active) {
      // Skip non-credit courses in GPA calculation
      if (c.credits == 0) continue;
      
      final pts = gradeToPoint[c.grade] ?? 0.0;
      qp += pts * c.credits;
      cr += c.credits;
    }
    return cr == 0 ? 0 : qp / cr;
  }

  /// CGPA cumulative until and including semester sIdx (replacement rule)
  double _cgpaUntil(int sIdx) {
    final excluded = _excludedForCgpaPrefix(sIdx);
    double qp = 0, cr = 0;
    for (int si = 0; si <= sIdx; si++) {
      for (int ci = 0; ci < semesters[si].courses.length; ci++) {
        final c = semesters[si].courses[ci];
        if (!_isActive(c)) continue;
        if (excluded.contains((si, ci))) continue;
        
        // Skip non-credit courses in CGPA calculation
        if (c.credits == 0) continue;
        
        final pts = gradeToPoint[c.grade] ?? 0.0;
        qp += pts * c.credits;
        cr += c.credits;
      }
    }
    return cr == 0 ? 0 : qp / cr;
  }

  void _addSemester() {
    setState(() {
      final colorIndex = _getNextColorIndex();
      semesters.add(SemesterModel(
        courses: [Course.empty(), Course.empty()],
        colorIndex: colorIndex,
      ));
    });
  }

  // NEW: delete an entire semester (with confirmation)
  Future<void> _deleteSemester(int sIdx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete semester?'),
        content: const Text('This will remove the semester and its courses.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      // dispose course controllers
      for (final c in semesters[sIdx].courses) {
        c.dispose();
      }
      semesters.removeAt(sIdx);

      // clear any inline-edit state (simplest + safest after index shift)
      for (final ctrl in _semNameCtrls.values) {
        ctrl.dispose();
      }
      _semNameCtrls.clear();
      _editingSemesters.clear();
    });
  }

  void _addCourse(int sIdx) {
    setState(() => semesters[sIdx].courses.add(Course.empty()));
  }

  void _removeCourse(int sIdx, int cIdx) {
    setState(() {
      semesters[sIdx].courses[cIdx].dispose();
      semesters[sIdx].courses.removeAt(cIdx);

      // NEW: auto-delete semester if no courses remain
      if (semesters[sIdx].courses.isEmpty) {
        // Dispose sem-name editor state for this index
        _semNameCtrls.remove(sIdx)?.dispose();
        _editingSemesters.remove(sIdx);
        semesters.removeAt(sIdx);

        // After index shift, safest is to reset editor maps
        for (final ctrl in _semNameCtrls.values) {
          ctrl.dispose();
        }
        _semNameCtrls.clear();
        _editingSemesters.clear();
      }
    });
  }

  // --- inline edit controls for semester name --------------------------------
  void _beginEditSemName(int sIdx) {
    final current = semesters[sIdx].name.isNotEmpty
        ? semesters[sIdx].name
        : 'Semester #${sIdx + 1}';
    _semNameCtrls[sIdx]?.dispose();
    _semNameCtrls[sIdx] = TextEditingController(text: current);
    setState(() => _editingSemesters.add(sIdx));
  }

  void _commitEditSemName(int sIdx) {
    final text = _semNameCtrls[sIdx]?.text.trim() ?? '';
    setState(() {
      semesters[sIdx].name = text;
      _editingSemesters.remove(sIdx);
    });
    _semNameCtrls.remove(sIdx)?.dispose();
  }

  void _cancelEditSemName(int sIdx) {
    setState(() => _editingSemesters.remove(sIdx));
    _semNameCtrls.remove(sIdx)?.dispose();
  }

  // ---- semester reordering ---------------------------------------------------
  void _moveSemesterUp(int sIdx) {
    if (sIdx == 0) return; // Already at top
    setState(() {
      final temp = semesters[sIdx];
      semesters[sIdx] = semesters[sIdx - 1];
      semesters[sIdx - 1] = temp;
    });
  }

  void _moveSemesterDown(int sIdx) {
    if (sIdx >= semesters.length - 1) return; // Already at bottom
    setState(() {
      final temp = semesters[sIdx];
      semesters[sIdx] = semesters[sIdx + 1];
      semesters[sIdx + 1] = temp;
    });
  }

  // ---- Auto-save (silent, no UI feedback) ------------------------------------
  
  Future<void> _autoSave() async {
    // Silent save without UI updates
    vm.setSemestersFromUi(semesters);
    await vm.saveSnapshot();
  }

  // ---- Sync from department courses -----------------------------------------

  Future<void> _syncFromDepartment() async {
    if (_isSaving) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync from Department Courses'),
        content: const Text(
          'Your current record will be replaced. This will load courses from your department\'s curriculum. You can still edit grades after syncing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final result = await vm.syncFromDepartmentCourses();

      if (!mounted) return;

      // Handle error cases
      if (result.hasError) {
        final error = result.error!;
        
        switch (error.type) {
          case SyncErrorType.notAuthenticated:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Not authenticated. Please log in.')),
            );
            break;
            
          case SyncErrorType.profileNotFound:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile not found. Please contact support.')),
            );
            break;
            
          case SyncErrorType.departmentNotSet:
            // Show dialog prompting user to set department in profile
            await _showDepartmentNotSetDialog();
            break;
            
          case SyncErrorType.noCoursesFound:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.message)),
            );
            break;
            
          case SyncErrorType.unknown:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sync failed: ${error.message}')),
            );
            break;
        }
        return;
      }

      // Success case - we have semesters
      final newSemesters = result.semesters!;
      
      if (newSemesters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No courses found to sync')),
        );
        return;
      }

      // Dispose old controllers
      for (final s in semesters) {
        for (final c in s.courses) {
          c.dispose();
        }
      }

      // Update UI with new semesters
      setState(() {
        semesters
          ..clear()
          ..addAll(newSemesters);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced ${newSemesters.length} semesters successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Show dialog prompting user to set department in profile
  Future<void> _showDepartmentNotSetDialog() async {
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

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        Scaffold(
          appBar: HCAppBar(
            leading: const BackButton(),
            title: 'GPA Calculator',
            actions: [
              IconButton(
                onPressed: _isSaving ? null : _syncFromDepartment,
                tooltip: 'Sync from Department',
                icon: const Icon(Icons.cloud_download),
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: semesters.length + 1, // +1 for "Add New Semester"
            itemBuilder: (context, index) {
              if (index == semesters.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 48),
                  child: OutlinedButton.icon(
                    onPressed: _addSemester,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add New Semester'),
                  ),
                );
              }

              final sIdx = index;
              final s = semesters[sIdx];
              final gpa = _semesterGpa(sIdx);
              final cgpa = _cgpaUntil(sIdx);
              final isEditing = _editingSemesters.contains(sIdx);

              return Padding(
                padding: EdgeInsets.only(
                    bottom: sIdx == semesters.length - 1 ? 16 : 24),
                child: Card(
                  key: ObjectKey(semesters[sIdx]),
                  margin: EdgeInsets.zero,
                  elevation: 2,
                  color: _getSemesterColor(s.colorIndex, context), // Use semester's colorIndex
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Inline title editor + actions
                        Row(
                          children: [
                            Expanded(
                              child: isEditing
                                  ? TextField(
                                      controller: _semNameCtrls[sIdx],
                                      autofocus: true,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          _commitEditSemName(sIdx),
                                      decoration: const InputDecoration(
                                        hintText: 'e.g., Fall 2025',
                                        isDense: true,
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: () => _beginEditSemName(sIdx),
                                      child: Text(
                                        (s.name.isNotEmpty)
                                            ? s.name
                                            : 'Semester #${sIdx + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 4),
                            if (isEditing) ...[
                              IconButton(
                                icon: const Icon(Icons.check),
                                tooltip: 'Save name',
                                onPressed: () => _commitEditSemName(sIdx),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: 'Cancel',
                                onPressed: () => _cancelEditSemName(sIdx),
                              ),
                            ] else ...[
                              // Reorder buttons
                              IconButton(
                                icon: const Icon(Icons.arrow_upward),
                                tooltip: 'Move semester up',
                                iconSize: 20,
                                onPressed: sIdx > 0 ? () => _moveSemesterUp(sIdx) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward),
                                tooltip: 'Move semester down',
                                iconSize: 20,
                                onPressed: sIdx < semesters.length - 1 
                                    ? () => _moveSemesterDown(sIdx) 
                                    : null,
                              ),
                             
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete semester',
                                onPressed: () => _deleteSemester(sIdx),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Field headers
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Text(
                                  'Course Name',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'Grade',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Credits',
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Space for delete button
                              const SizedBox(width: 48),
                            ],
                          ),
                        ),

                        for (int cIdx = 0;
                            cIdx < semesters[sIdx].courses.length;
                            cIdx++) ...[
                          _CourseRow(
                            key: ObjectKey(semesters[sIdx].courses[cIdx]),
                            course: semesters[sIdx].courses[cIdx],
                            creditGrades: gradeToPoint.keys.toList(),
                            nonCreditGrades: nonCreditGradeToPoint.keys.toList(),
                            onChanged: () => setState(() {}),
                            onDelete: () => _removeCourse(sIdx, cIdx),
                          ),

                          // Replacement notes
                          _ReplacementNote(
                            isLatestOverall: _isLatestOverall(sIdx, cIdx),
                            replacesSemesters:
                                _replacesSemestersOverall(sIdx, cIdx),
                            laterSemesterName:
                                _laterSemesterNameFor(sIdx, cIdx),
                          ),

                          const SizedBox(height: 8),
                        ],

                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () => _addCourse(sIdx),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Course'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GPA: ${gpa.toStringAsFixed(2)}',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('CGPA: ${cgpa.toStringAsFixed(2)}',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Saving overlay to block taps while saving
        if (_isSaving)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

// ====== replacement note (tiny widget) ========================================

class _ReplacementNote extends StatelessWidget {
  const _ReplacementNote({
    required this.isLatestOverall,
    required this.replacesSemesters,
    required this.laterSemesterName,
  });

  final bool isLatestOverall;
  final List<String> replacesSemesters; // names (or "Semester #N")
  final String? laterSemesterName;      // name of later semester, if any

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (isLatestOverall && replacesSemesters.isNotEmpty) {
      final list = replacesSemesters.join(', ');
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.swap_horiz, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'This attempt replaces previous attempts in $list.',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    if (!isLatestOverall && laterSemesterName != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Replaced by $laterSemesterName — excluded from final CGPA.',
                style: textTheme.bodySmall?.copyWith(
                  color: textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ====== row widget =============================================================

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    super.key,
    required this.course,
    required this.creditGrades,
    required this.nonCreditGrades,
    required this.onChanged,
    required this.onDelete,
  });

  final Course course;
  final List<String> creditGrades;
  final List<String> nonCreditGrades;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  static const double kFieldHeight = 48;
  static const double kRadius = 14;
  static const double kGap = 8;

  InputDecoration boxDeco([String? hint]) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(kRadius)),
      );

  OutlinedButtonThemeData outlinedTheme(BuildContext ctx) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(kFieldHeight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Determine which grade list to use based on credits
    final isNonCredit = course.credits == 0;
    final availableGrades = isNonCredit ? nonCreditGrades : creditGrades;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Course name
        Expanded(
          flex: 5,
          child: SizedBox(
            height: kFieldHeight,
            child: TextFormField(
              controller: course.nameCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: boxDeco('MAT 119'),
              onChanged: (_) => onChanged(),
            ),
          ),
        ),
        const SizedBox(width: kGap),

        // Grade
        Expanded(
          flex: 3,
          child: SizedBox(
            height: kFieldHeight,
            child: DropdownButtonFormField<String>(
              initialValue: availableGrades.contains(course.grade) ? course.grade : null,
              decoration: boxDeco().copyWith(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              hint: const Text('XX'),
              isExpanded: true,
              isDense: true,
              items: availableGrades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                course.grade = v;
                onChanged();
              },
            ),
          ),
        ),
        const SizedBox(width: kGap),

        // Credits
        Expanded(
          flex: 2,
          child: SizedBox(
            height: kFieldHeight,
            child: TextFormField(
              controller: course.creditCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: boxDeco('4'),
              onChanged: (v) {
                final newCredits = int.tryParse(v) ?? 0;
                final oldCredits = course.credits;
                course.credits = newCredits;
                
                // If switching between credit/non-credit, reset grade
                if ((oldCredits == 0) != (newCredits == 0)) {
                  course.grade = null;
                }
                
                onChanged();
              },
            ),
          ),
        ),
        const SizedBox(width: kGap),

        // Delete
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(
              width: kFieldHeight, height: kFieldHeight),
          child: OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
