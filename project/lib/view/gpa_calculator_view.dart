// gpa_calculator_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project/viewmodel/gpa_calculator_viewmodel.dart';

class GpaCalculatorView extends StatefulWidget {
  const GpaCalculatorView({super.key});

  @override
  State<GpaCalculatorView> createState() => _GpaCalculatorViewState();
}

class _GpaCalculatorViewState extends State<GpaCalculatorView> {
  late final GpaViewModel vm;
  bool _isLoading = true;
  bool _isSaving = false;

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
              ? [SemesterModel(courses: [Course.empty()])]
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
  void dispose() {
    for (final s in semesters) {
      for (final c in s.courses) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // Editable grade scale
  static const Map<String, double> gradeToPoint = {
    'AA': 4.0, 'BA': 3.5, 'BB': 3.0, 'CB': 2.5,
    'CC': 2.0, 'DC': 1.5, 'DD': 1.0, 'FD': 0.5, 'FF': 0.0, 'EX': 0.0,
  };

  final List<SemesterModel> semesters = [
    SemesterModel(courses: [Course.empty(), Course.empty()]),
    SemesterModel(courses: [Course.empty()]),
  ];

  // ---- helpers --------------------------------------------------------------

  bool _isActive(Course c) =>
      c.nameCtrl.text.trim().isNotEmpty && c.grade != null && c.credits > 0;

  double _semesterGpa(int sIdx) {
    final active = semesters[sIdx].courses.where(_isActive);
    double qp = 0, cr = 0;
    for (final c in active) {
      final pts = gradeToPoint[c.grade] ?? 0.0;
      qp += pts * c.credits;
      cr += c.credits;
    }
    return cr == 0 ? 0 : qp / cr;
  }

  double _cgpaUntil(int sIdx) {
    double qp = 0, cr = 0;
    for (int i = 0; i <= sIdx; i++) {
      for (final c in semesters[i].courses.where(_isActive)) {
        final pts = gradeToPoint[c.grade] ?? 0.0;
        qp += pts * c.credits;
        cr += c.credits;
      }
    }
    return cr == 0 ? 0 : qp / cr;
  }

  void _addSemester() {
    setState(() {
      semesters.add(SemesterModel(courses: [Course.empty(), Course.empty()]));
    });
  }

  void _addCourse(int sIdx) {
    setState(() => semesters[sIdx].courses.add(Course.empty()));
  }

  void _removeCourse(int sIdx, int cIdx) {
    setState(() {
      semesters[sIdx].courses[cIdx].dispose();
      semesters[sIdx].courses.removeAt(cIdx);
    });
  }

  // NEW: edit semester name ----------------------------------------------------
  Future<void> _editSemesterName(int sIdx) async {
    final current = semesters[sIdx].name.isNotEmpty
        ? semesters[sIdx].name
        : 'Semester #${sIdx + 1}';
    final controller = TextEditingController(text: current);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit semester name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'e.g., Fall 2025',
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        semesters[sIdx].name = result;
      });
    }
  }

  // ---- explicit Save ---------------------------------------------------------

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      vm.setSemestersFromUi(semesters);
      await vm.saveSnapshot(); // upsert by user_id

      if (vm.error != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${vm.error}')),
        );
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('GPA Calculator'),
            actions: [
              IconButton(
                onPressed: _isSaving ? null : _save,
                tooltip: 'Save',
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: semesters.length + 1,
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

              return Padding(
                padding: EdgeInsets.only(
                  bottom: sIdx == semesters.length - 1 ? 16 : 24,
                ),
                child: Card(
                  key: ObjectKey(s),
                  margin: EdgeInsets.zero,
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CHANGED: Title row with Edit button
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (s.name.isNotEmpty) ? s.name : 'Semester #${sIdx + 1}',
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit semester name',
                              onPressed: () => _editSemesterName(sIdx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        for (int cIdx = 0; cIdx < s.courses.length; cIdx++) ...[
                          _CourseRow(
                            key: ObjectKey(s.courses[cIdx]),
                            course: s.courses[cIdx],
                            grades: gradeToPoint.keys.toList(),
                            onChanged: () => setState(() {}),
                            onDelete: () => _removeCourse(sIdx, cIdx),
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
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('CGPA: ${cgpa.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleMedium),
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

        if (_isSaving)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: Colors.black.withOpacity(0.08),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

// ====== models =================================================================

class SemesterModel {
  final List<Course> courses;

  // NEW: simple name string (no controllers to manage)
  String name;

  SemesterModel({
    required this.courses,
    this.name = '',
  });
}

class Course {
  final TextEditingController nameCtrl;
  final TextEditingController creditCtrl;
  String? grade;
  int credits;

  Course({
    required this.nameCtrl,
    required this.creditCtrl,
    this.grade,
    this.credits = 0,
  });

  factory Course.empty() => Course(
        nameCtrl: TextEditingController(),
        creditCtrl: TextEditingController(),
      );

  void dispose() {
    nameCtrl.dispose();
    creditCtrl.dispose();
  }
}

// ====== row widget =============================================================

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    super.key,
    required this.course,
    required this.grades,
    required this.onChanged,
    required this.onDelete,
  });

  final Course course;
  final List<String> grades;
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Course name
        Expanded(
          flex: 4,
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
              value: course.grade,
              decoration: boxDeco(),
              hint: const Text('XX'),
              isExpanded: true,
              items: grades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (v) { course.grade = v; onChanged(); },
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
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: boxDeco('4'),
              onChanged: (v) { course.credits = int.tryParse(v) ?? 0; onChanged(); },
            ),
          ),
        ),
        const SizedBox(width: kGap),

        // Delete
        ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: kFieldHeight, height: kFieldHeight),
          child: OutlinedButton(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
            child: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}
