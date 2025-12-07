import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

class RegisterRequestViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> sendRequest({
    required String email,
    required String name,
    required String surname,
    required String dob,
    required String description,
    List<String>? filePaths,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    List<String> uploadedPaths = [];

    try {
      final supabase = Supabase.instance.client;
      final trimmedEmail = email.trim().toLowerCase();
      final trimmedName = name.trim();
      final trimmedSurname = surname.trim();
      final trimmedDescription = description.trim();
      final trimmedDob = dob.trim();

      // Validate inputs
      if (trimmedEmail.isEmpty || trimmedName.isEmpty || 
          trimmedSurname.isEmpty || trimmedDob.isEmpty || trimmedDescription.isEmpty) {
        _errorMessage = 'All fields are required.';
        return false;
      }

      // Parse date of birth
      DateTime? parsedDob;
      try {
        parsedDob = DateFormat('dd/MM/yyyy').parse(trimmedDob);
      } catch (e) {
        _errorMessage = 'Invalid date of birth format.';
        return false;
      }

      // Check if email already exists using secure RPC
      try {
        final bool exists = await supabase
            .rpc('check_request_exists', params: {'check_email': trimmedEmail});
        
        if (exists) {
          _errorMessage = "You already have an ongoing request process.";
          return false;
        }
      } on PostgrestException catch (e) {
        debugPrint('RPC error checking request existence: ${e.message}');
        _errorMessage = 'Unable to verify request status. Please try again.';
        return false;
      }

      String? documentUrls;

      // Upload files if provided
      if (filePaths != null && filePaths.isNotEmpty) {
        List<String> uploadedUrls = [];
        
        for (var filePath in filePaths) {
          final file = File(filePath);
          
          // Validate file exists and is readable
          if (!await file.exists()) {
            _errorMessage = 'One or more selected files no longer exist.';
            // Cleanup already uploaded files before returning
            if (uploadedPaths.isNotEmpty) {
              await _cleanupUploadedFiles(uploadedPaths);
            }
            return false;
          }

          final fileName = p.basename(filePath);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storagePath = '$trimmedEmail/${timestamp}_$fileName';
          
          try {
            await supabase.storage.from('register-request-docs').upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: false),
            );
            
            // Only add to uploadedPaths after successful upload
            uploadedPaths.add(storagePath);

            final url = supabase.storage
                .from('register-request-docs')
                .getPublicUrl(storagePath);
            uploadedUrls.add(url);
          } on StorageException catch (e) {
            debugPrint('Storage error uploading file: ${e.message}');
            _errorMessage = 'Failed to upload documents. Please try again.';
            // Cleanup already uploaded files before returning
            if (uploadedPaths.isNotEmpty) {
              await _cleanupUploadedFiles(uploadedPaths);
            }
            return false;
          }
        }
        
        documentUrls = uploadedUrls.join(',');
      }

      // Insert request into database
      try {
        await supabase.from('register_requests').insert({
          'email': trimmedEmail,
          'name': trimmedName,
          'surname': trimmedSurname,
          'dob': parsedDob.toIso8601String(),
          'description': trimmedDescription,
          'document': documentUrls,
        });
      } on PostgrestException catch (e) {
        debugPrint('Database error inserting request: ${e.message}');
        _errorMessage = 'Failed to submit request. Please try again.';
        // Cleanup uploaded files since database insert failed
        if (uploadedPaths.isNotEmpty) {
          await _cleanupUploadedFiles(uploadedPaths);
        }
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Unexpected error sending request: $e');
      _errorMessage = 'An unexpected error occurred. Please check your connection and try again.';
      // Cleanup uploaded files on unexpected error
      if (uploadedPaths.isNotEmpty) {
        await _cleanupUploadedFiles(uploadedPaths);
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _cleanupUploadedFiles(List<String> paths) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from('register-request-docs').remove(paths);
      debugPrint('Cleaned up ${paths.length} uploaded files after error');
    } catch (e) {
      debugPrint('Failed to cleanup uploaded files: $e');
    }
  }
}
