// gpa_models.dart
import 'package:flutter/material.dart';

/// Represents a semester containing multiple courses
class SemesterModel {
  final List<Course> courses;
  String name;
  int colorIndex; // Index (0-9) for consistent coloring regardless of position
  
  SemesterModel({
    required this.courses,
    this.name = '',
    this.colorIndex = 0,
  });
}

/// Represents a course with its details and grade
class Course {
  final TextEditingController nameCtrl;
  final TextEditingController creditCtrl;
  String? grade; // null until picked
  int credits; // numeric shadow for calc

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

/// Result of syncing courses from department
class SyncCoursesResult {
  final List<SemesterModel>? semesters;
  final SyncError? error;
  
  SyncCoursesResult.success(this.semesters) : error = null;
  SyncCoursesResult.error(this.error) : semesters = null;
  
  bool get isSuccess => semesters != null;
  bool get hasError => error != null;
}

/// Represents different types of sync errors
enum SyncErrorType {
  notAuthenticated,
  profileNotFound,
  departmentNotSet,
  noCoursesFound,
  unknown,
}

/// Contains error information from sync operations
class SyncError {
  final SyncErrorType type;
  final String message;
  final String? department;
  
  SyncError({
    required this.type,
    required this.message,
    this.department,
  });
}
